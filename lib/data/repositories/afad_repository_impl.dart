import 'dart:async';

import '../../core/constants.dart';
import '../../core/utils/rate_limiter.dart';
import '../../domain/entities/earthquake_query.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/repositories/afad_repository.dart';
import '../datasources/afad_remote_datasource.dart';
import '../datasources/cache_datasource.dart';

class AfadRepositoryImpl implements AfadRepository {
  final AfadRemoteDataSource _remoteDataSource;
  final CacheDataSource _cacheDataSource;
  final RateLimiter _rateLimiter;
  final DateTime Function() _clock;
  final Map<String, Future<AfadApiResponse>> _inFlightRequests = {};

  AfadRepositoryImpl({
    AfadRemoteDataSource? remoteDataSource,
    CacheDataSource? cacheDataSource,
    RateLimiter? rateLimiter,
    DateTime Function()? clock,
  }) : _remoteDataSource = remoteDataSource ?? AfadRemoteDataSource(),
       _cacheDataSource = cacheDataSource ?? CacheDataSource(),
       _clock = clock ?? DateTime.now,
       _rateLimiter = rateLimiter ?? RateLimiter(clock: clock ?? DateTime.now);

  @override
  Future<AfadApiResponse> fetchEarthquakes({
    double lat = AppConstants.balikesirLat,
    double lng = AppConstants.balikesirLng,
    double radius = 150.0,
    double minMagnitude = 1.5,
    DateTime? startDate,
    DateTime? endDate,
    EarthquakeQuery? query,
    bool forceRefresh = false,
  }) async {
    final now = _clock();

    // 1. Resolve EarthquakeQuery entity
    final EarthquakeQuery eqQuery =
        query ??
        (startDate != null && endDate != null
            ? EarthquakeQuery.absolute(
                center: GeoPoint(lat, lng),
                radiusKm: radius,
                minMagnitude: minMagnitude,
                startDate: startDate,
                endDate: endDate,
              )
            : EarthquakeQuery.relative(
                center: GeoPoint(lat, lng),
                radiusKm: radius,
                minMagnitude: minMagnitude,
                days: 30,
              ));

    try {
      eqQuery.validate();
    } catch (e) {
      return AfadApiResponse(
        events: const [],
        isSuccess: false,
        errorMessage:
            'Geçersiz sorgu parametresi: ${e.toString().replaceAll("ArgumentError: ", "")}',
        query: eqQuery,
      );
    }

    final cacheKey = CacheDataSource.generateCacheKey(eqQuery);

    // 2. Cache Hit Check (if !forceRefresh)
    final existingEnvelope = await _cacheDataSource.getEnvelope(cacheKey);
    if (!forceRefresh && existingEnvelope != null) {
      if (existingEnvelope.isFresh(now)) {
        return AfadApiResponse(
          events: existingEnvelope.events,
          isFromCache: true,
          isSuccess: true,
          isPartial: existingEnvelope.isPartial,
          statusNotice: existingEnvelope.statusNotice,
          fetchedAt: existingEnvelope.fetchedAt,
          requestedAt: existingEnvelope.requestedAt,
          query: eqQuery,
          totalRawRecords: existingEnvelope.totalRawRecords,
          validRecords: existingEnvelope.validRecords,
          rejectedRecords: existingEnvelope.rejectedRecords,
          outOfBoundsRecords: existingEnvelope.outOfBoundsRecords,
        );
      }
    }

    // 3. Single-Flight Execution
    if (_inFlightRequests.containsKey(cacheKey)) {
      return await _inFlightRequests[cacheKey]!;
    }

    final future = _executeFetch(
      query: eqQuery,
      cacheKey: cacheKey,
      existingEnvelope: existingEnvelope,
      requestedAt: now,
    );

    _inFlightRequests[cacheKey] = future;

    try {
      return await future;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<AfadApiResponse> _executeFetch({
    required EarthquakeQuery query,
    required String cacheKey,
    required AfadCacheEnvelope? existingEnvelope,
    required DateTime requestedAt,
  }) async {
    final now = _clock();
    final timeRange = query.resolveTimeWindow(_clock);

    // 1. Rate Limiter check
    try {
      _rateLimiter.checkAndRecord(enforce: true);
    } on RateLimitException catch (e) {
      if (existingEnvelope != null && existingEnvelope.isUsableStale(now)) {
        return AfadApiResponse(
          events: existingEnvelope.events,
          isFromCache: true,
          isSuccess: false,
          isPartial: existingEnvelope.isPartial,
          errorMessage:
              'İstek sınırı aşıldı. Önceki veri gösteriliyor (${e.message}).',
          statusNotice: existingEnvelope.statusNotice,
          fetchedAt: existingEnvelope.fetchedAt,
          requestedAt: requestedAt,
          query: query,
        );
      }
      return AfadApiResponse(
        events: const [],
        isSuccess: false,
        errorMessage: e.message,
        query: query,
      );
    }

    // 2. Perform Remote Fetch
    try {
      final fetchResult = await _remoteDataSource.fetchEarthquakesFromApi(
        query: query,
        startDate: timeRange.start,
        endDate: timeRange.end,
        fetchedAt: now,
        rateLimiter: _rateLimiter,
      );

      final envelope = AfadCacheEnvelope(
        query: query,
        actualStartDate: timeRange.start,
        actualEndDate: timeRange.end,
        requestedAt: requestedAt,
        fetchedAt: now,
        events: fetchResult.events,
        isPartial: fetchResult.isPartial,
        totalRawRecords: fetchResult.totalRawRecords,
        validRecords: fetchResult.validRecords,
        rejectedRecords: fetchResult.rejectedRecords,
        outOfBoundsRecords: fetchResult.outOfBoundsRecords,
        statusNotice: fetchResult.statusNotice,
      );

      try {
        await _cacheDataSource.saveEnvelope(cacheKey, envelope);
      } catch (_) {
        // Disk write failure must not lose remote result
      }

      return AfadApiResponse(
        events: fetchResult.events,
        isFromCache: false,
        isSuccess: true,
        isPartial: fetchResult.isPartial,
        statusNotice: fetchResult.statusNotice,
        fetchedAt: now,
        requestedAt: requestedAt,
        query: query,
        totalRawRecords: fetchResult.totalRawRecords,
        validRecords: fetchResult.validRecords,
        rejectedRecords: fetchResult.rejectedRecords,
        outOfBoundsRecords: fetchResult.outOfBoundsRecords,
      );
    } catch (e) {
      final cleanErrorMsg = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('HttpException: ', '')
          .replaceAll('FormatException: ', '');

      if (existingEnvelope != null && existingEnvelope.isUsableStale(now)) {
        return AfadApiResponse(
          events: existingEnvelope.events,
          isFromCache: true,
          isSuccess: false,
          isPartial: existingEnvelope.isPartial,
          errorMessage:
              'AFAD canlı sunucu uyarısı: $cleanErrorMsg (Önceki önbellek verisi gösteriliyor)',
          statusNotice: existingEnvelope.statusNotice,
          fetchedAt: existingEnvelope.fetchedAt,
          requestedAt: requestedAt,
          query: query,
        );
      }

      return AfadApiResponse(
        events: const [],
        isFromCache: false,
        isSuccess: false,
        errorMessage:
            'AFAD canlı sunucusuyla iletişim kurulamadı: $cleanErrorMsg',
        query: query,
      );
    }
  }

  @override
  Future<void> clearCache() async {
    await _cacheDataSource.clearCache();
  }
}
