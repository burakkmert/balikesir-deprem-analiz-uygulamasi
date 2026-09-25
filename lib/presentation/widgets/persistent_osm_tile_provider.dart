import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../data/datasources/osm_tile_cache_datasource.dart';

class PersistentOsmTileProvider extends TileProvider {
  final OsmTileCacheDataSource dataSource;

  PersistentOsmTileProvider({required this.dataSource});

  static PersistentOsmTileProvider? _defaultInstance;

  static PersistentOsmTileProvider get defaultInstance {
    if (_defaultInstance != null) return _defaultInstance!;
    final tempDir = Directory('${Directory.systemTemp.path}/osm_tile_cache');
    _defaultInstance = PersistentOsmTileProvider(
      dataSource: OsmTileCacheDataSource(cacheDir: tempDir),
    );
    return _defaultInstance!;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return PersistentOsmImageProvider(url: url, dataSource: dataSource);
  }
}

class PersistentOsmImageProvider
    extends ImageProvider<PersistentOsmImageProvider> {
  final String url;
  final OsmTileCacheDataSource dataSource;

  PersistentOsmImageProvider({required this.url, required this.dataSource});

  @override
  Future<PersistentOsmImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return Future.value(this);
  }

  @override
  ImageStreamCompleter loadImage(
    PersistentOsmImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<Codec> _loadAsync(
    PersistentOsmImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await dataSource.getTile(url);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Tile image could not be loaded: $url');
    }
    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    return await decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PersistentOsmImageProvider && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}
