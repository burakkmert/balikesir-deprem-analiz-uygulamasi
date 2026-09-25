import 'dart:math' as math;

import '../entities/fay_segmenti.dart';
import '../entities/fault_distance_result.dart';
import '../entities/geo_point.dart';
import '../entities/toplanma_alani.dart';

class ToplanmaAlaniWithDistance {
  final ToplanmaAlani area;
  final double distanceKm;

  ToplanmaAlaniWithDistance({required this.area, required this.distanceKm});

  @override
  String toString() {
    return '${area.ad} (${distanceKm.toStringAsFixed(2)} km)';
  }
}

class SpatialAnalysisService {
  static const double earthRadiusKm = 6371.0;

  // Regional bounding box scope matching dataset metadata
  static const double minLon = 26.3;
  static const double maxLon = 28.9;
  static const double minLat = 39.1;
  static const double maxLat = 40.7;

  /// Calculate Haversine distance in kilometers between two GeoPoint coordinates
  static double haversineDistanceKm(GeoPoint p1, GeoPoint p2) {
    final double dLat = _degreesToRadians(p2.latitude - p1.latitude);
    final double dLon = _degreesToRadians(p2.longitude - p1.longitude);

    final double lat1 = _degreesToRadians(p1.latitude);
    final double lat2 = _degreesToRadians(p2.latitude);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(lat1) *
            math.cos(lat2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Calculates minimum Haversine distance in km from target [point] to a segment [p1 -> p2]
  /// using Golden Section Search on parameter t in [0, 1].
  /// Note: The 1e-6 threshold is the search interval convergence tolerance on parameter t,
  /// not a 1e-6 km distance precision guarantee.
  static double distanceToSegmentKm(GeoPoint point, GeoPoint p1, GeoPoint p2) {
    if (p1.latitude == p2.latitude && p1.longitude == p2.longitude) {
      return haversineDistanceKm(point, p1);
    }

    double dist(double t) {
      final lat = p1.latitude + t * (p2.latitude - p1.latitude);
      final lng = p1.longitude + t * (p2.longitude - p1.longitude);
      return haversineDistanceKm(point, GeoPoint(lat, lng));
    }

    // Always check endpoints t = 0.0 and t = 1.0 explicitly
    double minDist = math.min(dist(0.0), dist(1.0));

    // Golden section search for local minimum on t in [0.0, 1.0]
    final double gr = (math.sqrt(5) - 1) / 2; // ~0.61803398875
    double a = 0.0;
    double b = 1.0;
    double c = b - gr * (b - a);
    double d = a + gr * (b - a);
    double fc = dist(c);
    double fd = dist(d);

    for (int i = 0; i < 30; i++) {
      if ((b - a).abs() < 1e-6) break;
      if (fc < fd) {
        b = d;
        d = c;
        fd = fc;
        c = b - gr * (b - a);
        fc = dist(c);
      } else {
        a = c;
        c = d;
        fc = fd;
        d = a + gr * (b - a);
        fd = dist(d);
      }
    }

    final double tMin = (a + b) / 2;
    final double candidateDist = dist(tMin);
    return math.min(minDist, candidateDist);
  }

  /// Detailed calculation returning [FaultDistanceResult] with status, distance, and nearest fault ID
  static FaultDistanceResult calculateFaultDistanceResult(
    GeoPoint point,
    List<FaySegmenti> faults,
  ) {
    // Explicit non-finite coordinate check
    if (point.latitude.isNaN ||
        point.latitude.isInfinite ||
        point.longitude.isNaN ||
        point.longitude.isInfinite) {
      return FaultDistanceResult(
        status: FaultDistanceStatus.error,
        calculationPoint: point,
      );
    }

    if (faults.isEmpty) {
      return FaultDistanceResult(
        status: FaultDistanceStatus.noFaultData,
        calculationPoint: point,
      );
    }

    // Regional scope check matching metadata bounding box [minLon=26.3, maxLon=28.9, minLat=39.1, maxLat=40.7]
    if (point.latitude < minLat ||
        point.latitude > maxLat ||
        point.longitude < minLon ||
        point.longitude > maxLon) {
      return FaultDistanceResult(
        status: FaultDistanceStatus.outOfScope,
        calculationPoint: point,
      );
    }

    double minDistanceKm = double.infinity;
    String? nearestFaultId;
    String? nearestFaultCatalogId;

    for (final fault in faults) {
      for (final line in fault.subLines) {
        if (line.isEmpty) continue;
        if (line.length == 1) {
          final dist = haversineDistanceKm(point, line.first);
          if (dist < minDistanceKm) {
            minDistanceKm = dist;
            nearestFaultId = fault.id;
            nearestFaultCatalogId = fault.catalogId;
          }
          continue;
        }

        for (int i = 0; i < line.length - 1; i++) {
          final dist = distanceToSegmentKm(point, line[i], line[i + 1]);
          if (dist < minDistanceKm) {
            minDistanceKm = dist;
            nearestFaultId = fault.id;
            nearestFaultCatalogId = fault.catalogId;
          }
        }
      }
    }

    if (minDistanceKm.isInfinite) {
      return FaultDistanceResult(
        status: FaultDistanceStatus.error,
        calculationPoint: point,
      );
    }

    return FaultDistanceResult(
      status: FaultDistanceStatus.success,
      distanceKm: minDistanceKm,
      nearestFaultId: nearestFaultId,
      nearestFaultCatalogId: nearestFaultCatalogId,
      calculationPoint: point,
    );
  }

  /// Backward-compatible method returning min distance in km
  static double calculateMinDistanceToFaultLines(
    GeoPoint point,
    List<FaySegmenti> faults,
  ) {
    final result = calculateFaultDistanceResult(point, faults);
    return result.distanceKm ?? double.infinity;
  }

  /// Get top N closest assembly areas sorted by distance
  static List<ToplanmaAlaniWithDistance> getClosestToplanmaAlanlari(
    GeoPoint point,
    List<ToplanmaAlani> assemblyAreas, {
    int count = 3,
  }) {
    if (assemblyAreas.isEmpty) return [];

    final listWithDist = assemblyAreas.map((area) {
      final areaPoint = GeoPoint(area.enlem, area.boylam);
      final dist = haversineDistanceKm(point, areaPoint);
      return ToplanmaAlaniWithDistance(area: area, distanceKm: dist);
    }).toList();

    listWithDist.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return listWithDist.take(count).toList();
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
