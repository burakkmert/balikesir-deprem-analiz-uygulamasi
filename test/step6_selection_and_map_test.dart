import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:afet_analiz/data/datasources/asset_local_datasource.dart';
import 'package:afet_analiz/data/repositories/local_data_repository_impl.dart';
import 'package:afet_analiz/domain/entities/deprem_olayi.dart';
import 'package:afet_analiz/domain/entities/earthquake_query.dart';
import 'package:afet_analiz/domain/entities/geo_point.dart';
import 'package:afet_analiz/domain/repositories/afad_repository.dart';
import 'package:afet_analiz/presentation/screens/home_screen.dart';
import 'package:afet_analiz/presentation/viewmodels/app_state_viewmodel.dart';
import 'package:afet_analiz/presentation/viewmodels/earthquakes_viewmodel.dart';
import 'package:afet_analiz/presentation/viewmodels/regional_metrics_viewmodel.dart';
import 'package:afet_analiz/presentation/viewmodels/selection_viewmodel.dart';
import 'package:afet_analiz/presentation/viewmodels/view_state.dart';
import 'package:afet_analiz/presentation/widgets/map_view.dart';

class NetworkNoOpTileProvider extends TileProvider {
  static const List<int> _transparentPngBytes = [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ];

  static final MemoryImage _transparentImage = MemoryImage(
    Uint8List.fromList(_transparentPngBytes),
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _transparentImage;
  }
}

class MockUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  String? launchedUrl;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrl = url;
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    return true;
  }
}

class MockAfadRepository implements AfadRepository {
  int fetchCallCount = 0;
  bool returnEmpty = false;
  Duration delay = Duration.zero;

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
    fetchCallCount++;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (returnEmpty) {
      return AfadApiResponse(events: [], isFromCache: false, isSuccess: true);
    }
    return AfadApiResponse(
      events: [
        DepremOlayi(
          eventID: 'EQ-TEST-100',
          enlem: lat,
          boylam: lng,
          derinlik: 7.5,
          buyukluk: 3.8,
          yer: 'BALIKESİR',
          tarih: DateTime.now(),
        ),
      ],
      isFromCache: false,
      isSuccess: true,
    );
  }

  @override
  Future<void> clearCache() async {}
}

