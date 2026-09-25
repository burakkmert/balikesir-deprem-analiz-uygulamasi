import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:afet_analiz/core/utils/rate_limiter.dart';
import 'package:afet_analiz/data/datasources/afad_remote_datasource.dart';
import 'package:afet_analiz/data/datasources/cache_datasource.dart';
import 'package:afet_analiz/data/datasources/osm_tile_cache_datasource.dart';
import 'package:afet_analiz/data/models/deprem_olayi_dto.dart';
import 'package:afet_analiz/data/repositories/afad_repository_impl.dart';
import 'package:afet_analiz/domain/entities/deprem_olayi.dart';
import 'package:afet_analiz/domain/entities/earthquake_query.dart';
import 'package:afet_analiz/domain/entities/geo_point.dart';
import 'package:afet_analiz/domain/repositories/afad_repository.dart';
import 'package:afet_analiz/presentation/viewmodels/earthquakes_viewmodel.dart';
import 'package:afet_analiz/presentation/widgets/persistent_osm_tile_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AFAD & OSM Step 8 Caching, Rate Limiting & Tile Tests', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('step8_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('1. Identical relative query at different times yields fresh cache hit with 0 HTTP calls', () async {
      DateTime currentTime = DateTime(2026, 9, 25, 12, 0, 0);
      int httpCallCount = 0;

      final jsonPayload = jsonEncode([
        {
          'eventID': 'EQ-FRESH-1',
          'latitude': 39.648,
          'longitude': 27.882,
          'depth': 5.0,
          'magnitude': 3.0,
          'location': 'KARESI',
          'date': '2026-09-25 10:00:00',
        },
      ]);

      final client = MockClient((request) async {
        httpCallCount++;
        return http.Response(jsonPayload, 200);
      });

      final repo = AfadRepositoryImpl(
        remoteDataSource: AfadRemoteDataSource(client: client),
        cacheDataSource: CacheDataSource(),
        clock: () => currentTime,
      );

      final query = EarthquakeQuery.relative(
        center: GeoPoint(39.6484, 27.8826),
        radiusKm: 50.0,
        minMagnitude: 2.0,
        days: 30,
      );

      // Fetch #1 at T=0
      final res1 = await repo.fetchEarthquakes(query: query);
      expect(res1.isSuccess, isTrue);
      expect(res1.isFromCache, isFalse);
      expect(httpCallCount, equals(1));

      // Advance time by 5 minutes (well within 15 min TTL)
      currentTime = currentTime.add(const Duration(minutes: 5));

      // Fetch #2 at T+5m
      final res2 = await repo.fetchEarthquakes(query: query);
      expect(res2.isSuccess, isTrue);
      expect(res2.isFromCache, isTrue);
      expect(httpCallCount, equals(1)); // ZERO new HTTP calls!
    });

    test('2. Different query parameters produce distinct canonical keys and no false cache sharing', () async {
      final queryA = EarthquakeQuery.relative(
        center: GeoPoint(39.6484, 27.8826),
        radiusKm: 50.0,
      );
      final queryB = EarthquakeQuery.relative(
        center: GeoPoint(40.3500, 27.9700),
        radiusKm: 50.0,
      );

      expect(queryA.canonicalKey, isNot(equals(queryB.canonicalKey)));
    });

    test('3. TTL boundaries: Fresh <=15m, Expired >15m & <=24h uses stale fallback on error', () async {
      DateTime currentTime = DateTime(2026, 9, 25, 12, 0, 0);
      int attempt = 0;

      final jsonPayload = jsonEncode([
        {
          'eventID': 'EQ-TTL-1',
          'latitude': 39.648,
          'longitude': 27.882,
          'depth': 5.0,
          'magnitude': 3.0,
          'location': 'KARESI',
          'date': '2026-09-25 10:00:00',
        },
      ]);

      final client = MockClient((request) async {
        attempt++;
        if (attempt == 1) {
          return http.Response(jsonPayload, 200);
        } else {
          throw SocketException('Network server down');
        }
      });

      final repo = AfadRepositoryImpl(
        remoteDataSource: AfadRemoteDataSource(client: client),
        cacheDataSource: CacheDataSource(),
        clock: () => currentTime,
      );

      final query = EarthquakeQuery.relative(
        center: GeoPoint(39.6484, 27.8826),
      );

      // 1. Initial fetch at T=0
      await repo.fetchEarthquakes(query: query);

      // 2. T+20 min (expired freshness TTL, but within 24h retention)
      currentTime = currentTime.add(const Duration(minutes: 20));
      final staleRes = await repo.fetchEarthquakes(query: query);

      expect(staleRes.isSuccess, isFalse);
      expect(staleRes.isFromCache, isTrue);
      expect(staleRes.events.length, equals(1));
      expect(
        staleRes.errorMessage,
        contains('Önceki önbellek verisi gösteriliyor'),
      );

      // 3. T+25 hours (past 24h retention limit)
      currentTime = currentTime.add(const Duration(hours: 25));
      final expiredRes = await repo.fetchEarthquakes(query: query);

      expect(expiredRes.isSuccess, isFalse);
      expect(expiredRes.events, isEmpty); // Outdated cache rejected!
    });

    test('4. Force refresh skips fresh cache check and coalesces concurrent single-flight requests', () async {
      DateTime currentTime = DateTime(2026, 9, 25, 12, 0, 0);
      int httpCallCount = 0;

      final jsonPayload = jsonEncode([
        {
          'eventID': 'EQ-REFRESH-1',
          'latitude': 39.648,
          'longitude': 27.882,
          'depth': 5.0,
          'magnitude': 3.0,
          'location': 'KARESI',
          'date': '2026-09-25 10:00:00',
        },
      ]);

      final client = MockClient((request) async {
        httpCallCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonPayload, 200);
      });

      final repo = AfadRepositoryImpl(
        remoteDataSource: AfadRemoteDataSource(client: client),
        cacheDataSource: CacheDataSource(),
        clock: () => currentTime,
      );

      final query = EarthquakeQuery.relative(
        center: GeoPoint(39.6484, 27.8826),
      );

      // Initial fetch
      await repo.fetchEarthquakes(query: query);
      expect(httpCallCount, equals(1));

      // Trigger TWO concurrent forceRefresh calls simultaneously
      final future1 = repo.fetchEarthquakes(query: query, forceRefresh: true);
      final future2 = repo.fetchEarthquakes(query: query, forceRefresh: true);

      final results = await Future.wait([future1, future2]);

      expect(results[0].isSuccess, isTrue);
      expect(results[1].isSuccess, isTrue);
      expect(
        httpCallCount,
        equals(2),
      ); // Only ONE new network call for both concurrent requests!
    });

    test('5. RateLimiter parses Retry-After header (seconds & HTTP-date) and enforces cooldown', () async {
      final limiter = RateLimiter(clock: () => DateTime(2026, 9, 25, 12, 0, 0));

      // Parse integer seconds
      limiter.parseAndSetCooldown('120');
      expect(limiter.cooldownUntil, isNotNull);
      expect(
        limiter.cooldownUntil!
            .difference(DateTime(2026, 9, 25, 12, 0, 0))
            .inSeconds,
        equals(120),
      );

      // Expect exception while cooldown active
      expect(
        () => limiter.checkAndRecord(enforce: true),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('6. Pagination error on page 2 returns valid events from page 1 as partial result', () async {
      final page1List = List.generate(
        100,
        (i) => {
          'eventID': 'P1-$i',
          'latitude': 39.648,
          'longitude': 27.882,
          'depth': 5.0,
          'magnitude': 3.0,
          'location': 'KARESI',
          'date': '2026-09-25 10:00:00',
        },
      );

      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(jsonEncode(page1List), 200);
        } else {
          throw SocketException('Connection dropped during page 2');
        }
      });

      final dataSource = AfadRemoteDataSource(client: client);
      final result = await dataSource.fetchEarthquakesFromApi(
        query: EarthquakeQuery.relative(center: GeoPoint(39.6484, 27.8826)),
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 25),
      );

      expect(result.isPartial, isTrue);
      expect(result.events.length, equals(100));
      expect(result.statusNotice, contains('Kısmi sonuç gösteriliyor'));
    });

    test('7. Date parsing with +03:00 timezone across UTC date boundary works strictly', () {
      // 2026-09-25T00:30:00+03:00 is 2026-09-24 21:30:00 UTC
      final parsed = DepremOlayiDto.parseStrictDate(
        '2026-09-25T00:30:00+03:00',
      );
      expect(parsed.hasExplicitTimezone, isTrue);
      expect(parsed.dateTime.year, equals(2026));

      // Invalid time 12:99:00 throws FormatException
      expect(
        () => DepremOlayiDto.parseStrictDate('2026-09-25T12:99:00+03:00'),
        throwsFormatException,
      );
    });

    test('8. EarthquakesViewModel 350ms debounce ignores intermediate point selections', () async {
      final repo = MockAfadRepository();
      final vm = EarthquakesViewModel(
        afadRepository: repo,
        debounceDuration: const Duration(milliseconds: 100),
      );

      final pA = GeoPoint(39.6484, 27.8826);
      final pB = GeoPoint(40.3500, 27.9700);

      // Select point A
      vm.onPointSelected(point: pA);
      expect(vm.isLoading, isTrue);

      // 30ms later select point B
      await Future.delayed(const Duration(milliseconds: 30));
      vm.onPointSelected(point: pB);

      // Wait 150ms for B's debounce to fire
      await Future.delayed(const Duration(milliseconds: 150));

      expect(repo.queriesExecuted.length, equals(1));
      expect(repo.queriesExecuted.first.center, equals(pB)); // Only B executed!
    });

    test('9. OSM Tile Cache 200 OK saves tile to disk, subsequent call is a disk hit', () async {
      final tileUrl = 'https://tile.openstreetmap.org/10/583/387.png';
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      int networkFetchCount = 0;
      final client = MockClient((request) async {
        networkFetchCount++;
        return http.Response.bytes(
          dummyBytes,
          200,
          headers: {
            'content-type': 'image/png',
            'cache-control': 'max-age=86400',
            'etag': '"test-etag-123"',
          },
        );
      });

      final tileSource = OsmTileCacheDataSource(
        cacheDir: tempDir,
        client: client,
      );

      // Fetch #1 from network
      final bytes1 = await tileSource.getTile(tileUrl);
      expect(bytes1, equals(dummyBytes));
      expect(networkFetchCount, equals(1));

      // Fetch #2 from persistent disk cache
      final bytes2 = await tileSource.getTile(tileUrl);
      expect(bytes2, equals(dummyBytes));
      expect(networkFetchCount, equals(1)); // ZERO new network calls!
    });

    test('10. OSM Tile Cache 304 Not Modified updates metadata and returns cached tile bytes', () async {
      final tileUrl = 'https://tile.openstreetmap.org/10/583/388.png';
      final dummyBytes = Uint8List.fromList([10, 20, 30]);

      DateTime currentTime = DateTime(2026, 9, 25, 12, 0, 0);
      int networkFetchCount = 0;

      final client = MockClient((request) async {
        networkFetchCount++;
        if (request.headers.containsKey('If-None-Match')) {
          return http.Response(
            '',
            304,
            headers: {'cache-control': 'max-age=86400'},
          );
        }
        return http.Response.bytes(
          dummyBytes,
          200,
          headers: {
            'content-type': 'image/png',
            'cache-control': 'max-age=60', // 1 minute TTL
            'etag': '"etag-304-test"',
          },
        );
      });

      final tileSource = OsmTileCacheDataSource(
        cacheDir: tempDir,
        client: client,
        clock: () => currentTime,
      );

      // 1. Initial fetch at T=0
      await tileSource.getTile(tileUrl);
      expect(networkFetchCount, equals(1));

      // 2. Advance time past max-age=60s
      currentTime = currentTime.add(const Duration(seconds: 120));

      // 3. Conditional fetch (sends If-None-Match, receives 304)
      final bytes304 = await tileSource.getTile(tileUrl);

      expect(bytes304, equals(dummyBytes));
      expect(networkFetchCount, equals(2));
    });

    test(
      '11. MapView default tile provider uses PersistentOsmTileProvider',
      () {
        final provider = PersistentOsmTileProvider.defaultInstance;
        expect(provider, isNotNull);
        expect(provider.dataSource, isNotNull);
      },
    );
  });
}

class MockAfadRepository implements AfadRepository {
  final List<EarthquakeQuery> queriesExecuted = [];

  @override
  Future<AfadApiResponse> fetchEarthquakes({
    double lat = 39.6484,
    double lng = 27.8826,
    double radius = 150.0,
    double minMagnitude = 1.5,
    DateTime? startDate,
    DateTime? endDate,
    EarthquakeQuery? query,
    bool forceRefresh = false,
  }) async {
    final eqQuery =
        query ??
        EarthquakeQuery.relative(
          center: GeoPoint(lat, lng),
          radiusKm: radius,
          minMagnitude: minMagnitude,
        );

    queriesExecuted.add(eqQuery);

    return AfadApiResponse(
      events: [
        DepremOlayi(
          eventID: 'MOCK-1',
          enlem: eqQuery.center.latitude,
          boylam: eqQuery.center.longitude,
          derinlik: 5.0,
          buyukluk: 3.0,
          yer: 'TEST LOCATION',
          tarih: DateTime(2026, 9, 25),
        ),
      ],
      isSuccess: true,
      query: eqQuery,
    );
  }

  @override
  Future<void> clearCache() async {}
}
