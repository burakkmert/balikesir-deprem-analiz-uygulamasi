import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../viewmodels/app_state_viewmodel.dart';
import '../widgets/dashboard_sheet.dart';
import '../widgets/map_view.dart';
import '../widgets/neighborhood_search_bar.dart';

class HomeScreen extends StatefulWidget {
  final TileProvider? tileProvider;
  const HomeScreen({super.key, this.tileProvider});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateViewModel>();

    if (state.isRegionalLoading && !state.isLoaded) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.safeEmeraldAccent.withAlpha(100),
                  ),
                ),
                child: const CircularProgressIndicator(
                  color: AppColors.safeEmeraldAccent,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Balıkesir Afet Analiz Sistemi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Demografi, Fay Hatları ve Toplanma Alanları Yükleniyor...',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(200),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: ClipRRect(
              child: Stack(
                children: [
                  MapView(
                    mapController: _mapController,
                    tileProvider: widget.tileProvider,
                  ),
                  Positioned(
                    left: 16,
                    top: 80,
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
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark.withAlpha(220),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.cardBorder.withAlpha(180),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 5),
                            Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: NeighborhoodSearchBar(),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 120,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'recenter_btn',
                          backgroundColor: AppColors.surfaceDark.withAlpha(230),
                          foregroundColor: AppColors.safeEmeraldAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.cardBorder),
                          ),
                          onPressed: () {
                            _mapController.move(
                              const LatLng(
                                AppConstants.balikesirLat,
                                AppConstants.balikesirLng,
                              ),
                              AppConstants.defaultZoom,
                            );
                          },
                          tooltip: 'Balıkesir Merkeze Odaklan',
                          child: const Icon(
                            Icons.center_focus_strong_rounded,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'refresh_btn',
                          backgroundColor: AppColors.surfaceDark.withAlpha(230),
                          foregroundColor: AppColors.warningAmber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.cardBorder),
                          ),
                          onPressed: () => state.clearCacheAndRefresh(),
                          tooltip: 'AFAD Verilerini Yenile',
                          child: const Icon(Icons.sync_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const DashboardSheet(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
