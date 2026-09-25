import 'geo_point.dart';

enum TimeWindowType { relativeDays, absoluteRange }

class EarthquakeQuery {
  final GeoPoint center;
  final double radiusKm;
  final double minMagnitude;
  final TimeWindowType timeWindowType;
  final int? relativeDays;
  final DateTime? absoluteStartDate;
  final DateTime? absoluteEndDate;

  const EarthquakeQuery({
    required this.center,
    this.radiusKm = 150.0,
    this.minMagnitude = 1.5,
    this.timeWindowType = TimeWindowType.relativeDays,
    this.relativeDays = 30,
    this.absoluteStartDate,
    this.absoluteEndDate,
  });

  factory EarthquakeQuery.relative({
    required GeoPoint center,
    double radiusKm = 150.0,
    double minMagnitude = 1.5,
    int days = 30,
  }) {
    return EarthquakeQuery(
      center: center,
      radiusKm: radiusKm,
      minMagnitude: minMagnitude,
      timeWindowType: TimeWindowType.relativeDays,
      relativeDays: days,
    );
  }

  factory EarthquakeQuery.absolute({
    required GeoPoint center,
    double radiusKm = 150.0,
    double minMagnitude = 1.5,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return EarthquakeQuery(
      center: center,
      radiusKm: radiusKm,
      minMagnitude: minMagnitude,
      timeWindowType: TimeWindowType.absoluteRange,
      absoluteStartDate: startDate,
      absoluteEndDate: endDate,
    );
  }

  void validate() {
    if (center.latitude < -90.0 ||
        center.latitude > 90.0 ||
        center.longitude < -180.0 ||
        center.longitude > 180.0) {
      throw ArgumentError(
        'Geçersiz merkez koordinatı: (${center.latitude}, ${center.longitude})',
      );
    }
    if (radiusKm <= 0 || radiusKm.isNaN || radiusKm.isInfinite) {
      throw ArgumentError('Geçersiz arama yarıçapı: $radiusKm');
    }
    if (minMagnitude.isNaN || minMagnitude.isInfinite) {
      throw ArgumentError('Geçersiz minimum büyüklük: $minMagnitude');
    }
    if (timeWindowType == TimeWindowType.relativeDays) {
      if (relativeDays == null || relativeDays! <= 0) {
        throw ArgumentError('Geçersiz göreli gün sayısı: $relativeDays');
      }
    } else {
      if (absoluteStartDate == null || absoluteEndDate == null) {
        throw ArgumentError('Mutlak zaman aralığı için tarih gerekli.');
      }
      if (absoluteStartDate!.isAfter(absoluteEndDate!)) {
        throw ArgumentError('Başlangıç tarihi bitiş tarihinden sonra olamaz.');
      }
    }
  }

  /// Canonical key string for caching without timestamp jitter
  String get canonicalKey {
    final latStr = center.latitude.toStringAsFixed(4);
    final lngStr = center.longitude.toStringAsFixed(4);
    final rStr = radiusKm.toStringAsFixed(1);
    final mStr = minMagnitude.toStringAsFixed(1);

    if (timeWindowType == TimeWindowType.relativeDays) {
      return 'eq_query_rel_lat:${latStr}_lng:${lngStr}_r:${rStr}_m:${mStr}_d:${relativeDays!}';
    } else {
      final sStr = absoluteStartDate!.toIso8601String();
      final eStr = absoluteEndDate!.toIso8601String();
      return 'eq_query_abs_lat:${latStr}_lng:${lngStr}_r:${rStr}_m:${mStr}_s:${sStr}_e:$eStr';
    }
  }

  /// Resolve real start and end timestamps at execution time
  ({DateTime start, DateTime end}) resolveTimeWindow([
    DateTime Function()? clock,
  ]) {
    validate();
    final now = (clock ?? DateTime.now)();

    if (timeWindowType == TimeWindowType.relativeDays) {
      final end = now;
      final start = now.subtract(Duration(days: relativeDays!));
      return (start: start, end: end);
    } else {
      return (start: absoluteStartDate!, end: absoluteEndDate!);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': center.latitude,
      'lng': center.longitude,
      'radiusKm': radiusKm,
      'minMagnitude': minMagnitude,
      'timeWindowType': timeWindowType.name,
      'relativeDays': relativeDays,
      'absoluteStartDate': absoluteStartDate?.toIso8601String(),
      'absoluteEndDate': absoluteEndDate?.toIso8601String(),
      'canonicalKey': canonicalKey,
    };
  }

  factory EarthquakeQuery.fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num).toDouble();
    final lng = (json['lng'] as num).toDouble();
    final radius = (json['radiusKm'] as num).toDouble();
    final minMag = (json['minMagnitude'] as num).toDouble();
    final typeStr = json['timeWindowType'] as String;

    if (typeStr == TimeWindowType.relativeDays.name) {
      return EarthquakeQuery.relative(
        center: GeoPoint(lat, lng),
        radiusKm: radius,
        minMagnitude: minMag,
        days: json['relativeDays'] as int? ?? 30,
      );
    } else {
      return EarthquakeQuery.absolute(
        center: GeoPoint(lat, lng),
        radiusKm: radius,
        minMagnitude: minMag,
        startDate: DateTime.parse(json['absoluteStartDate']),
        endDate: DateTime.parse(json['absoluteEndDate']),
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EarthquakeQuery && other.canonicalKey == canonicalKey;
  }

  @override
  int get hashCode => canonicalKey.hashCode;

  @override
  String toString() {
    return 'EarthquakeQuery($canonicalKey)';
  }
}
