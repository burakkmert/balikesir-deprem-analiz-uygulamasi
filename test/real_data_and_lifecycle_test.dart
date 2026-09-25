import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:afet_analiz/data/datasources/asset_local_datasource.dart';
import 'package:afet_analiz/data/models/fay_segmenti_dto.dart';
import 'package:afet_analiz/data/models/ilce_demografi_dto.dart';
import 'package:afet_analiz/data/models/mahalle_nufus_dto.dart';
import 'package:afet_analiz/data/repositories/local_data_repository_impl.dart';
import 'package:afet_analiz/domain/entities/fay_segmenti.dart';
import 'package:afet_analiz/domain/entities/fault_distance_result.dart';
import 'package:afet_analiz/domain/entities/earthquake_query.dart';
import 'package:afet_analiz/domain/entities/geo_point.dart';
import 'package:afet_analiz/domain/repositories/afad_repository.dart';
import 'package:afet_analiz/domain/services/spatial_analysis_service.dart';
import 'package:afet_analiz/presentation/viewmodels/earthquakes_viewmodel.dart';

class MockAssetLoader {
  static Future<String> loadAssetFromFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('File not found: $path');
    }
    return file.readAsString(encoding: utf8);
  }
}

class ControlledAfadRepository implements AfadRepository {
  bool shouldDelay = false;

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
    if (shouldDelay) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return AfadApiResponse(events: [], isSuccess: true);
  }

  @override
  Future<void> clearCache() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 5 Acceptance & Pipeline Rigorous Tests', () {
    test('1. Generated demography JSON files match reference counts, totals, and sample values', () async {
      final popFile = File('assets/data/balikesir_mahalle_nufus.json');
      final ageFile = File('assets/data/balikesir_ilce_demografi.json');

      expect(popFile.existsSync(), isTrue);
      expect(ageFile.existsSync(), isTrue);

      final popJson = jsonDecode(popFile.readAsStringSync(encoding: utf8));
      final ageJson = jsonDecode(ageFile.readAsStringSync(encoding: utf8));

      final List records = popJson['records'];
      final List ageRecords = ageJson['records'];

      expect(records.length, equals(1133));
      expect(ageRecords.length, equals(20));

      final int totalPop = records.fold(
        0,
        (sum, item) => sum + (item['nufus'] as int),
      );
      expect(totalPop, equals(1284514));

      // Altınoluk check
      final altinoluk = records.firstWhere(
        (r) => r['mahalle_ad'] == 'Altınoluk Mah.' && r['ilce_ad'] == 'Edremit',
      );
      expect(altinoluk['nufus'], equals(7148));

      // Susurluk check
      final susurluk = ageRecords.firstWhere(
        (r) => r['ilce_ad'] == 'Susurluk',
        orElse: () => null,
      );
      expect(susurluk, isNotNull);

      // Edremit age dependency checks
      final edremitAge = ageRecords.firstWhere(
        (r) => r['ilce_ad'] == 'Edremit',
      );
      expect(edremitAge['cocuk_bagimlilik'], equals(24.44));
      expect(edremitAge['toplam_bagimlilik'], equals(56.59));
      expect(edremitAge['yasli_bagimlilik'], equals(32.16));
    });

    test('2. LocalDataRepositoryImpl parses generated JSON files and links district indicators', () async {
      final dataSource = AssetLocalDataSource(
        assetLoader: (path) async {
          return File(path).readAsString(encoding: utf8);
        },
      );

      final repository = LocalDataRepositoryImpl(assetDataSource: dataSource);
      await repository.loadLocalData();

      expect(repository.isDemografiLoaded, isTrue);
      expect(repository.mahalleNufusList.length, equals(1133));
      expect(repository.ilceDemografiList.length, equals(20));

      final demografi = repository.getDemografi('Edremit', 'Altınoluk Mah.');
      expect(demografi, isNotNull);
      expect(demografi!.nufus, equals(7148));
      expect(demografi.ilceDemografi, isNotNull);
      expect(demografi.toplamBagimlilik, equals(56.59));
    });

    test('3. DTO Schema strictness: Missing or corrupt values throw FormatException', () {
      expect(
        () => MahalleNufusDto.fromJson({
          'mahalle_kodu': '101',
          'mahalle_ad': 'Test',
          'ilce_ad': 'Test',
          'nufus': -500, // Negative population invalid
          'yil': 2025,
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => IlceDemografiDto.fromJson({
          'ilce_kodu': '201',
          'ilce_ad': 'Test',
          'cocuk_bagimlilik': 'invalid_float',
          'toplam_bagimlilik': 40.0,
          'yasli_bagimlilik': 20.0,
          'yil': 2025,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('4. AssetLocalDataSource throws AssetLoadException when records/features key is missing', () async {
      final dataSource = AssetLocalDataSource(
        assetLoader: (path) async {
          return jsonEncode({'wrong_key': []});
        },
      );

      expect(
        () => dataSource.loadMahalleNufusData(),
        throwsA(isA<AssetLoadException>()),
      );
    });

    test('5. Step 5 Acceptance: Real Toplanma GeoJSON outer and inner rings are preserved in domain entities', () async {
      final dataSource = AssetLocalDataSource(
        assetLoader: (path) async {
          return File(path).readAsString(encoding: utf8);
        },
      );

      final geometriler = await dataSource.loadToplanmaGeometrileriData();
      expect(geometriler.length, equals(1682));

      int totalInnerRings = 0;
      for (final g in geometriler) {
        expect(g.outerRing.length, greaterThanOrEqualTo(4));
        totalInnerRings += g.innerRings.length;
      }

      expect(totalInnerRings, equals(2));

      final withInner = geometriler.firstWhere((g) => g.innerRings.isNotEmpty);
      expect(withInner.innerRings.first.length, greaterThanOrEqualTo(4));
    });

    test('6. Step 5 Acceptance: Generated Fault GeoJSON and Metadata match reference counts (60 features, EUR_TRCS014)', () async {
      final faultFile = File('assets/data/balikesir_fay_hatlari.geojson');
      final metaFile = File('assets/data/balikesir_fay_metadata.json');

      expect(faultFile.existsSync(), isTrue);
      expect(metaFile.existsSync(), isTrue);

      final faultJson = jsonDecode(faultFile.readAsStringSync(encoding: utf8));
      final metaJson = jsonDecode(metaFile.readAsStringSync(encoding: utf8));

      expect(faultJson['type'], equals('FeatureCollection'));
      expect((faultJson['features'] as List).length, equals(60));

      expect(metaJson['global_feature_count'], equals(16195));
      expect(metaJson['selected_feature_count'], equals(60));

      final eurFound = (faultJson['features'] as List).any((f) {
        final props = f['properties'] ?? {};
        return strContains(props, 'EUR_TRCS014');
      });
      expect(eurFound, isTrue);
    });

    test('7. Step 5 Acceptance: FaySegmentiDto round-trip JSON contract and catalogId isolation', () {
      const orig = FaySegmenti(
        id: 'fault_geom_0001',
        catalogId: 'EUR_TRCS014',
        catalogName: 'MTA_CATALOG_2025',
        slipType: 'Strike-Slip',
        subLines: [
          [GeoPoint(39.5, 27.5), GeoPoint(39.6, 27.6)],
          [GeoPoint(39.7, 27.7), GeoPoint(39.8, 27.8)],
        ],
      );

      final jsonMap = FaySegmentiDto.toJson(orig);
      final decoded = FaySegmentiDto.fromJson(jsonMap);

      expect(decoded.id, equals(orig.id));
      expect(decoded.catalogId, equals('EUR_TRCS014'));
      expect(decoded.catalogName, equals('MTA_CATALOG_2025'));
      expect(decoded.subLines.length, equals(2));
      expect(decoded.subLines[0].length, equals(2));
      expect(decoded.subLines[1].length, equals(2));
    });

    test('8. Step 5 Acceptance: SpatialAnalysisService Golden Section Search vs independent geometric reference', () {
      // Horizontal segment at latitude 40.0° N from longitude 27.0° E to 28.0° E
      const p1 = GeoPoint(40.0, 27.0);
      const p2 = GeoPoint(40.0, 28.0);

      // Point at (40.5° N, 27.5° E).
      // Closest point on segment is (40.0° N, 27.5° E).
      // Latitude difference = 0.5°.
      // Haversine distance for 0.5° latitude = 0.5 * 111.1949 km ~ 55.597 km.
      const target = GeoPoint(40.5, 27.5);

      final dist = SpatialAnalysisService.distanceToSegmentKm(target, p1, p2);
      final expectedReferenceKm = SpatialAnalysisService.haversineDistanceKm(
        target,
        const GeoPoint(40.0, 27.5),
      );

      expect((dist - expectedReferenceKm).abs(), lessThan(0.001));
      expect((dist - 55.597).abs(), lessThan(0.1));

      // Out of scope check (target point outside bounding box 26.3..28.9 x 39.1..40.7)
      const outOfScopeTarget = GeoPoint(35.0, 20.0);
      final outResult = SpatialAnalysisService.calculateFaultDistanceResult(
        outOfScopeTarget,
        [
          const FaySegmenti(
            id: 'F1',
            subLines: [
              [p1, p2],
            ],
          ),
        ],
      );
      expect(outResult.status, equals(FaultDistanceStatus.outOfScope));

      // Non-finite coordinate check
      const invalidTarget = GeoPoint(double.nan, 27.5);
      final errResult = SpatialAnalysisService.calculateFaultDistanceResult(
        invalidTarget,
        [
          const FaySegmenti(
            id: 'F1',
            subLines: [
              [p1, p2],
            ],
          ),
        ],
      );
      expect(errResult.status, equals(FaultDistanceStatus.error));
    });

    test('9. Step 5 Acceptance: Disposed ViewModel ignores late async completion without throwing', () async {
      final fakeAfad = ControlledAfadRepository()..shouldDelay = true;
      final eqVM = EarthquakesViewModel(afadRepository: fakeAfad);

      final future = eqVM.fetchEarthquakes(
        point: const GeoPoint(39.6484, 27.8826),
      );
      eqVM.dispose();

      expect(eqVM.isDisposed, isTrue);
      await future;
    });
  });
}

bool strContains(dynamic obj, String target) {
  return obj.toString().contains(target);
}
