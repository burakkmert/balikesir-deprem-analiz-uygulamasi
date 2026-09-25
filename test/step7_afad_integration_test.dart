import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:afet_analiz/data/datasources/afad_remote_datasource.dart';
import 'package:afet_analiz/data/datasources/cache_datasource.dart';
import 'package:afet_analiz/data/models/deprem_olayi_dto.dart';
import 'package:afet_analiz/data/repositories/afad_repository_impl.dart';
import 'package:afet_analiz/domain/entities/deprem_olayi.dart';
import 'package:afet_analiz/domain/entities/earthquake_query.dart';
import 'package:afet_analiz/domain/entities/geo_point.dart';
import 'package:afet_analiz/domain/repositories/afad_repository.dart';
import 'package:afet_analiz/presentation/viewmodels/earthquakes_viewmodel.dart';
import 'package:afet_analiz/presentation/viewmodels/view_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AFAD Step 7 Integration & Strict Parser Tests', () {
    test(
      'A1: Uri parameters must contain bounding box and NO radius/maxrad',
      () async {
        Uri? capturedUri;

        final client = MockClient((request) async {
          capturedUri = request.url;
          return http.Response('[]', 200);
        });

        final dataSource = AfadRemoteDataSource(client: client);
        await dataSource.fetchEarthquakesFromApi(
          lat: 39.6484,
          lng: 27.8826,
          radius: 50.0,
          minMagnitude: 2.0,
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 25),
        );

        expect(capturedUri, isNotNull);
        final params = capturedUri!.queryParameters;
        expect(params.containsKey('minlat'), isTrue);
        expect(params.containsKey('maxlat'), isTrue);
        expect(params.containsKey('minlon'), isTrue);
        expect(params.containsKey('maxlon'), isTrue);
        expect(params.containsKey('start'), isTrue);
        expect(params.containsKey('end'), isTrue);
        expect(params.containsKey('minmag'), isTrue);
        expect(params.containsKey('orderby'), isTrue);
        expect(params.containsKey('limit'), isTrue);
        expect(params.containsKey('offset'), isTrue);

        // CRITICAL: radius and maxrad must NOT be sent
        expect(params.containsKey('radius'), isFalse);
        expect(params.containsKey('maxrad'), isFalse);
      },
    );

    test('A2: Events outside circle distance are filtered out', () async {
      final jsonPayload = jsonEncode([
        {
          'eventID': 'EQ-INSIDE',
          'latitude': 39.650,
          'longitude': 27.880,
          'depth': 7.0,
          'magnitude': 3.5,
          'location': 'BALIKESİR MERKEZ',
          'date': '2026-09-25 12:00:00',
        },
        {
          'eventID': 'EQ-OUTSIDE',
          'latitude': 38.500, // ~128 km away
          'longitude': 27.000,
          'depth': 10.0,
          'magnitude': 4.0,
          'location': 'IZMIR',
          'date': '2026-09-25 11:00:00',
        },
      ]);

      final client = MockClient((request) async {
        return http.Response.bytes(utf8.encode(jsonPayload), 200);
      });

      final dataSource = AfadRemoteDataSource(client: client);
      final result = await dataSource.fetchEarthquakesFromApi(
        lat: 39.6484,
        lng: 27.8826,
        radius: 50.0,
        minMagnitude: 2.0,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 25),
      );

      expect(result.events.length, equals(1));
      expect(result.events.first.eventID, equals('EQ-INSIDE'));
      expect(result.outOfBoundsRecords, equals(1));
    });

    test(
      'A3: Page 1 events outside circle does not stop pagination early',
      () async {
        // Create 100 events outside circle for page 1
        final page1List = List.generate(
          100,
          (i) => {
            'eventID': 'PAGE1-$i',
            'latitude': 38.500,
            'longitude': 27.000,
            'depth': 10.0,
            'magnitude': 3.0,
            'location': 'OUTSIDE',
            'date': '2026-09-25 10:00:00',
          },
        );

        // Page 2 has 2 events inside circle
        final page2List = [
          {
            'eventID': 'PAGE2-INSIDE-1',
            'latitude': 39.648,
            'longitude': 27.882,
            'depth': 5.0,
            'magnitude': 2.8,
            'location': 'BALIKESIR CENTER',
            'date': '2026-09-25 09:00:00',
          },
        ];

        int callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          final offset = request.url.queryParameters['offset'];
          if (offset == '0') {
            return http.Response(jsonEncode(page1List), 200);
          } else {
            return http.Response(jsonEncode(page2List), 200);
          }
        });

        final dataSource = AfadRemoteDataSource(client: client);
        final result = await dataSource.fetchEarthquakesFromApi(
          lat: 39.6484,
          lng: 27.8826,
          radius: 50.0,
          minMagnitude: 2.0,
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 25),
        );

        expect(callCount, equals(2));
        expect(result.events.length, equals(1));
        expect(result.events.first.eventID, equals('PAGE2-INSIDE-1'));
      },
    );

    test('B1: Strict parsing rejects invalid dates, missing IDs, and rms for magnitude', () {
      // 1. Missing eventID -> throws FormatException
      expect(
        () => DepremOlayiDto.fromJson({
          'latitude': 39.6,
          'longitude': 27.8,
          'magnitude': 3.0,
          'date': '2026-09-25 12:00:00',
        }),
        throwsFormatException,
      );

      // 2. Invalid calendar date (Feb 30) -> throws FormatException
      expect(
        () => DepremOlayiDto.fromJson({
          'eventID': 'ERR-DATE',
          'latitude': 39.6,
          'longitude': 27.8,
          'magnitude': 3.0,
          'date': '2026-02-30 12:00:00',
        }),
        throwsFormatException,
      );

      // 3. rms field present but no magnitude -> throws FormatException (does NOT use rms!)
      expect(
        () => DepremOlayiDto.fromJson({
          'eventID': 'ERR-RMS',
          'latitude': 39.6,
          'longitude': 27.8,
          'rms': 2.5,
          'date': '2026-09-25 12:00:00',
        }),
        throwsFormatException,
      );

      // 4. Negative magnitude is accepted!
      final negMagEq = DepremOlayiDto.fromJson({
        'eventID': 'NEG-MAG',
        'latitude': 39.6,
        'longitude': 27.8,
        'magnitude': -0.4,
        'date': '2026-09-25 12:00:00',
      });
      expect(negMagEq.buyukluk, equals(-0.4));
    });

    test('B2: Timezone offset detection works correctly', () {
      final utcEq = DepremOlayiDto.fromJson({
        'eventID': 'TZ-UTC',
        'latitude': 39.6,
        'longitude': 27.8,
        'magnitude': 3.0,
        'date': '2026-09-25T14:30:00.000Z',
      });
      expect(utcEq.isTimezoneVerified, isTrue);

      final localEq = DepremOlayiDto.fromJson({
        'eventID': 'TZ-UNVERIFIED',
        'latitude': 39.6,
        'longitude': 27.8,
        'magnitude': 3.0,
        'date': '2026-09-25 14:30:00',
      });
      expect(localEq.isTimezoneVerified, isFalse);
    });

    test(
      'C1: Network timeout returns error response and NO mock fallbacks',
      () async {
        final client = MockClient((request) async {
          throw TimeoutException('Request timed out');
        });

        final repo = AfadRepositoryImpl(
          remoteDataSource: AfadRemoteDataSource(client: client),
          cacheDataSource: CacheDataSource(),
        );

        final response = await repo.fetchEarthquakes(
          lat: 39.6484,
          lng: 27.8826,
          radius: 50.0,
          minMagnitude: 2.0,
        );

        expect(response.isSuccess, isFalse);
        expect(response.events, isEmpty);
        expect(
          response.errorMessage,
          contains('AFAD canlı sunucusuyla iletişim kurulamadı'),
        );
      },
    );

    test('C2: Stale cache is returned on refresh failure without updating fetchedAt', () async {
      final initialFetchDate = DateTime(2026, 9, 25, 10, 0, 0);
      final jsonPayload = jsonEncode([
        {
          'eventID': 'CACHED-1',
          'latitude': 39.648,
          'longitude': 27.882,
          'depth': 5.0,
          'magnitude': 3.2,
          'location': 'KARESI',
          'date': '2026-09-25 08:00:00',
        },
      ]);

      int attempt = 0;
      final client = MockClient((request) async {
        attempt++;
        if (attempt == 1) {
          return http.Response(jsonPayload, 200);
        } else {
          throw SocketException('Network error');
        }
      });

      final repo = AfadRepositoryImpl(
        remoteDataSource: AfadRemoteDataSource(client: client),
        cacheDataSource: CacheDataSource(),
        clock: () => initialFetchDate,
      );

      // Attempt 1: Successful fetch & cache
      final res1 = await repo.fetchEarthquakes(
        lat: 39.6484,
        lng: 27.8826,
        radius: 50.0,
        minMagnitude: 2.0,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 25),
      );
      expect(res1.isSuccess, isTrue);
      expect(res1.events.length, equals(1));
      expect(res1.fetchedAt, equals(initialFetchDate));

      // Attempt 2: Network fails, return stale cache with original fetchedAt
      final res2 = await repo.fetchEarthquakes(
        lat: 39.6484,
        lng: 27.8826,
        radius: 50.0,
        minMagnitude: 2.0,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 25),
        forceRefresh: true,
      );

      expect(res2.isSuccess, isFalse);
      expect(res2.isFromCache, isTrue);
      expect(res2.events.length, equals(1));
      expect(res2.events.first.eventID, equals('CACHED-1'));
      expect(
        res2.fetchedAt,
        equals(initialFetchDate),
      ); // Original fetchedAt preserved!
    });

    test(
      'D1: ViewModel race condition protection late A cannot overwrite B',
      () async {
        final completerA = Completer<AfadApiResponse>();
        final completerB = Completer<AfadApiResponse>();

        final repo = MultiCompleterAfadRepository(completerA, completerB);
        final vm = EarthquakesViewModel(afadRepository: repo);

        final pointA = GeoPoint(39.6484, 27.8826);
        final pointB = GeoPoint(40.3500, 27.9700);

        // 1. Start query A
        vm.fetchEarthquakes(point: pointA);
        expect(vm.isLoading, isTrue);

        // 2. Start query B on SAME ViewModel
        vm.fetchEarthquakes(point: pointB);
        expect(vm.currentPoint, equals(pointB));

        // 3. Complete B
        completerB.complete(
          AfadApiResponse(
            events: [
              DepremOlayi(
                eventID: 'EVENT-B',
                enlem: 40.35,
                boylam: 27.97,
                derinlik: 5.0,
                buyukluk: 3.5,
                yer: 'BANDIRMA',
                tarih: DateTime(2026, 9, 25),
              ),
            ],
            isSuccess: true,
          ),
        );
        await Future.delayed(Duration.zero);

        expect(vm.state, equals(ViewState.success));
        expect(vm.earthquakes.first.eventID, equals('EVENT-B'));

        // 4. Complete late query A
        completerA.complete(
          AfadApiResponse(
            events: [
              DepremOlayi(
                eventID: 'EVENT-A',
                enlem: 39.64,
                boylam: 27.88,
                derinlik: 10.0,
                buyukluk: 4.2,
                yer: 'KARESI',
                tarih: DateTime(2026, 9, 24),
              ),
            ],
            isSuccess: true,
          ),
        );
        await Future.delayed(Duration.zero);

        // Verify ViewModel is STILL on B!
        expect(vm.currentPoint, equals(pointB));
        expect(vm.earthquakes.first.eventID, equals('EVENT-B'));
      },
    );
  });
}

class MultiCompleterAfadRepository implements AfadRepository {
  final Completer<AfadApiResponse> completerA;
  final Completer<AfadApiResponse> completerB;
  int callCount = 0;

  MultiCompleterAfadRepository(this.completerA, this.completerB);

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
  }) {
    callCount++;
    if (callCount == 1) {
      return completerA.future;
    } else {
      return completerB.future;
    }
  }

  @override
  Future<void> clearCache() async {}
}
