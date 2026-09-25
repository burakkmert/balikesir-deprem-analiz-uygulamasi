import '../entities/deprem_olayi.dart';
import '../entities/earthquake_query.dart';

class AfadApiResponse {
  final List<DepremOlayi> events;
  final bool isFromCache;
  final bool isSuccess;
  final bool isPartial;
  final String? errorMessage;
  final String? statusNotice;
  final DateTime? fetchedAt;
  final DateTime? requestedAt;
  final EarthquakeQuery? query;
  final int totalRawRecords;
  final int validRecords;
  final int rejectedRecords;
  final int outOfBoundsRecords;

  AfadApiResponse({
    required this.events,
    this.isFromCache = false,
    this.isSuccess = true,
    this.isPartial = false,
    this.errorMessage,
    this.statusNotice,
    this.fetchedAt,
    this.requestedAt,
    this.query,
    this.totalRawRecords = 0,
    this.validRecords = 0,
    this.rejectedRecords = 0,
    this.outOfBoundsRecords = 0,
  });
}

abstract class AfadRepository {
  Future<AfadApiResponse> fetchEarthquakes({
    double lat,
    double lng,
    double radius,
    double minMagnitude,
    DateTime? startDate,
    DateTime? endDate,
    EarthquakeQuery? query,
    bool forceRefresh = false,
  });

  Future<void> clearCache();
}
