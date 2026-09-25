import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:afet_analiz/data/datasources/asset_local_datasource.dart';
import 'package:afet_analiz/data/models/fay_segmenti_dto.dart';
import 'package:afet_analiz/data/models/toplanma_geometri_dto.dart';
import 'package:afet_analiz/data/repositories/local_data_repository_impl.dart';

void main() {
  group('Step 5 Dart Coordinate Validation & Repository Isolation Tests', () {
    test('1. ToplanmaGeometriDto throws FormatException on invalid/NaN coords or unclosed ring', () {
      // Unclosed ring (first != last)
      final unclosedJson = {
        'type': 'Feature',
        'id': 'g1',
        'properties': {'id': 'g1', 'source_placemark_id': 'PM1'},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [27.8, 39.6],
              [27.9, 39.6],
              [27.9, 39.7],
              [27.85, 39.65], // Not matching [27.8, 39.6]
            ],
          ],
        },
      };
      expect(
        () => ToplanmaGeometriDto.fromJson(unclosedJson),
        throwsA(isA<FormatException>()),
      );

      // Non-numeric string coord
      final invalidStringCoord = {
        'type': 'Feature',
        'id': 'g2',
        'properties': {'id': 'g2'},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [27.8, 39.6],
              ['INVALID', 39.6],
              [27.9, 39.7],
              [27.8, 39.6],
            ],
          ],
        },
      };
      expect(
        () => ToplanmaGeometriDto.fromJson(invalidStringCoord),
        throwsA(isA<FormatException>()),
      );
    });

    test('2. ToplanmaGeometriDto preserves outer and inner rings correctly for valid GeoJSON', () {
      final validJson = {
        'type': 'Feature',
        'id': 'g3',
        'properties': {
          'id': 'g3',
          'source_placemark_id': 'PM_100',
          'is_per_area_attribute_matched': false,
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [27.8, 39.6],
              [27.9, 39.6],
              [27.9, 39.7],
              [27.8, 39.6],
            ],
            [
              [27.82, 39.62],
              [27.88, 39.62],
              [27.88, 39.68],
              [27.82, 39.62],
            ],
          ],
        },
      };

      final geom = ToplanmaGeometriDto.fromJson(validJson);
      expect(geom.id, equals('g3'));
      expect(geom.sourcePlacemarkId, equals('PM_100'));
      expect(geom.outerRing.length, equals(4));
      expect(geom.innerRings.length, equals(1));
      expect(geom.innerRings.first.length, equals(4));
      expect(geom.outerRing.first.latitude, equals(39.6));
      expect(geom.outerRing.first.longitude, equals(27.8));
    });

    test('3. FaySegmentiDto throws FormatException on invalid/NaN coords or short points', () {
      final invalidCoordJson = {
        'type': 'Feature',
        'id': 'f1',
        'properties': {'tech_id': 'f1'},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [27.8, 39.6],
            ['INVALID_LON', 39.7],
          ],
        },
      };
      expect(
        () => FaySegmentiDto.fromJson(invalidCoordJson),
        throwsA(isA<FormatException>()),
      );

      final shortPointJson = {
        'type': 'Feature',
        'id': 'f2',
        'properties': {'tech_id': 'f2'},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [27.8, 39.6],
            [27.9], // Short coordinate point
          ],
        },
      };
      expect(
        () => FaySegmentiDto.fromJson(shortPointJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('4. FaySegmentiDto round-trip JSON serialization preserves multi-lines and catalog fields', () {
      final featureJson = {
        'type': 'Feature',
        'id': 'f3',
        'properties': {
          'tech_id': 'f3',
          'catalog_id': 'CAT_123',
          'catalog_name': 'NAME_XYZ',
          'slipType': 'Normal',
        },
        'geometry': {
          'type': 'MultiLineString',
          'coordinates': [
            [
              [27.8, 39.6],
              [27.85, 39.65],
            ],
            [
              [27.86, 39.66],
              [27.9, 39.7],
            ],
          ],
        },
      };

      final dto = FaySegmentiDto.fromJson(featureJson);
      expect(dto.id, equals('f3'));
      expect(dto.catalogId, equals('CAT_123'));
      expect(dto.catalogName, equals('NAME_XYZ'));
      expect(dto.slipType, equals('Normal'));
      expect(dto.subLines.length, equals(2));

      final jsonOut = FaySegmentiDto.toJson(dto);
      final dtoBack = FaySegmentiDto.fromJson(jsonOut);
      expect(dtoBack.id, equals(dto.id));
      expect(dtoBack.catalogId, equals(dto.catalogId));
      expect(dtoBack.subLines.length, equals(2));
    });

    test('5. LocalDataRepositoryImpl supports partial demography loading and retry', () async {
      int ilceCallCount = 0;

      final customDataSource = AssetLocalDataSource(
        assetLoader: (path) async {
          if (path.contains('mahalle_nufus')) {
            return jsonEncode({
              'records': [
                {
                  'mahalle_kodu': '101',
                  'mahalle_ad': 'MERKEZ',
                  'ilce_ad': 'KARESİ',
                  'nufus': 15000,
                  'yil': 2025,
                },
              ],
            });
          }
          if (path.contains('ilce_demografi')) {
            ilceCallCount++;
            if (ilceCallCount == 1) {
              throw FormatException(
                'Simulated district demography asset error',
              );
            } else {
              return jsonEncode({
                'records': [
                  {
                    'ilce_kodu': '2001',
                    'ilce_ad': 'KARESİ',
                    'cocuk_bagimlilik': 20.5,
                    'toplam_bagimlilik': 40.0,
                    'yasli_bagimlilik': 19.5,
                    'yil': 2025,
                  },
                ],
              });
            }
          }
          if (path.contains('toplanma_geometrileri')) {
            return jsonEncode({'type': 'FeatureCollection', 'features': []});
          }
          if (path.contains('toplanma_metadata')) {
            return jsonEncode({
              'schema_version': 1,
              'source_filename': 'test.kml',
              'source_sha256': 'hash',
              'dataset_url': '',
              'placemark_count': 0,
              'polygon_count': 0,
              'inner_boundary_count': 0,
              'official_distinct_areas_count': null,
              'is_per_area_attribute_matched': false,
              'single_source_record': {},
              'validation_error_count': 0,
            });
          }
          if (path.contains('fay_hatlari')) {
            return jsonEncode({'type': 'FeatureCollection', 'features': []});
          }
          throw Exception('Unknown asset path: $path');
        },
      );

      final repo = LocalDataRepositoryImpl(assetDataSource: customDataSource);

      // First load attempt: Mahalle nufus succeeds, ilce demografi fails
      await repo.loadLocalData();

      expect(repo.isDemografiLoaded, isTrue);
      expect(repo.mahalleNufusList.length, equals(1));
      expect(repo.ilceDemografiList, isEmpty);
      expect(repo.demografiError, isNotNull);
      expect(repo.getDemografi('KARESİ', 'MERKEZ'), isNotNull);

      // Second load attempt (retry): Only ilce demografi is re-attempted and succeeds
      await repo.loadLocalData();

      expect(repo.ilceDemografiList.length, equals(1));
      expect(repo.demografiError, isNull);
      expect(repo.getDemografi('KARESİ', 'MERKEZ')?.ilceDemografi, isNotNull);
    });
  });
}
