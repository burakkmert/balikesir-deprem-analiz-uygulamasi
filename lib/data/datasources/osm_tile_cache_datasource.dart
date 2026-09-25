import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class OsmTileMeta {
  final String tileUrl;
  final String? etag;
  final String? lastModified;
  final DateTime? expires;
  final Set<String> cacheControlDirectives;
  final DateTime fetchedAt;
  final int sizeBytes;

  OsmTileMeta({
    required this.tileUrl,
    this.etag,
    this.lastModified,
    this.expires,
    this.cacheControlDirectives = const {},
    required this.fetchedAt,
    required this.sizeBytes,
  });

  bool get noStore => cacheControlDirectives.contains('no-store');
  bool get noCache => cacheControlDirectives.contains('no-cache');
  bool get mustRevalidate => cacheControlDirectives.contains('must-revalidate');

  bool isFresh(DateTime now) {
    if (noCache || noStore) return false;
    if (expires != null) {
      return now.isBefore(expires!);
    }
    // Default fallback if no max-age/expires provided: 7 days
    return now.difference(fetchedAt) < const Duration(days: 7);
  }

  Map<String, dynamic> toJson() {
    return {
      'tileUrl': tileUrl,
      'etag': etag,
      'lastModified': lastModified,
      'expires': expires?.toIso8601String(),
      'cacheControlDirectives': cacheControlDirectives.toList(),
      'fetchedAt': fetchedAt.toIso8601String(),
      'sizeBytes': sizeBytes,
    };
  }

  factory OsmTileMeta.fromJson(Map<String, dynamic> json) {
    return OsmTileMeta(
      tileUrl: json['tileUrl'] as String,
      etag: json['etag'] as String?,
      lastModified: json['lastModified'] as String?,
      expires: json['expires'] != null
          ? DateTime.tryParse(json['expires'] as String)
          : null,
      cacheControlDirectives: (json['cacheControlDirectives'] as List? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toSet(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      sizeBytes: json['sizeBytes'] as int? ?? 0,
    );
  }
}

class OsmTileCacheDataSource {
  final Directory cacheDir;
  final http.Client client;
  final int maxDiskBudgetBytes;
  final int maxSingleTileSizeBytes;
  final DateTime Function() clock;
  final Map<String, Future<Uint8List?>> _inFlightTiles = {};

  OsmTileCacheDataSource({
    required this.cacheDir,
    http.Client? client,
    this.maxDiskBudgetBytes = 128 * 1024 * 1024, // 128 MiB
    this.maxSingleTileSizeBytes = 2 * 1024 * 1024, // 2 MiB
    DateTime Function()? clock,
  }) : client = client ?? http.Client(),
       clock = clock ?? DateTime.now;

  static String generateKey(String tileUrl) {
    return 'tile_${tileUrl.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
  }

  Future<Uint8List?> getTile(String tileUrl) async {
    final key = generateKey(tileUrl);
    if (_inFlightTiles.containsKey(key)) {
      return await _inFlightTiles[key]!;
    }

    final future = _loadOrFetchTile(tileUrl, key);
    _inFlightTiles[key] = future;
    try {
      return await future;
    } finally {
      _inFlightTiles.remove(key);
    }
  }

  Future<Uint8List?> _loadOrFetchTile(String tileUrl, String key) async {
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    final imageFile = File('${cacheDir.path}/$key.tile');
    final metaFile = File('${cacheDir.path}/$key.meta.json');

    OsmTileMeta? meta;
    Uint8List? cachedBytes;

    if (imageFile.existsSync() && metaFile.existsSync()) {
      try {
        final metaStr = metaFile.readAsStringSync();
        meta = OsmTileMeta.fromJson(jsonDecode(metaStr));
        cachedBytes = imageFile.readAsBytesSync();
      } catch (_) {
        meta = null;
        cachedBytes = null;
      }
    }

    final now = clock();

    // 1. Fresh Cache Hit
    if (meta != null && cachedBytes != null && meta.isFresh(now)) {
      return cachedBytes;
    }

    // 2. Network Fetch / Conditional Request
    final headers = <String, String>{
      'User-Agent': 'AfetAnalizBalikesir/1.0 (Contact: info@balikesir.bel.tr; Flutter tile cache)',
      'Accept': 'image/webp,image/png,image/*;q=0.8',
    };

    if (meta != null && cachedBytes != null) {
      if (meta.etag != null) {
        headers['If-None-Match'] = meta.etag!;
      }
      if (meta.lastModified != null) {
        headers['If-Modified-Since'] = meta.lastModified!;
      }
    }

    try {
      final response = await client
          .get(Uri.parse(tileUrl), headers: headers)
          .timeout(const Duration(seconds: 8));

      // HTTP 304 Not Modified
      if (response.statusCode == 304 && cachedBytes != null && meta != null) {
        final updatedMeta = OsmTileMeta(
          tileUrl: tileUrl,
          etag: meta.etag,
          lastModified: meta.lastModified,
          expires: _parseExpiresHeader(response.headers, now),
          cacheControlDirectives: _parseCacheControl(response.headers),
          fetchedAt: now,
          sizeBytes: cachedBytes.length,
        );
        try {
          metaFile.writeAsStringSync(jsonEncode(updatedMeta.toJson()));
        } catch (_) {}
        return cachedBytes;
      }

      // HTTP 200 OK
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final contentType = response.headers['content-type'] ?? '';

        // Verify valid image (not HTML error body) and size limit
        if (contentType.contains('html') ||
            bytes.length > maxSingleTileSizeBytes) {
          return cachedBytes;
        }

        final cacheControl = _parseCacheControl(response.headers);
        final expires = _parseExpiresHeader(response.headers, now);

        final newMeta = OsmTileMeta(
          tileUrl: tileUrl,
          etag: response.headers['etag'],
          lastModified: response.headers['last-modified'],
          expires: expires,
          cacheControlDirectives: cacheControl,
          fetchedAt: now,
          sizeBytes: bytes.length,
        );

        if (!newMeta.noStore) {
          try {
            imageFile.writeAsBytesSync(bytes);
            metaFile.writeAsStringSync(jsonEncode(newMeta.toJson()));
            _evictDiskCacheIfNeeded();
          } catch (_) {}
        }

        return bytes;
      }

      // Non-200 / Server Error: Fallback to cached tile if available
      if (cachedBytes != null && (meta == null || !meta.mustRevalidate)) {
        return cachedBytes;
      }

      return null;
    } catch (_) {
      // Offline / Connection error fallback to cached tile
      if (cachedBytes != null && (meta == null || !meta.mustRevalidate)) {
        return cachedBytes;
      }
      return null;
    }
  }

  Set<String> _parseCacheControl(Map<String, String> headers) {
    final cc = headers['cache-control'];
    if (cc == null) return {};
    return cc
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  DateTime? _parseExpiresHeader(Map<String, String> headers, DateTime now) {
    final cc = headers['cache-control'] ?? '';
    final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cc.toLowerCase());
    if (maxAgeMatch != null) {
      final seconds = int.tryParse(maxAgeMatch.group(1)!);
      if (seconds != null) {
        return now.add(Duration(seconds: seconds));
      }
    }

    final expStr = headers['expires'];
    if (expStr != null) {
      try {
        return DateTime.parse(expStr);
      } catch (_) {}
    }

    return null;
  }

  void _evictDiskCacheIfNeeded() {
    if (!cacheDir.existsSync()) return;

    final tileFiles = cacheDir.listSync().whereType<File>().toList();
    int totalSize = 0;
    final List<({File imageFile, File metaFile, DateTime fetchedAt, int size})>
    entries = [];

    for (final f in tileFiles) {
      if (f.path.endsWith('.tile')) {
        final metaPath = f.path.replaceAll('.tile', '.meta.json');
        final metaF = File(metaPath);
        final size = f.lengthSync();
        totalSize += size;

        DateTime fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
        if (metaF.existsSync()) {
          try {
            final m = jsonDecode(metaF.readAsStringSync());
            fetchedAt = DateTime.parse(m['fetchedAt']);
          } catch (_) {}
        }
        entries.add((
          imageFile: f,
          metaFile: metaF,
          fetchedAt: fetchedAt,
          size: size,
        ));
      }
    }

    if (totalSize <= maxDiskBudgetBytes) return;

    // Sort oldest first
    entries.sort((a, b) => a.fetchedAt.compareTo(b.fetchedAt));
    final targetSize = (maxDiskBudgetBytes * 0.8).toInt(); // trim to 80%

    while (totalSize > targetSize && entries.isNotEmpty) {
      final item = entries.removeAt(0);
      try {
        if (item.imageFile.existsSync()) item.imageFile.deleteSync();
        if (item.metaFile.existsSync()) item.metaFile.deleteSync();
      } catch (_) {}
      totalSize -= item.size;
    }
  }

  void clearDiskCache() {
    if (cacheDir.existsSync()) {
      try {
        cacheDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}
