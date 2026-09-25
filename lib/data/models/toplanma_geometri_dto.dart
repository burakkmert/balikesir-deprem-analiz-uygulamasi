import '../../domain/entities/geo_point.dart';
import '../../domain/entities/toplanma_geometri.dart';

class ToplanmaGeometriDto {
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

  static ToplanmaGeometri fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('type') || json['type'] != 'Feature') {
      throw FormatException(
        'Invalid GeoJSON feature format for ToplanmaGeometriDto',
      );
    }

    final props = (json['properties'] as Map<String, dynamic>?) ?? {};
    final id = props['id']?.toString() ?? json['id']?.toString() ?? '';
    final sourcePlacemarkId = props['source_placemark_id']?.toString();
    final isMatched = props['is_per_area_attribute_matched'] == true;

    final geometry = json['geometry'] as Map<String, dynamic>?;
    if (geometry == null || geometry['type'] != 'Polygon') {
      throw FormatException(
        'ToplanmaGeometriDto requires Polygon geometry type',
      );
    }

    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.isEmpty) {
      throw FormatException('Polygon coordinates list is empty or invalid');
    }

    final List<GeoPoint> outerRing = _parseRing(coordinates[0], 'outer ring');
    if (outerRing.length < 4) {
      throw FormatException('Outer ring has fewer than 4 valid coordinates');
    }
    if (outerRing.first != outerRing.last) {
      throw FormatException(
        'Outer ring is not closed (first point != last point)',
      );
    }

    final List<List<GeoPoint>> innerRings = [];
    for (int i = 1; i < coordinates.length; i++) {
      final ring = _parseRing(coordinates[i], 'inner ring #$i');
      if (ring.length < 4) {
        throw FormatException(
          'Inner ring #$i has fewer than 4 valid coordinates',
        );
      }
      if (ring.first != ring.last) {
        throw FormatException(
          'Inner ring #$i is not closed (first point != last point)',
        );
      }
      innerRings.add(ring);
    }

    return ToplanmaGeometri(
      id: id,
      sourcePlacemarkId: sourcePlacemarkId,
      isPerAreaAttributeMatched: isMatched,
      outerRing: outerRing,
      innerRings: innerRings,
    );
  }

  static List<GeoPoint> _parseRing(dynamic ringData, String ringName) {
    if (ringData is! List) {
      throw FormatException('$ringName data is not a list');
    }
    final List<GeoPoint> pts = [];
    for (int i = 0; i < ringData.length; i++) {
      final item = ringData[i];
      if (item is! List || item.length < 2) {
        throw FormatException('$ringName point #$i has fewer than 2 elements');
      }
      final double lng = _parseCoord(item[0], '$ringName point #$i longitude');
      final double lat = _parseCoord(item[1], '$ringName point #$i latitude');

      if (lng < -180.0 || lng > 180.0 || lat < -90.0 || lat > 90.0) {
        throw FormatException(
          '$ringName point #$i out of bounds [-180..180, -90..90]: [$lng, $lat]',
        );
      }
      pts.add(GeoPoint(lat, lng));
    }
    return pts;
  }

  static Map<String, dynamic> toJson(ToplanmaGeometri geom) {
    final List<List<List<double>>> rings = [
      geom.outerRing.map((p) => [p.longitude, p.latitude]).toList(),
      ...geom.innerRings.map(
        (ring) => ring.map((p) => [p.longitude, p.latitude]).toList(),
      ),
    ];

    return {
      'type': 'Feature',
      'id': geom.id,
      'properties': {
        'id': geom.id,
        'source_placemark_id': geom.sourcePlacemarkId,
        'is_per_area_attribute_matched': geom.isPerAreaAttributeMatched,
      },
      'geometry': {'type': 'Polygon', 'coordinates': rings},
    };
  }
}
