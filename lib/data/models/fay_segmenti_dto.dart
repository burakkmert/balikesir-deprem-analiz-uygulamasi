import '../../domain/entities/fay_segmenti.dart';
import '../../domain/entities/geo_point.dart';

class FaySegmentiDto {
  static double _parseCoord(dynamic val, String name) {
    if (val == null) {
      throw FormatException('Missing coordinate value for $name');
    }
    if (val is num) {
      final double d = val.toDouble();
      if (d.isNaN || d.isInfinite) {
        throw FormatException('Non-finite coordinate value for $name: $val');
      }
      return d;
    }
    if (val is String) {
      final double? parsed = double.tryParse(val);
      if (parsed == null || parsed.isNaN || parsed.isInfinite) {
        throw FormatException('Invalid numeric coordinate for $name: "$val"');
      }
      return parsed;
    }
    throw FormatException(
      'Unsupported coordinate type for $name: ${val.runtimeType}',
    );
  }

  static FaySegmenti fromJson(Map<String, dynamic> json) {
    String segmentId = '';
    String? catalogId;
    String? catalogName;
    String? slipType;
    List<List<GeoPoint>> subLines = [];

    if (json.containsKey('type') && json['type'] == 'Feature') {
      final properties = json['properties'] as Map<String, dynamic>? ?? {};
      segmentId =
          properties['tech_id']?.toString() ??
          json['id']?.toString() ??
          properties['id']?.toString() ??
          properties['FID']?.toString() ??
          properties['OBJECTID']?.toString() ??
          '';

      catalogId = properties['catalog_id']?.toString();
      catalogName = properties['catalog_name']?.toString();
      slipType =
          properties['slipType']?.toString() ??
          properties['slip_type']?.toString() ??
          properties['SLIP_TYPE']?.toString() ??
          properties['FAY_TIPI']?.toString() ??
          properties['FAY_ADI']?.toString();

      final geometry = json['geometry'] as Map<String, dynamic>?;
      if (geometry != null) {
        final geomType = geometry['type']?.toString();
        final rawCoords = geometry['coordinates'];

        if (geomType == 'LineString' && rawCoords is List) {
          final List<GeoPoint> linePoints = _parsePointList(
            rawCoords,
            'LineString',
          );
          if (linePoints.length < 2) {
            throw FormatException('LineString has fewer than 2 valid points');
          }
          subLines.add(linePoints);
        } else if (geomType == 'MultiLineString' && rawCoords is List) {
          for (int i = 0; i < rawCoords.length; i++) {
            final line = rawCoords[i];
            if (line is List) {
              final List<GeoPoint> linePoints = _parsePointList(
                line,
                'MultiLineString line #$i',
              );
              if (linePoints.length < 2) {
                throw FormatException(
                  'MultiLineString line #$i has fewer than 2 valid points',
                );
              }
              subLines.add(linePoints);
            } else {
              throw FormatException('MultiLineString line #$i is not a list');
            }
          }
        } else {
          throw FormatException(
            'Unsupported or missing geometry in FaySegmentiDto: $geomType',
          );
        }
      }
    } else {
      segmentId = json['id']?.toString() ?? json['tech_id']?.toString() ?? '';
      catalogId =
          json['catalog_id']?.toString() ?? json['catalogId']?.toString();
      catalogName =
          json['catalog_name']?.toString() ?? json['catalogName']?.toString();
      slipType = json['slipType']?.toString() ?? json['slip_type']?.toString();

      final rawCoords = json['subLines'] ?? json['coordinates'];
      if (rawCoords is List) {
        if (rawCoords.isNotEmpty && rawCoords[0] is List) {
          for (int i = 0; i < rawCoords.length; i++) {
            final sub = rawCoords[i];
            if (sub is List) {
              final pts = _parsePointList(sub, 'SubLine #$i');
              if (pts.length < 2) {
                throw FormatException(
                  'SubLine #$i has fewer than 2 valid points',
                );
              }
              subLines.add(pts);
            }
          }
        } else {
          final pts = _parsePointList(rawCoords, 'Coordinates');
          if (pts.length < 2) {
            throw FormatException(
              'Coordinates list has fewer than 2 valid points',
            );
          }
          subLines.add(pts);
        }
      } else {
        throw FormatException(
          'Missing or invalid subLines/coordinates in FaySegmentiDto',
        );
      }
    }

    return FaySegmenti(
      id: segmentId,
      catalogId: catalogId,
      catalogName: catalogName,
      slipType: slipType,
      subLines: subLines,
    );
  }

  static List<GeoPoint> _parsePointList(
    List<dynamic> list,
    String contextName,
  ) {
    final List<GeoPoint> pts = [];
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is List) {
        if (item.length < 2) {
          throw FormatException(
            '$contextName point #$i has fewer than 2 elements',
          );
        }
        final double lng = _parseCoord(
          item[0],
          '$contextName point #$i longitude',
        );
        final double lat = _parseCoord(
          item[1],
          '$contextName point #$i latitude',
        );

        if (lng < -180.0 || lng > 180.0 || lat < -90.0 || lat > 90.0) {
          throw FormatException(
            '$contextName point #$i out of bounds [-180..180, -90..90]: [$lng, $lat]',
          );
        }
        pts.add(GeoPoint(lat, lng));
      } else if (item is Map) {
        final double lat = _parseCoord(
          item['lat'] ?? item['latitude'] ?? item['enlem'],
          '$contextName point #$i latitude',
        );
        final double lng = _parseCoord(
          item['lng'] ?? item['longitude'] ?? item['boylam'],
          '$contextName point #$i longitude',
        );
        if (lng < -180.0 || lng > 180.0 || lat < -90.0 || lat > 90.0) {
          throw FormatException(
            '$contextName point #$i out of bounds [-180..180, -90..90]: [$lng, $lat]',
          );
        }
        pts.add(GeoPoint(lat, lng));
      } else {
        throw FormatException(
          '$contextName point #$i is neither a List nor a Map',
        );
      }
    }
    return pts;
  }

  static Map<String, dynamic> toJson(FaySegmenti segment) {
    return {
      'id': segment.id,
      'catalogId': segment.catalogId,
      'catalogName': segment.catalogName,
      'slipType': segment.slipType,
      'subLines': segment.subLines
          .map((line) => line.map((pt) => [pt.longitude, pt.latitude]).toList())
          .toList(),
    };
  }

  static Map<String, dynamic> toGeoJsonFeature(FaySegmenti segment) {
    final bool isMulti = segment.subLines.length > 1;
    return {
      'type': 'Feature',
      'id': segment.id,
      'properties': {
        'tech_id': segment.id,
        'catalog_id': segment.catalogId,
        'catalog_name': segment.catalogName,
        'slipType': segment.slipType,
      },
      'geometry': {
        'type': isMulti ? 'MultiLineString' : 'LineString',
        'coordinates': isMulti
            ? segment.subLines
                  .map(
                    (line) =>
                        line.map((p) => [p.longitude, p.latitude]).toList(),
                  )
                  .toList()
            : (segment.subLines.isNotEmpty
                  ? segment.subLines.first
                        .map((p) => [p.longitude, p.latitude])
                        .toList()
                  : []),
      },
    };
  }
}
