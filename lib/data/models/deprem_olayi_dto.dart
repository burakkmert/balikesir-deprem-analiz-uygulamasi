import '../../domain/entities/deprem_olayi.dart';

class StrictDateResult {
  final DateTime dateTime;
  final bool hasExplicitTimezone;

  StrictDateResult({required this.dateTime, required this.hasExplicitTimezone});
}

class DepremOlayiDto {
  static StrictDateResult parseStrictDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty date string');
    }

    final regExp = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?)?(Z|z|[+-]\d{2}:?\d{2})?$',
    );
    final match = regExp.firstMatch(trimmed);
    if (match == null) {
      throw FormatException('Invalid date format structure: $raw');
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    final hourStr = match.group(4);
    final minuteStr = match.group(5);
    final secondStr = match.group(6);

    final hour = hourStr != null ? int.parse(hourStr) : 0;
    final minute = minuteStr != null ? int.parse(minuteStr) : 0;
    final second = secondStr != null ? int.parse(secondStr) : 0;

    if (month < 1 || month > 12) {
      throw FormatException('Invalid month $month in date: $raw');
    }
    if (day < 1 || day > 31) {
      throw FormatException('Invalid day $day in date: $raw');
    }

    final maxDaysInMonth = DateTime(year, month + 1, 0).day;
    if (day > maxDaysInMonth) {
      throw FormatException(
        'Day $day exceeds month $month limit ($maxDaysInMonth) in date: $raw',
      );
    }

    if (hour < 0 || hour > 23) {
      throw FormatException('Invalid hour $hour in date: $raw');
    }
    if (minute < 0 || minute > 59) {
      throw FormatException('Invalid minute $minute in date: $raw');
    }
    if (second < 0 || second > 59) {
      throw FormatException('Invalid second $second in date: $raw');
    }

    final tzGroup = match.group(8);
    final bool hasExplicitTimezone = tzGroup != null && tzGroup.isNotEmpty;

    final isoStr = trimmed.contains(' ') && !trimmed.contains('T')
        ? trimmed.replaceFirst(' ', 'T')
        : trimmed;

    final parsed = DateTime.tryParse(isoStr);
    if (parsed == null) {
      throw FormatException('Unparseable date string: $raw');
    }

    return StrictDateResult(
      dateTime: parsed,
      hasExplicitTimezone: hasExplicitTimezone,
    );
  }

  static double? _parseStrictDouble(dynamic val) {
    if (val == null || val is bool) return null;
    if (val is double) {
      if (val.isNaN || val.isInfinite) return null;
      return val;
    }
    if (val is int) return val.toDouble();
    if (val is String) {
      final s = val.trim();
      if (s.isEmpty) return null;
      final d = double.tryParse(s);
      if (d == null || d.isNaN || d.isInfinite) return null;
      return d;
    }
    return null;
  }

  static DepremOlayi fromJson(
    Map<String, dynamic> json, {
    DateTime? fetchedAt,
  }) {
    // 1. Mandatory eventID
    final rawId = (json['eventID'] ?? json['id'] ?? json['eventId'])
        ?.toString()
        .trim();
    if (rawId == null || rawId.isEmpty) {
      throw const FormatException('Missing or empty eventID');
    }

    // 2. Mandatory latitude
    final lat = _parseStrictDouble(
      json['latitude'] ?? json['enlem'] ?? json['lat'],
    );
    if (lat == null || lat < -90.0 || lat > 90.0) {
      throw FormatException('Invalid latitude in record: ${json['latitude']}');
    }

    // 3. Mandatory longitude
    final lng = _parseStrictDouble(
      json['longitude'] ?? json['boylam'] ?? json['lng'] ?? json['lon'],
    );
    if (lng == null || lng < -180.0 || lng > 180.0) {
      throw FormatException(
        'Invalid longitude in record: ${json['longitude']}',
      );
    }

    // 4. Mandatory magnitude (DO NOT use rms!)
    final magRaw = json['magnitude'] ?? json['buyukluk'] ?? json['mag'];
    final mag = _parseStrictDouble(magRaw);
    if (mag == null) {
      throw FormatException('Invalid magnitude in record: $magRaw');
    }

    // 5. Mandatory date
    final dateStr = (json['date'] ?? json['tarih'] ?? json['eventDate'])
        ?.toString();
    if (dateStr == null || dateStr.trim().isEmpty) {
      throw const FormatException('Missing date in record');
    }
    final parsedDateResult = parseStrictDate(dateStr);

    // 6. Optional fields
    final depthRaw = json['depth'] ?? json['derinlik'];
    final depth = _parseStrictDouble(depthRaw);

    final locRaw = json['location'] ?? json['yer'];
    final location = (locRaw != null && locRaw.toString().trim().isNotEmpty)
        ? locRaw.toString().trim()
        : null;

    final typeRaw = json['type'] ?? json['magType'] ?? json['tip'];
    final type = (typeRaw != null && typeRaw.toString().trim().isNotEmpty)
        ? typeRaw.toString().trim()
        : null;

    final bool isVerifiedTimezone =
        json['isTimezoneVerified'] == true ||
        parsedDateResult.hasExplicitTimezone;

    DateTime? recordFetchedAt = fetchedAt;
    if (recordFetchedAt == null && json['fetchedAt'] != null) {
      recordFetchedAt = DateTime.tryParse(json['fetchedAt'].toString());
    }

    return DepremOlayi(
      eventID: rawId,
      enlem: lat,
      boylam: lng,
      derinlik: depth,
      buyukluk: mag,
      yer: location,
      tip: type,
      tarih: parsedDateResult.dateTime,
      fetchedAt: recordFetchedAt,
      isTimezoneVerified: isVerifiedTimezone,
    );
  }

  static Map<String, dynamic> toJson(DepremOlayi entity) {
    return {
      'eventID': entity.eventID,
      'enlem': entity.enlem,
      'boylam': entity.boylam,
      'derinlik': entity.derinlik,
      'buyukluk': entity.buyukluk,
      'yer': entity.yer,
      'tip': entity.tip,
      'tarih': entity.tarih.toIso8601String(),
      'fetchedAt': entity.fetchedAt?.toIso8601String(),
      'isTimezoneVerified': entity.isTimezoneVerified,
    };
  }
}
