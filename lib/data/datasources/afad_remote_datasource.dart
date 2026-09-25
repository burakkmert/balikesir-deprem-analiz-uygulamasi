import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../core/utils/rate_limiter.dart';
import '../../domain/entities/deprem_olayi.dart';
import '../../domain/entities/earthquake_query.dart';
import '../../domain/entities/geo_point.dart';
import '../models/deprem_olayi_dto.dart';

class AfadFetchResult {
  final List<DepremOlayi> events;
  final bool isPartial;
  final int totalRawRecords;
  final int validRecords;
  final int rejectedRecords;
  final int outOfBoundsRecords;
  final String? statusNotice;

  AfadFetchResult({
    required this.events,
    required this.isPartial,
    required this.totalRawRecords,
    required this.validRecords,
    required this.rejectedRecords,
    required this.outOfBoundsRecords,
    this.statusNotice,
  });
}

class AfadRemoteDataSource {
  final http.Client client;

  AfadRemoteDataSource({http.Client? client})
    : client = client ?? http.Client();

  Future<AfadFetchResult> fetchEarthquakesFromApi({
    double lat = AppConstants.balikesirLat,
    double lng = AppConstants.balikesirLng,
    double radius = 150.0,
    double minMagnitude = 1.5,
    EarthquakeQuery? query,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? fetchedAt,
    RateLimiter? rateLimiter,
  }) async {
    final EarthquakeQuery eqQuery =
        query ??
        EarthquakeQuery.absolute(
          center: GeoPoint(lat, lng),
          radiusKm: radius,
          minMagnitude: minMagnitude,
          startDate: startDate,
          endDate: endDate,
        );

    eqQuery.validate();

    final DateTime nowUtc = fetchedAt ?? DateTime.now().toUtc();
    final double queryLat = eqQuery.center.latitude;
    final double queryLng = eqQuery.center.longitude;
    final double queryRadius = eqQuery.radiusKm;

    // 1. Calculate Outward Expanded Bounding Box
    final double latRad = queryLat * math.pi / 180.0;
    final double latDelta =
        (queryRadius / 111.0) * 1.005; // 0.5% buffer expansion
    final double safeCos = math.cos(latRad).abs().clamp(0.01, 1.0);
    final double lonDelta = (queryRadius / (111.0 * safeCos)) * 1.005;

    final double minLat = (queryLat - latDelta).clamp(-90.0, 90.0);
    final double maxLat = (queryLat + latDelta).clamp(-90.0, 90.0);
    final double minLon = (queryLng - lonDelta).clamp(-180.0, 180.0);
    final double maxLon = (queryLng + lonDelta).clamp(-180.0, 180.0);

    const int pageLimit = 100;
    const int maxPages = 5;

    int offset = 0;
    int pageCount = 0;
    bool reachedEnd = false;
    bool isPartial = false;

    int totalRawCount = 0;
    int validCount = 0;
    int rejectedCount = 0;
    int outOfBoundsCount = 0;

    final Map<String, DepremOlayi> eventsMap = {};
    String? paginationWarning;

    while (!reachedEnd && pageCount < maxPages) {
      pageCount++;

      // Rate limit check per HTTP call
      if (rateLimiter != null) {
        try {
          rateLimiter.checkAndRecord(enforce: true);
        } catch (e) {
          if (eventsMap.isNotEmpty) {
            isPartial = true;
            paginationWarning =
                'İstek sınırı nedeniyle sayfa $pageCount alınamadı. Kısmi sonuç gösteriliyor.';
            break;
          }
          rethrow;
        }
      }

      final queryParams = <String, String>{
        'start': _formatDate(startDate),
        'end': _formatDate(endDate),
        'minlat': minLat.toStringAsFixed(4),
        'maxlat': maxLat.toStringAsFixed(4),
        'minlon': minLon.toStringAsFixed(4),
        'maxlon': maxLon.toStringAsFixed(4),
        'minmag': eqQuery.minMagnitude.toStringAsFixed(1),
        'orderby': 'timedesc',
        'limit': pageLimit.toString(),
        'offset': offset.toString(),
      };

      final uri = Uri.parse(AppConstants.afadApiBaseUrl)
          .replace(queryParameters: queryParams);

      final http.Response response;
      try {
        response = await client
            .get(
              uri,
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'AfetAnalizBalikesir/1.0 (Contact: info@balikesir.bel.tr; Flutter app)',
              },
            )
            .timeout(const Duration(seconds: 10));
      } on Exception catch (e) {
        if (eventsMap.isNotEmpty) {
          isPartial = true;
          paginationWarning =
              'Bağlantı kesintisi nedeniyle sayfa $pageCount alınamadı. Kısmi sonuç gösteriliyor.';
          break;
        }
        if (e is TimeoutException) {
          throw TimeoutException('AFAD isteği zaman aşımına uğradı (10 sn).');
        } else if (e is SocketException) {
          throw SocketException('AFAD sunucusuna bağlanılamadı: ${e.message}');
        }
        rethrow;
      }

      if (response.statusCode == 429 || response.statusCode == 503) {
        final retryAfter = response.headers['retry-after'];
        if (rateLimiter != null && retryAfter != null) {
          rateLimiter.parseAndSetCooldown(retryAfter);
        }
        if (eventsMap.isNotEmpty) {
          isPartial = true;
          paginationWarning =
              'HTTP ${response.statusCode} nedeniyle sayfa $pageCount alınamadı. Kısmi sonuç gösteriliyor.';
          break;
        }
        final msg = retryAfter != null
            ? 'AFAD sunucu sınırı (HTTP ${response.statusCode}). $retryAfter saniye bekleyin.'
            : 'AFAD sunucu sınırı (HTTP ${response.statusCode}). Lütfen daha sonra tekrar deneyin.';
        throw HttpException(msg);
      }

      if (response.statusCode != 200) {
        if (eventsMap.isNotEmpty) {
          isPartial = true;
          paginationWarning =
              'HTTP ${response.statusCode} sunucu yanıtı nedeniyle sayfa $pageCount kesildi.';
          break;
        }
        throw HttpException(
          'AFAD sunucu hatası (HTTP ${response.statusCode}).',
        );
      }

      final body = response.body.trim();
      if (body.startsWith('<html') || body.startsWith('<!DOCTYPE')) {
        if (eventsMap.isNotEmpty) {
          isPartial = true;
          paginationWarning =
              'AFAD HTML hata sayfası döndürdü. Kısmi sonuç gösteriliyor.';
          break;
        }
        throw const FormatException('AFAD sunucusu JSON yerine HTML döndürdü.');
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        if (eventsMap.isNotEmpty) {
          isPartial = true;
          paginationWarning =
              'Bozuk JSON yanıtı nedeniyle sayfalama durduruldu.';
          break;
        }
        throw const FormatException('AFAD yanıtı geçerli JSON değil.');
      }

      if (decoded is! List) {
        if (eventsMap.isNotEmpty) {
          isPartial = true;
          paginationWarning =
              'Liste dışı yanıt nedeniyle sayfalama durduruldu.';
          break;
        }
        throw const FormatException('AFAD yanıtı JSON listesi değil.');
      }

      final List<dynamic> rawList = decoded;
      final int rawCountThisPage = rawList.length;
      totalRawCount += rawCountThisPage;

      if (rawCountThisPage == 0) {
        reachedEnd = true;
        break;
      }

      offset += rawCountThisPage;
      if (rawCountThisPage < pageLimit) {
        reachedEnd = true;
      }

      for (final item in rawList) {
        if (item is! Map<String, dynamic>) {
          rejectedCount++;
          continue;
        }

        try {
          final event = DepremOlayiDto.fromJson(item, fetchedAt: nowUtc);
          validCount++;

          final distKm = calculateDistanceKm(
            queryLat,
            queryLng,
            event.enlem,
            event.boylam,
          );
          if (distKm <= queryRadius) {
            eventsMap[event.eventID] = event;
          } else {
            outOfBoundsCount++;
          }
        } catch (_) {
          rejectedCount++;
        }
      }
    }

    if (!reachedEnd && pageCount >= maxPages) {
      isPartial = true;
    }

    if (totalRawCount > 0 && validCount == 0 && eventsMap.isEmpty) {
      throw const FormatException(
        'Alınan tüm AFAD kayıtları veri doğrulama aşamasında reddedildi.',
      );
    }

    String? statusNotice = paginationWarning;
    if (statusNotice == null) {
      if (isPartial) {
        statusNotice = 'Sayfa sınırına ulaşıldı (Kısmi sonuç gösteriliyor).';
      } else if (rejectedCount > 0) {
        statusNotice =
            '$rejectedCount adet kayıt hatalı biçim nedeniyle atlandı.';
      }
    }

    final eventsList = eventsMap.values.toList();
    eventsList.sort((a, b) => b.tarih.compareTo(a.tarih));

    return AfadFetchResult(
      events: eventsList,
      isPartial: isPartial,
      totalRawRecords: totalRawCount,
      validRecords: validCount,
      rejectedRecords: rejectedCount,
      outOfBoundsRecords: outOfBoundsCount,
      statusNotice: statusNotice,
    );
  }

  static String _formatDate(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${twoDigits(dt.month)}-${twoDigits(dt.day)} ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}:${twoDigits(dt.second)}';
  }

  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
