import 'package:flutter_test/flutter_test.dart';
import 'package:afet_analiz/data/models/deprem_olayi_dto.dart';
import 'package:afet_analiz/presentation/viewmodels/earthquakes_viewmodel.dart';
import 'package:afet_analiz/domain/entities/deprem_olayi.dart';
import 'package:afet_analiz/domain/repositories/afad_repository.dart';
import 'package:afet_analiz/domain/entities/earthquake_query.dart';

class MockAfadRepository implements AfadRepository {
  List<DepremOlayi> mockEvents = [];
  bool shouldFail = false;
  
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
    if (shouldFail) {
      return AfadApiResponse(
        events: const [],
        isSuccess: false,
        errorMessage: 'Mock Failure',
      );
    }
    return AfadApiResponse(
      events: mockEvents,
      isSuccess: true,
      isFromCache: false,
      isPartial: false,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clearCache() async {}
}

void main() {
  group('Phase 6.2 AFAD Data Pipeline Tests', () {
    test('A. Parsing a REAL-SHAPE AFAD JSON object must produce a valid entity', () {
      final jsonRaw = {
        "eventID": 729056,
        "location": "Sındırgı (Balıkesir)",
        "latitude": 39.23433,
        "longitude": 28.102,
        "depth": 13.28,
        "type": "ML",
        "magnitude": 2.1,
        "country": "Türkiye",
        "province": "Balıkesir",
        "district": "Sındırgı",
        "neighborhood": "Kozlu",
        "date": "2026-09-19T10:05:10",
        "isEventUpdate": false,
        "lastUpdateDate": null
      };

      final deprem = DepremOlayiDto.fromJson(jsonRaw);
      
      expect(deprem.eventID, "729056");
      expect(deprem.enlem, 39.23433);
      expect(deprem.boylam, 28.102);
      expect(deprem.derinlik, 13.28);
      expect(deprem.buyukluk, 2.1);
      expect(deprem.yer, "Sındırgı (Balıkesir)");
      expect(deprem.tarih.year, 2026);
    });

    test('B. A list of multiple real-shape records must not parse to []', () {
      final listRaw = [
        {
          "eventID": 729056,
          "latitude": 39.23433,
          "longitude": 28.102,
          "magnitude": 2.1,
          "date": "2026-09-19T10:05:10",
        },
        {
          "eventID": 729057,
          "latitude": 39.23433,
          "longitude": 28.102,
          "magnitude": 2.5,
          "date": "2026-09-19T11:05:10",
        }
      ];

      final parsedList = listRaw.map((e) => DepremOlayiDto.fromJson(e)).toList();
      expect(parsedList.length, 2);
    });

    test('C. Refresh with successful data must replace an empty state even if point is null', () async {
      final mockRepo = MockAfadRepository();
      final viewModel = EarthquakesViewModel(afadRepository: mockRepo);
      
      // Initially empty
      expect(viewModel.earthquakes.length, 0);

      // Populate mock
      mockRepo.mockEvents = [
        DepremOlayi(
          eventID: '123',
          enlem: 39.0,
          boylam: 27.0,
          buyukluk: 3.0,
          tarih: DateTime.now(),
        )
      ];

      // Point is null, this should fallback to balikesir center instead of clearing
      await viewModel.fetchEarthquakes(point: null, forceRefresh: true);
      
      expect(viewModel.earthquakes.length, 1);
      expect(viewModel.earthquakes.first.eventID, '123');
    });
  });
}
