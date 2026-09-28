import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'persistent_osm_tile_provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../domain/entities/fay_segmenti.dart';
import '../../domain/entities/toplanma_alani.dart';
import '../../domain/entities/toplanma_geometri.dart';
import '../viewmodels/app_state_viewmodel.dart';

class MapView extends StatefulWidget {
  final MapController? mapController;
  final TileProvider? tileProvider;
  final bool showDevGeometries;

  const MapView({
    super.key,
    this.mapController,
    this.tileProvider,
    this.showDevGeometries = false,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  MapController? _internalMapController;
  MapController get _effectiveController =>
      widget.mapController ?? (_internalMapController ??= MapController());

  List<ToplanmaGeometri>? _cachedGeoms;
  bool? _cachedShowDev;
  bool? _cachedSufficient;
  List<Polygon> _cachedPolygons = [];

  List<FaySegmenti>? _cachedFaultSegments;
  List<Polyline> _cachedFaultPolylines = [];

  @override
  void dispose() {
    _internalMapController?.dispose();
    super.dispose();
  }

  List<Polyline> _getFaultPolylines(List<FaySegmenti> faySegmentleri) {
    if (_cachedFaultSegments == faySegmentleri) {
      return _cachedFaultPolylines;
    }
    _cachedFaultSegments = faySegmentleri;
    final List<Polyline> faultPolylines = [];
    for (final segment in faySegmentleri) {
      for (final line in segment.subLines) {
        if (line.isNotEmpty) {
          faultPolylines.add(
            Polyline(
              points: line.map((p) => LatLng(p.latitude, p.longitude)).toList(),
              color: const Color(0xFFDC2626),
              strokeWidth: 3.2,
            ),
          );
        }
      }
    }
    _cachedFaultPolylines = faultPolylines;
    return _cachedFaultPolylines;
  }

  List<Polygon> _getAreaPolygons(
    List<ToplanmaGeometri> geometriler,
    bool showDevGeometries,
    bool isAttributeSufficient,
  ) {
    if (_cachedGeoms == geometriler &&
        _cachedShowDev == showDevGeometries &&
        _cachedSufficient == isAttributeSufficient) {
      return _cachedPolygons;
    }
    _cachedGeoms = geometriler;
    _cachedShowDev = showDevGeometries;
    _cachedSufficient = isAttributeSufficient;

    final List<Polygon> areaPolygons = [];
    for (final geom in geometriler) {
      if (geom.outerRing.isNotEmpty) {
        areaPolygons.add(
          Polygon(
            points: geom.outerRing
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList(),
            holePointsList: geom.innerRings
                .map(
                  (ring) =>
                      ring.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                )
                .toList(),
            color: AppColors.safeEmerald.withAlpha(50),
            borderColor: AppColors.safeEmeraldAccent,
            borderStrokeWidth: 2.0,
          ),
        );
      }
    }
    _cachedPolygons = areaPolygons;
    return _cachedPolygons;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateViewModel>();
    final selectedPoint = state.selectedPoint;

    if (state.mapFocusTarget != null) {
      final focusTarget = state.mapFocusTarget!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _effectiveController.move(focusTarget, 14.5);
        state.clearMapFocus();
      });
    }

    final faultPolylines = state.showFaults
        ? _getFaultPolylines(state.faySegmentleri)
        : <Polyline>[];
    final areaPolygons = state.showToplanmaGeometrileri
        ? _getAreaPolygons(
            state.toplanmaGeometrileri,
            widget.showDevGeometries,
            state.isToplanmaAttributeSufficient,
          )
        : <Polygon>[];

    final List<Marker> assemblyMarkers = [];
    if (state.showToplanmaGeometrileri) {
      final List<ToplanmaAlani> displayAreas = [];
      final Set<String> seenIds = {};

      for (final item in state.closestToplanmaAlanlari) {
        if (seenIds.add(item.area.id)) {
          displayAreas.add(item.area);
        }
      }
      for (final area in state.toplanmaAlanlari) {
        if (seenIds.add(area.id)) {
          displayAreas.add(area);
        }
      }

      final String? nearestId = state.closestToplanmaAlanlari.isNotEmpty
          ? state.closestToplanmaAlanlari.first.area.id
          : (state.toplanmaAlanlari.isNotEmpty
                ? state.toplanmaAlanlari.first.id
                : null);

      for (final area in displayAreas) {
        if (area.enlem.isNaN ||
            area.enlem.isInfinite ||
            area.boylam.isNaN ||
            area.boylam.isInfinite) {
          continue;
        }

        final isNearest = area.id == nearestId;
        final areaPoint = LatLng(area.enlem, area.boylam);

        assemblyMarkers.add(
          Marker(
            point: areaPoint,
            width: isNearest ? 46 : 38,
            height: isNearest ? 46 : 38,
            child: GestureDetector(
              onTap: () => _showAssemblyAreaDetails(context, area),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isNearest
                        ? AppColors.warningAmber
                        : AppColors.safeEmeraldAccent,
                    width: isNearest ? 3.0 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isNearest
                          ? AppColors.warningAmber.withAlpha(160)
                          : AppColors.safeEmerald.withAlpha(120),
                      blurRadius: isNearest ? 12 : 8,
                      spreadRadius: isNearest ? 2 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  isNearest ? Icons.star_rounded : Icons.shield_outlined,
                  color: isNearest
                      ? AppColors.warningAmber
                      : AppColors.safeEmeraldAccent,
                  size: isNearest ? 24 : 20,
                ),
              ),
            ),
          ),
        );
      }
    }

    Marker? targetMarker;
    if (selectedPoint != null) {
      targetMarker = Marker(
        point: selectedPoint,
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warningAmber.withAlpha(45),
                border: Border.all(
                  color: AppColors.warningAmber.withAlpha(180),
                  width: 2,
                ),
              ),
            ),
            const Icon(
              Icons.location_on,
              color: AppColors.warningAmber,
              size: 34,
            ),
          ],
        ),
      );
    }

    final List<Marker> earthquakeMarkers = [];
    if (state.showEarthquakes) {
      for (final eq in state.earthquakes) {
        final isMajor = eq.buyukluk >= 4.0;
        final isWarning = eq.buyukluk >= 3.0;

        final color = isMajor
            ? AppColors.alertBrickRed
            : (isWarning ? AppColors.warningAmber : AppColors.textSecondary);

        earthquakeMarkers.add(
          Marker(
            point: LatLng(eq.enlem, eq.boylam),
            width: isMajor ? 20 : 16,
            height: isMajor ? 20 : 16,
            child: Container(
              decoration: BoxDecoration(
                color: color.withAlpha(200),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(color: color.withAlpha(100), blurRadius: 4),
                ],
              ),
            ),
          ),
        );
      }
    }

    return FlutterMap(
      mapController: _effectiveController,
      options: MapOptions(
        initialCenter: const LatLng(
          AppConstants.balikesirLat,
          AppConstants.balikesirLng,
        ),
        initialZoom: AppConstants.defaultZoom,
        minZoom: 6.0,
        maxZoom: 18.0,
        onTap: (tapPosition, point) {
          state.updateSelectedPoint(point);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.afet_analiz',
          tileProvider:
              widget.tileProvider ?? PersistentOsmTileProvider.defaultInstance,
        ),
        PolygonLayer(polygons: areaPolygons),
        PolylineLayer(polylines: faultPolylines),
        MarkerLayer(
          markers: [
            ...assemblyMarkers,
            ...earthquakeMarkers,
            if (targetMarker != null) ...[targetMarker],
          ],
        ),
      ],
    );
  }

  void _showAssemblyAreaDetails(BuildContext context, ToplanmaAlani area) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.safeEmerald.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.safeEmeraldAccent.withAlpha(120),
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.safeEmeraldAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          area.ad,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${area.ilce} / ${area.mahalle}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28, color: AppColors.dividerColor),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Toplanma Alanı Adresi:',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  Expanded(
                    child: Text(
                      area.adres.isNotEmpty
                          ? area.adres
                          : 'Adres bilgisi mevcut',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
