import 'geo_point.dart';

class FaySegmenti {
  final String id;
  final String? catalogId;
  final String? catalogName;
  final String? slipType;
  final List<List<GeoPoint>> subLines;

  const FaySegmenti({
    required this.id,
    this.catalogId,
    this.catalogName,
    this.slipType,
    required this.subLines,
  });

  /// Backward-compatible getter returning all points flattened
  List<GeoPoint> get coordinates => subLines.expand((line) => line).toList();

  @override
  String toString() {
    return 'FaySegmenti(id: $id, catalogId: $catalogId, subLinesCount: ${subLines.length})';
  }
}
