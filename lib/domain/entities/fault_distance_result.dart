import 'geo_point.dart';

enum FaultDistanceStatus { success, noFaultData, outOfScope, error }

class FaultDistanceResult {
  final FaultDistanceStatus status;
  final double? distanceKm;
  final String? nearestFaultId;
  final String? nearestFaultCatalogId;
  final GeoPoint? calculationPoint;

  const FaultDistanceResult({
    required this.status,
    this.distanceKm,
    this.nearestFaultId,
    this.nearestFaultCatalogId,
    this.calculationPoint,
  });

  bool get isSuccess =>
      status == FaultDistanceStatus.success && distanceKm != null;

  @override
  String toString() {
    return 'FaultDistanceResult(status: $status, distanceKm: $distanceKm, nearestFaultId: $nearestFaultId)';
  }
}
