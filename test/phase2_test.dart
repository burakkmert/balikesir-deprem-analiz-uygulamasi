import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:afet_analiz/app/app.dart';
import 'package:afet_analiz/core/utils/rate_limiter.dart';
import 'package:afet_analiz/domain/entities/fay_segmenti.dart';
import 'package:afet_analiz/domain/entities/geo_point.dart';
import 'package:afet_analiz/domain/services/spatial_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 & 4.2 Tests', () {
    test('GeoUtils Haversine distance test', () {
      final p1 = const GeoPoint(39.6484, 27.8826); // Balıkesir Center
      final p2 = const GeoPoint(39.6542, 27.8864); // Nearby point
      final distance = SpatialAnalysisService.haversineDistanceKm(p1, p2);

      expect(distance, greaterThan(0.0));
      expect(distance, lessThan(2.0)); // Should be less than 2 km
    });

    test('GeoUtils min distance to fault lines test', () {
      final point = const GeoPoint(39.6484, 27.8826);
      final fault = FaySegmenti(
        id: 'F1',
        slipType: 'Strike-Slip',
        subLines: [
          [const GeoPoint(39.6000, 27.8000), const GeoPoint(39.7000, 27.9000)],
        ],
      );

      final minDistance =
          SpatialAnalysisService.calculateMinDistanceToFaultLines(point, [
            fault,
          ]);
      expect(minDistance.isFinite, isTrue);
      expect(minDistance, greaterThan(0.0));
    });

    test('RateLimiter limit enforcement test', () {
      final limiter = RateLimiter(
        maxRequestsPerWindow: 3,
        windowDuration: const Duration(seconds: 10),
      );

      expect(limiter.checkAndRecord(), isTrue);
      expect(limiter.checkAndRecord(), isTrue);
      expect(limiter.checkAndRecord(), isTrue);
      expect(limiter.checkAndRecord(), isFalse);

      expect(
        () => limiter.checkAndRecord(enforce: true),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('requestMapFocus preserves analysis selection', () {
      final module = AfetAnalizAppModule();
      final appState = module.createAppState();
      appState.selectIlceAndMahalle('ALTIEYLÜL', 'BAHÇELİEVLER');

      expect(appState.selectedIlce, equals('ALTIEYLÜL'));
      expect(appState.selectedMahalle, equals('BAHÇELİEVLER'));

      // Request camera focus to assembly area
      appState.requestMapFocus(const LatLng(39.5, 27.5));

      // Map focus target is set for camera
      expect(appState.mapFocusTarget, equals(const LatLng(39.5, 27.5)));

      // Analytical selection remains UNCHANGED
      expect(appState.selectedIlce, equals('ALTIEYLÜL'));
      expect(appState.selectedMahalle, equals('BAHÇELİEVLER'));

      appState.clearMapFocus();
      expect(appState.mapFocusTarget, isNull);

      appState.dispose();
      module.dispose();
    });
  });
}
