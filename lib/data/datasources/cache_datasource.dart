import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/deprem_olayi.dart';
import '../../domain/entities/earthquake_query.dart';
import '../models/deprem_olayi_dto.dart';

class AfadCacheEnvelope {
  final String source;
  final int schemaVersion;
  final EarthquakeQuery query;
  final DateTime actualStartDate;
  final DateTime actualEndDate;
  final DateTime requestedAt;
  final DateTime fetchedAt;
  final List<DepremOlayi> events;
  final bool isPartial;
  final int totalRawRecords;
  final int validRecords;
  final int rejectedRecords;
  final int outOfBoundsRecords;
  final String? statusNotice;

  AfadCacheEnvelope({
    this.source = 'AFAD',
    this.schemaVersion = 3,
    required this.query,
    required this.actualStartDate,
    required this.actualEndDate,
    required this.requestedAt,
    required this.fetchedAt,
    required this.events,
    this.isPartial = false,
    this.totalRawRecords = 0,
    this.validRecords = 0,
    this.rejectedRecords = 0,
    this.outOfBoundsRecords = 0,
    this.statusNotice,
  });

  bool isFresh(DateTime now, {Duration ttl = const Duration(minutes: 15)}) {
    // Guard against future timestamps (>1 min in future)
    if (fetchedAt.isAfter(now.add(const Duration(minutes: 1)))) {
      return false;
    }
    return now.difference(fetchedAt) <= ttl;
  }

  bool isUsableStale(
    DateTime now, {
    Duration retentionLimit = const Duration(hours: 24),
  }) {
    if (fetchedAt.isAfter(now.add(const Duration(minutes: 1)))) {
      return false;
    }
    return now.difference(fetchedAt) <= retentionLimit;
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'schemaVersion': schemaVersion,
      'query': query.toJson(),
      'actualStartDate': actualStartDate.toIso8601String(),
      'actualEndDate': actualEndDate.toIso8601String(),
      'requestedAt': requestedAt.toIso8601String(),
      'fetchedAt': fetchedAt.toIso8601String(),
      'events': events.map((e) => DepremOlayiDto.toJson(e)).toList(),
      'isPartial': isPartial,
      'totalRawRecords': totalRawRecords,
      'validRecords': validRecords,
      'rejectedRecords': rejectedRecords,
      'outOfBoundsRecords': outOfBoundsRecords,
      'statusNotice': statusNotice,
    };
  }

  factory AfadCacheEnvelope.fromJson(Map<String, dynamic> json) {
    final fetchedAtDt = DateTime.parse(json['fetchedAt'] as String);
    final eventsRaw = (json['events'] as List? ?? []);
    final parsedEvents = eventsRaw
        .map(
          (e) => DepremOlayiDto.fromJson(
            e as Map<String, dynamic>,
            fetchedAt: fetchedAtDt,
          ),
        )
        .toList();

    return AfadCacheEnvelope(
      source: json['source'] as String? ?? 'AFAD',
      schemaVersion: json['schemaVersion'] as int? ?? 3,
      query: EarthquakeQuery.fromJson(json['query'] as Map<String, dynamic>),
      actualStartDate: DateTime.parse(json['actualStartDate'] as String),
      actualEndDate: DateTime.parse(json['actualEndDate'] as String),
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      fetchedAt: fetchedAtDt,
      events: parsedEvents,
      isPartial: json['isPartial'] as bool? ?? false,
      totalRawRecords: json['totalRawRecords'] as int? ?? 0,
      validRecords: json['validRecords'] as int? ?? 0,
      rejectedRecords: json['rejectedRecords'] as int? ?? 0,
      outOfBoundsRecords: json['outOfBoundsRecords'] as int? ?? 0,
      statusNotice: json['statusNotice'] as String?,
    );
  }
}

class CacheDataSource {
  static const String _keyPrefixV3 = 'afad_cache_v3_';
  static const String _legacyKeyPrefix = 'afad_cache_';
  static const Duration freshnessTTL = Duration(minutes: 15);
  static const Duration staleRetentionLimit = Duration(hours: 24);
  static const int maxCacheEntries = 20;
  static const int maxCacheSizeBytes = 5 * 1024 * 1024; // 5 MiB

  final SharedPreferences? _prefs;

  CacheDataSource([this._prefs]);

  static Future<CacheDataSource> create() async {
    final prefs = await SharedPreferences.getInstance();
    final instance = CacheDataSource(prefs);
    await instance._purgeLegacyKeys();
    return instance;
  }

  Future<void> _purgeLegacyKeys() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (key.startsWith(_legacyKeyPrefix) && !key.startsWith(_keyPrefixV3)) {
        await prefs.remove(key);
      }
    }
  }

  static String generateCacheKey(EarthquakeQuery query) {
    return '$_keyPrefixV3${query.canonicalKey}';
  }

  Future<AfadCacheEnvelope?> getEnvelope(String key) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await _purgeLegacyKeys();

    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return null;

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      final envelope = AfadCacheEnvelope.fromJson(decoded);

      // Verify envelope schema version
      if (envelope.schemaVersion != 3) {
        await prefs.remove(key);
        return null;
      }
      return envelope;
    } catch (_) {
      // Purge corrupt envelope
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> saveEnvelope(String key, AfadCacheEnvelope envelope) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(envelope.toJson());

    // Write to SharedPreferences
    await prefs.setString(key, jsonStr);

    // Evict old entries if budget exceeded
    await _enforceEvictionPolicy(prefs);
  }

  Future<void> _enforceEvictionPolicy(SharedPreferences prefs) async {
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(_keyPrefixV3))
        .toList();

    if (keys.isEmpty) return;

    final List<({String key, int size, DateTime requestedAt})> entries = [];
    int totalSize = 0;

    for (final k in keys) {
      final str = prefs.getString(k);
      if (str == null) continue;
      final size = str.length;
      totalSize += size;

      DateTime requestedAt = DateTime.fromMillisecondsSinceEpoch(0);
      try {
        final decoded = jsonDecode(str);
        if (decoded['requestedAt'] != null) {
          requestedAt = DateTime.parse(decoded['requestedAt']);
        }
      } catch (_) {}

      entries.add((key: k, size: size, requestedAt: requestedAt));
    }

    // Sort by requestedAt ascending (oldest first)
    entries.sort((a, b) => a.requestedAt.compareTo(b.requestedAt));

    while (entries.length > maxCacheEntries || totalSize > maxCacheSizeBytes) {
      if (entries.isEmpty) break;
      final oldest = entries.removeAt(0);
      await prefs.remove(oldest.key);
      totalSize -= oldest.size;
    }
  }

  Future<void> clearCache() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(_keyPrefixV3))
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
