import 'geo_point.dart';

class ToplanmaGeometri {
  final String id;
  final String? sourcePlacemarkId;
  final bool isPerAreaAttributeMatched;
  final List<GeoPoint> outerRing;
  final List<List<GeoPoint>> innerRings;

  const ToplanmaGeometri({
    required this.id,
    this.sourcePlacemarkId,
    this.isPerAreaAttributeMatched = false,
    required this.outerRing,
    required this.innerRings,
  });

  @override
  String toString() {
    return 'ToplanmaGeometri(id: $id, outerRingPoints: ${outerRing.length}, innerRingsCount: ${innerRings.length})';
  }
}