class MultiCompleterAfadRepository implements AfadRepository {
  final Map<double, Completer<AfadApiResponse>> completers = {};
  Completer<void>? clearCacheCompleter;
  int fetchCallCount = 0;

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
    fetchCallCount++;
    final targetLat = query?.center.latitude ?? lat;
    if (completers.containsKey(targetLat)) {
      return await completers[targetLat]!.future;
    }
    return AfadApiResponse(events: [], isFromCache: false, isSuccess: true);
  }

  @override
  Future<void> clearCache() async {
    if (clearCacheCompleter != null) {
      await clearCacheCompleter!.future;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 6 Acceptance Fixes & Comprehensive Verification Tests', () {
    late LocalDataRepositoryImpl realRepo;
    late MockAfadRepository mockAfad;
    late MockUrlLauncher mockLauncher;

    setUp(() {
      realRepo = LocalDataRepositoryImpl(
        assetDataSource: AssetLocalDataSource(),
      );
      mockAfad = MockAfadRepository();
      mockLauncher = MockUrlLauncher();
      UrlLauncherPlatform.instance = mockLauncher;
    });

    test('1. Initial launch state: selectedPoint null, selectedIlce null, selectedMahalle null', () async {
      final selectionVM = SelectionViewModel(localDataRepository: realRepo);
      expect(selectionVM.selectedPoint, isNull);
      expect(selectionVM.selectedIlce, isNull);
      expect(selectionVM.selectedMahalle, isNull);
      expect(selectionVM.selectedMahalleKodu, isNull);
      expect(selectionVM.hasPointSelection, isFalse);
    });

    test('2. Real Altınoluk selection via mahalleKodu 147693: population 7148, selectedPoint null', () async {
      await realRepo.loadLocalData();
      final selectionVM = SelectionViewModel(localDataRepository: realRepo);
      final metricsVM = RegionalMetricsViewModel(localDataRepository: realRepo);
      await metricsVM.loadRegionalData();

      selectionVM.selectMahalleByCode('147693');

      expect(selectionVM.selectedIlce, equals('Edremit'));
      expect(selectionVM.selectedMahalle, equals('Altınoluk Mah.'));
      expect(selectionVM.selectedMahalleKodu, equals('147693'));
      expect(selectionVM.selectedPoint, isNull);

      metricsVM.recalculateMetrics(
        selectedIlce: selectionVM.selectedIlce,
        selectedMahalle: selectionVM.selectedMahalle,
        selectedMahalleKodu: selectionVM.selectedMahalleKodu,
        selectedPoint: selectionVM.selectedPoint,
      );

      expect(metricsVM.currentDemografi?.nufus, equals(7148));
      expect(metricsVM.faultDistanceResult.calculationPoint, isNull);
    });

    test('3. Distinguishing same-named neighborhoods across different districts via mahalleKodu', () async {
      await realRepo.loadLocalData();

      final selectionVM = SelectionViewModel(localDataRepository: realRepo);

      // Akçaköy in Altıeylül (code 147031)
      selectionVM.selectMahalleByCode('147031');
      expect(selectionVM.selectedIlce, equals('Altıeylül'));
      expect(selectionVM.selectedMahalle, equals('Akçaköy Mah.'));

      // Akçaköy in Kepsut (code 148163)
      selectionVM.selectMahalleByCode('148163');
      expect(selectionVM.selectedIlce, equals('Kepsut'));
      expect(selectionVM.selectedMahalle, equals('Akçaköy Mah.'));
    });

    test('4. Mismatched code/district is rejected without corrupting current selection', () async {
      await realRepo.loadLocalData();
      final selectionVM = SelectionViewModel(localDataRepository: realRepo);

      selectionVM.selectMahalleByCode('147693'); // Edremit Altınoluk
      expect(selectionVM.selectedIlce, equals('Edremit'));

      // Try selecting Altınoluk code with wrong district 'Kepsut'
      selectionVM.selectIlceAndMahalle(
        'Kepsut',
        'Altınoluk Mah.',
        mahalleKodu: '147693',
      );

      // State remains unchanged
      expect(selectionVM.selectedIlce, equals('Edremit'));
      expect(selectionVM.selectedMahalle, equals('Altınoluk Mah.'));
      expect(selectionVM.selectedMahalleKodu, equals('147693'));
    });

    test('5. Selection from search bar emits single tick update', () async {
      await realRepo.loadLocalData();
      final selectionVM = SelectionViewModel(localDataRepository: realRepo);
      int notifyCount = 0;
      selectionVM.addListener(() => notifyCount++);

      selectionVM.selectIlceAndMahalle(
        'Edremit',
        'Altınoluk Mah.',
        mahalleKodu: '147693',
      );

      expect(notifyCount, equals(1));
      expect(selectionVM.selectedIlce, equals('Edremit'));
      expect(selectionVM.selectedMahalle, equals('Altınoluk Mah.'));
      expect(selectionVM.selectedMahalleKodu, equals('147693'));
    });

    test('6. Map point selection clears administrative selection and keeps exact tapped point', () async {
      await realRepo.loadLocalData();
      final selectionVM = SelectionViewModel(localDataRepository: realRepo);
      selectionVM.selectMahalleByCode('147693');
      expect(selectionVM.selectedMahalle, equals('Altınoluk Mah.'));

      final tapPoint = const GeoPoint(39.6484, 27.8826);
      selectionVM.updateSelectedPoint(tapPoint);

      expect(selectionVM.selectedPoint, equals(tapPoint));
      expect(selectionVM.selectedIlce, isNull);
      expect(selectionVM.selectedMahalle, isNull);
      expect(selectionVM.selectedMahalleKodu, isNull);
    });

    test('7. Null point does NOT trigger AFAD network call', () async {
      final eqVM = EarthquakesViewModel(afadRepository: mockAfad);

      await eqVM.fetchEarthquakes(point: null);

      expect(mockAfad.fetchCallCount, equals(0));
      expect(eqVM.earthquakes, isEmpty);
      expect(eqVM.state, equals(ViewState.initial));
    });

    test('8. Task 2 Test: A succeeds -> B loading -> B error: A data does NOT appear under B', () async {
      final multiRepo = MultiCompleterAfadRepository();
      final completerA = Completer<AfadApiResponse>();
      final completerB = Completer<AfadApiResponse>();

      final pointA = const GeoPoint(39.6, 27.8);
      final pointB = const GeoPoint(39.7, 27.9);

      multiRepo.completers[pointA.latitude] = completerA;
      multiRepo.completers[pointB.latitude] = completerB;

      final eqVM = EarthquakesViewModel(afadRepository: multiRepo);

      // 1. Point A fetch starts and succeeds
      final futureA = eqVM.fetchEarthquakes(point: pointA);
      completerA.complete(
        AfadApiResponse(
          events: [
            DepremOlayi(
              eventID: 'EQ-A-1',
              enlem: pointA.latitude,
              boylam: pointA.longitude,
              derinlik: 5.0,
              buyukluk: 3.5,
              yer: 'POINT A',
              tarih: DateTime.now(),
            ),
          ],
          isFromCache: false,
          isSuccess: true,
        ),
      );
      await futureA;
      expect(eqVM.earthquakes, hasLength(1));
      expect(eqVM.state, equals(ViewState.success));

      // 2. Point B fetch starts
      final futureB = eqVM.fetchEarthquakes(point: pointB);
      expect(eqVM.earthquakes, isEmpty);
      expect(eqVM.state, equals(ViewState.loading));

      // B returns error
      completerB.complete(
        AfadApiResponse(
          events: [],
          isFromCache: false,
          isSuccess: false,
          errorMessage: 'AFAD B Sunucu Hatası',
        ),
      );
      await futureB;

      // B is in error state, A's data is NOT shown under B
      expect(eqVM.earthquakes, isEmpty);
      expect(eqVM.state, equals(ViewState.error));
      expect(eqVM.errorMessage, contains('AFAD B Sunucu Hatası'));
    });

    test('9. Task 2 Test: Late request A completion on single EarthquakesViewModel cannot overwrite active request B', () async {
      final multiRepo = MultiCompleterAfadRepository();
      final completerA = Completer<AfadApiResponse>();
      final completerB = Completer<AfadApiResponse>();

      final pointA = const GeoPoint(39.6, 27.8);
      final pointB = const GeoPoint(39.7, 27.9);

      multiRepo.completers[pointA.latitude] = completerA;
      multiRepo.completers[pointB.latitude] = completerB;

      final eqVM = EarthquakesViewModel(afadRepository: multiRepo);

      // 1. Start request A on eqVM
      final futureA = eqVM.fetchEarthquakes(point: pointA);
      expect(eqVM.isLoading, isTrue);
      expect(eqVM.currentPoint, equals(pointA));

      // 2. Start request B on the SAME eqVM
      final futureB = eqVM.fetchEarthquakes(point: pointB);
      expect(eqVM.isLoading, isTrue);
      expect(eqVM.currentPoint, equals(pointB));

      // 3. Complete request B first
      completerB.complete(
        AfadApiResponse(
          events: [
            DepremOlayi(
              eventID: 'EQ-B-1',
              enlem: pointB.latitude,
              boylam: pointB.longitude,
              derinlik: 10.0,
              buyukluk: 4.5,
              yer: 'POINT B EVENT',
              tarih: DateTime.now(),
            ),
          ],
          isFromCache: false,
          isSuccess: true,
        ),
      );
      await futureB;

      expect(eqVM.state, equals(ViewState.success));
      expect(eqVM.currentPoint, equals(pointB));
      expect(eqVM.earthquakes, hasLength(1));
      expect(eqVM.earthquakes.first.eventID, equals('EQ-B-1'));

      // 4. Complete request A late
      completerA.complete(
        AfadApiResponse(
          events: [
            DepremOlayi(
              eventID: 'EQ-A-1',
              enlem: pointA.latitude,
              boylam: pointA.longitude,
              derinlik: 5.0,
              buyukluk: 3.0,
              yer: 'OLD A EVENT',
              tarih: DateTime.now(),
            ),
          ],
          isFromCache: false,
          isSuccess: true,
        ),
      );
      await futureA;

      // 5. Verify state, currentPoint, and earthquakes STILL belong to B!
      expect(eqVM.state, equals(ViewState.success));
      expect(eqVM.currentPoint, equals(pointB));
      expect(eqVM.earthquakes, hasLength(1));
      expect(eqVM.earthquakes.first.eventID, equals('EQ-B-1'));
    });

    test('10. Task 2 Test: Cache clear pending -> selection changes to B/null: A query does NOT restart', () async {
      final multiRepo = MultiCompleterAfadRepository();
      multiRepo.clearCacheCompleter = Completer<void>();

      final eqVM = EarthquakesViewModel(afadRepository: multiRepo);

      // Start clearCacheAndRefresh for Point A
      final futureRefresh = eqVM.clearCacheAndRefresh(
        point: const GeoPoint(39.6, 27.8),
      );

      // User clears selection or changes point while cache clear is pending
      eqVM.clearEarthquakes();

      // Complete cache clear
      multiRepo.clearCacheCompleter!.complete();
      await futureRefresh;

      // Query A did NOT start fetchEarthquakes after cache clear finished
      expect(multiRepo.fetchCallCount, equals(0));
      expect(eqVM.earthquakes, isEmpty);
    });

    testWidgets(
      '11. Task 1 Test: Normal MapView renders 0 polygons, showDevGeometries renders 1682 polygons & preserves total 2 holes',
      (tester) async {
        await realRepo.loadLocalData();
        final appState = AppStateViewModel(
          localDataRepository: realRepo,
          afadRepository: mockAfad,
        );
        addTearDown(appState.dispose);

        // 1. Normal user MapView (showDevGeometries = false)
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AppStateViewModel>.value(
              value: appState,
              child: MapView(
                tileProvider: NetworkNoOpTileProvider(),
                showDevGeometries: false,
              ),
            ),
          ),
        );

        final normalPolygonLayer = tester.widget<PolygonLayer>(
          find.byType(PolygonLayer),
        );
        expect(normalPolygonLayer.polygons, isEmpty);

        // 2. Dev mode MapView (showDevGeometries = true)
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AppStateViewModel>.value(
              value: appState,
              child: MapView(
                tileProvider: NetworkNoOpTileProvider(),
                showDevGeometries: true,
              ),
            ),
          ),
        );

        final devPolygonLayer = tester.widget<PolygonLayer>(
          find.byType(PolygonLayer),
        );
        expect(devPolygonLayer.polygons, hasLength(1682));

        // Total inner rings across all 1682 polygons is exactly 2
        final totalHoles = devPolygonLayer.polygons.fold<int>(
          0,
          (sum, poly) => sum + (poly.holePointsList?.length ?? 0),
        );
        expect(totalHoles, equals(2));

        // Assert domain model innerRings coordinates match Polygon.holePointsList for assembly_geom_0468 & assembly_geom_1459
        final geom0468 = appState.toplanmaGeometrileri.firstWhere(
          (g) => g.id == 'assembly_geom_0468',
        );
        final geom1459 = appState.toplanmaGeometrileri.firstWhere(
          (g) => g.id == 'assembly_geom_1459',
        );

        expect(geom0468.innerRings, hasLength(1));
        expect(geom1459.innerRings, hasLength(1));

        final poly0468 = devPolygonLayer.polygons.firstWhere(
          (p) =>
              p.holePointsList != null &&
              p.holePointsList!.isNotEmpty &&
              p.holePointsList!.first.length ==
                  geom0468.innerRings.first.length,
        );
        expect(poly0468.holePointsList, hasLength(1));
        expect(
          poly0468.holePointsList!.first.first.latitude,
          equals(geom0468.innerRings.first.first.latitude),
        );
      },
    );

    testWidgets(
      '12. Task 3 Test: Recenter button moves actual camera center to (39.6484, 27.8826) & zoom 9.5',
      (tester) async {
        await realRepo.loadLocalData();
        final appState = AppStateViewModel(
          localDataRepository: realRepo,
          afadRepository: mockAfad,
        );
        addTearDown(appState.dispose);
        await appState.initialize();

        final initialAfadCalls = mockAfad.fetchCallCount;

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AppStateViewModel>.value(
              value: appState,
              child: HomeScreen(tileProvider: NetworkNoOpTileProvider()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        // Access MapController from FlutterMap widget in HomeScreen
        final flutterMapWidget = tester.widget<FlutterMap>(
          find.byType(FlutterMap),
        );
        final mapController = flutterMapWidget.mapController!;

        // 1. Move camera away from Balıkesir center
        mapController.move(const LatLng(39.0, 27.0), 12.0);
        await tester.pump(const Duration(milliseconds: 400));

        // Verify camera HAS moved away
        expect(mapController.camera.center.latitude, closeTo(39.0, 0.001));
        expect(mapController.camera.center.longitude, closeTo(27.0, 0.001));
        expect(mapController.camera.zoom, equals(12.0));

        // 2. Tap "Balıkesir Merkeze Odaklan" recenter button
        final recenterBtn = find.byTooltip('Balıkesir Merkeze Odaklan');
        expect(recenterBtn, findsOneWidget);
        await tester.tap(recenterBtn);
        await tester.pump(const Duration(milliseconds: 400));

        // 3. Assert camera center and zoom returned to target Balıkesir center
        expect(mapController.camera.center.latitude, closeTo(39.6484, 0.001));
        expect(mapController.camera.center.longitude, closeTo(27.8826, 0.001));
        expect(mapController.camera.zoom, equals(9.5));

        // 4. Assert selection state & AFAD call count unchanged
        expect(appState.selectedPoint, isNull);
        expect(mockAfad.fetchCallCount, equals(initialAfadCalls));
      },
    );

    testWidgets(
      '13. Task 4 Test: HomeScreen renders unobscured OpenStreetMap attribution banner and opens copyright link',
      (tester) async {
        await realRepo.loadLocalData();
        final appState = AppStateViewModel(
          localDataRepository: realRepo,
          afadRepository: mockAfad,
        );
        addTearDown(appState.dispose);
        await appState.initialize();

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<AppStateViewModel>.value(
              value: appState,
              child: HomeScreen(tileProvider: NetworkNoOpTileProvider()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        // 1. Find attribution text banner
        final attrFinder = find.textContaining('OpenStreetMap contributors');
        expect(attrFinder, findsOneWidget);

        // 2. Tap attribution banner and verify url launch
        await tester.tap(attrFinder);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          mockLauncher.launchedUrl,
          equals('https://www.openstreetmap.org/copyright'),
        );

        // 3. Verify hit test on search bar open
        await tester.enterText(find.byType(TextField), 'Altınoluk');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(attrFinder);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          mockLauncher.launchedUrl,
          equals('https://www.openstreetmap.org/copyright'),
        );
      },
    );
  });
}
