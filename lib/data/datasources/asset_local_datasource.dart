import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../domain/entities/fay_segmenti.dart';
import '../../domain/entities/ilce_demografi.dart';
import '../../domain/entities/mahalle_nufus.dart';
import '../../domain/entities/toplanma_geometri.dart';
import '../../domain/entities/toplanma_metadata.dart';
import '../models/fay_segmenti_dto.dart';
import '../models/ilce_demografi_dto.dart';
import '../models/mahalle_nufus_dto.dart';
import '../models/toplanma_geometri_dto.dart';
import '../models/toplanma_metadata_dto.dart';

class AssetLoadException implements Exception {
  final String message;
  final String assetPath;
  final dynamic cause;

  AssetLoadException(this.message, {required this.assetPath, this.cause});

  @override
  String toString() =>
      'AssetLoadException: $message (asset: $assetPath, cause: $cause)';
}

class AssetLocalDataSource {
  final Future<String> Function(String path)? _assetLoader;

  AssetLocalDataSource({Future<String> Function(String path)? assetLoader})
    : _assetLoader = assetLoader ?? rootBundle.loadString;

  Future<List<MahalleNufus>> loadMahalleNufusData() async {
    try {
      final jsonString = await _assetLoader!(AppConstants.mahalleNufusJsonPath);
      final Map<String, dynamic> rootJson = jsonDecode(jsonString);
      if (!rootJson.containsKey('records') || rootJson['records'] is! List) {
        throw FormatException('Root JSON missing required "records" list');
      }
      final List<dynamic> recordsJson = rootJson['records'] as List<dynamic>;
      return recordsJson
          .map((e) => MahalleNufusDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AssetLoadException(
        'Mahalle nüfusu varlık dosyası yüklenemedi veya çözümlenemedi',
        assetPath: AppConstants.mahalleNufusJsonPath,
        cause: e,
      );
    }
  }

  Future<List<IlceDemografi>> loadIlceDemografiData() async {
    try {
      final jsonString = await _assetLoader!(
        AppConstants.ilceDemografiJsonPath,
      );
      final Map<String, dynamic> rootJson = jsonDecode(jsonString);
      if (!rootJson.containsKey('records') || rootJson['records'] is! List) {
        throw FormatException('Root JSON missing required "records" list');
      }
      final List<dynamic> recordsJson = rootJson['records'] as List<dynamic>;
      return recordsJson
          .map((e) => IlceDemografiDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AssetLoadException(
        'İlçe demografi varlık dosyası yüklenemedi veya çözümlenemedi',
        assetPath: AppConstants.ilceDemografiJsonPath,
        cause: e,
      );
    }
  }

  Future<ToplanmaMetadata> loadToplanmaMetadata() async {
    try {
      final jsonString = await _assetLoader!(
        AppConstants.toplanmaMetadataJsonPath,
      );
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return ToplanmaMetadataDto.fromJson(jsonMap);
    } catch (e) {
      throw AssetLoadException(
        'Toplanma alanları metadata dosyası yüklenemedi veya çözümlenemedi',
        assetPath: AppConstants.toplanmaMetadataJsonPath,
        cause: e,
      );
    }
  }

  Future<List<ToplanmaGeometri>> loadToplanmaGeometrileriData() async {
    try {
      final jsonString = await _assetLoader!(
        AppConstants.toplanmaGeometrileriGeoJsonPath,
      );
      final Map<String, dynamic> rootJson = jsonDecode(jsonString);
      if (!rootJson.containsKey('features') || rootJson['features'] is! List) {
        throw FormatException('GeoJSON missing required "features" list');
      }
      final List<dynamic> featuresJson = rootJson['features'] as List<dynamic>;
      return featuresJson
          .map((e) => ToplanmaGeometriDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AssetLoadException(
        'Toplanma geometrileri varlık dosyası yüklenemedi veya geçersiz şema',
        assetPath: AppConstants.toplanmaGeometrileriGeoJsonPath,
        cause: e,
      );
    }
  }

  Future<List<FaySegmenti>> loadFayHatlariData() async {
    try {
      final geoJsonString = await _assetLoader!(
        AppConstants.fayHatlariGeoJsonPath,
      );
      final Map<String, dynamic> geoJson = jsonDecode(geoJsonString);

      if (!geoJson.containsKey('features') || geoJson['features'] is! List) {
        throw FormatException('Fay GeoJSON missing required "features" list');
      }

      final List<dynamic> features = geoJson['features'];
      return features
          .map((e) => FaySegmentiDto.fromJson(e as Map<String, dynamic>))
          .where((segment) => segment.subLines.isNotEmpty)
          .toList();
    } catch (e) {
      throw AssetLoadException(
        'Fay hatları GeoJSON varlık dosyası yüklenemedi veya henüz üretilmedi',
        assetPath: AppConstants.fayHatlariGeoJsonPath,
        cause: e,
      );
    }
  }
}
