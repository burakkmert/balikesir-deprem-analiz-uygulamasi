import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../viewmodels/app_state_viewmodel.dart';
import '../widgets/map_view.dart';
import '../widgets/recent_earthquakes_sheet.dart';

class HaritaScreen extends StatefulWidget {
  final TileProvider? tileProvider;
  const HaritaScreen({super.key, this.tileProvider});

  @override
  State<HaritaScreen> createState() => _HaritaScreenState();
}

class _HaritaScreenState extends State<HaritaScreen> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenterMap() {
    final state = context.read<AppStateViewModel>();
    if (state.selectedPoint != null) {
      _mapController.move(state.selectedPoint!, 14.5);
    } else {
      _mapController.move(
        const LatLng(AppConstants.balikesirLat, AppConstants.balikesirLng),
        AppConstants.defaultZoom,
      );
    }
  }

  void _showLayersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.r20),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s20,
              vertical: AppTokens.s24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Harita Katmanları',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Consumer<AppStateViewModel>(
                  builder: (context, state, _) {
                    return Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Depremler (AFAD)'),
                          subtitle: Text(
                            '${state.earthquakes.length} olay',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: state.showEarthquakes,
                          onChanged: state.setShowEarthquakes,
                          activeTrackColor: AppColors.safeEmeraldAccent
                              .withAlpha(150),
                          activeThumbColor: AppColors.safeEmeraldAccent,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Diri Faylar'),
                          subtitle: const Text(
                            '60 segment',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: state.showFaults,
                          onChanged: state.setShowFaults,
                          activeTrackColor: AppColors.safeEmeraldAccent
                              .withAlpha(150),
                          activeThumbColor: AppColors.safeEmeraldAccent,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Toplanma Alanları'),
                          subtitle: const Text(
                            '1.682 polygon geometri',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: state.showToplanmaGeometrileri,
                          onChanged: state.setShowToplanmaGeometrileri,
                          activeTrackColor: AppColors.safeEmeraldAccent
                              .withAlpha(150),
                          activeThumbColor: AppColors.safeEmeraldAccent,
                        ),
                      ],
                    );
                  },
                ),
                const Divider(color: AppColors.cardBorder, height: 32),
                const Text(
                  'Harita Araçları',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.center_focus_strong_rounded,
                    color: AppColors.safeEmeraldAccent,
                  ),
                  title: const Text('Seçili Konuma Git'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _recenterMap();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.sync_rounded,
                    color: AppColors.warningAmber,
                  ),
                  title: const Text('AFAD Verilerini Yenile'),
                  onTap: () {
                    context.read<AppStateViewModel>().clearCacheAndRefresh();
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEarthquakesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 60,
          ), // Leave map visible behind
          child: const RecentEarthquakesSheet(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateViewModel>();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: const BoxDecoration(color: AppColors.backgroundDark),
            child: Stack(
              children: [
                // 1. Map View (Bottom-most layer)
                MapView(
                  mapController: _mapController,
                  tileProvider: widget.tileProvider,
                ),

                // 2. OSM Attribution (Bottom Left, safely above bottom nav/pill)
                Positioned(
                  left: 12,
                  bottom: 80, // Safely above the pill and bottom nav
                  child: GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(
                        'https://www.openstreetmap.org/copyright',
                      );
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      } catch (_) {}
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.s8,
                        vertical: AppTokens.s4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark.withAlpha(200),
                        borderRadius: BorderRadius.circular(AppTokens.r8),
                      ),
                      child: const Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Top Overlay (SafeArea)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left Context Chip
                          if (state.selectedIlce != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTokens.s12,
                                vertical: AppTokens.s8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark.withAlpha(240),
                                borderRadius: BorderRadius.circular(
                                  AppTokens.r12,
                                ),
                                border: Border.all(color: AppColors.cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(50),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.place_outlined,
                                    size: 16,
                                    color: AppColors.safeEmeraldAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    state.selectedMahalle != null
                                        ? '${state.selectedMahalle} / ${state.selectedIlce}'
                                        : '${state.selectedIlce} İlçesi',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const SizedBox.shrink(),

                          // Right Layer Control Button
                          GestureDetector(
                            onTap: () => _showLayersSheet(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTokens.s12,
                                vertical: AppTokens.s8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark.withAlpha(240),
                                borderRadius: BorderRadius.circular(
                                  AppTokens.r12,
                                ),
                                border: Border.all(color: AppColors.cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(50),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.layers_outlined,
                                    size: 16,
                                    color: AppColors.safeEmeraldAccent,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Katmanlar',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Floating Earthquake Pill (Bottom Center)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16, // Sits comfortably above persistent bottom nav
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _showEarthquakesModal(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.s20,
                          vertical: AppTokens.s12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(AppTokens.r20),
                          border: Border.all(color: AppColors.cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(150),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.waves,
                              size: 18,
                              color: AppColors.warningAmber,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Son Depremler',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${state.earthquakes.length} Olay',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
