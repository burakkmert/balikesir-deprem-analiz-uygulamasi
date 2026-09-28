import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../domain/entities/toplanma_alani.dart';
import '../viewmodels/app_state_viewmodel.dart';
import '../widgets/ui_components.dart';

class ToplanmaScreen extends StatelessWidget {
  const ToplanmaScreen({super.key});

  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }

  static Future<void> _launchDirections(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateViewModel>();
    final selectedPoint = state.selectedPoint;
    final selectedIlce = state.selectedIlce;
    final selectedMahalle = state.selectedMahalle;

    final bool hasLocation =
        selectedMahalle != null ||
        selectedIlce != null ||
        selectedPoint != null;

    // Determine nearest areas list
    List<_ToplanmaItem> displayItems = [];

    if (selectedPoint != null && state.closestToplanmaAlanlari.isNotEmpty) {
      displayItems = state.closestToplanmaAlanlari
          .map(
            (item) =>
                _ToplanmaItem(area: item.area, distanceKm: item.distanceKm),
          )
          .toList();
    } else if (state.toplanmaAlanlari.isNotEmpty) {
      displayItems = state.toplanmaAlanlari
          .map((area) => _ToplanmaItem(area: area, distanceKm: null))
          .toList();
    }

    final _ToplanmaItem? primaryItem = displayItems.isNotEmpty
        ? displayItems.first
        : null;
    final List<_ToplanmaItem> secondaryItems = displayItems.length > 1
        ? displayItems.sublist(1)
        : [];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: StandardPageLayout(
        title: 'Toplanma Alanları',
        subtitle: 'Seçili konuma yakın resmî acil durum toplanma alanları',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasLocation) ...[
              // Location Context Card
              LocationContextCard(
                selectedMahalle: selectedMahalle,
                selectedIlce: selectedIlce,
                selectedPoint: selectedPoint,
                overrideIcon: Icons.shield_outlined,
              ),
              const SizedBox(height: AppTokens.s16),

              if (state.toplanmaError != null) ...[
                const EmptyStateCard(
                  icon: Icons.error_outline,
                  iconColor: AppColors.alertBrickRed,
                  title: 'Veri Yükleme Hatası',
                  description:
                      'Toplanma alanları verisi yüklenirken bir sorun oluştu.',
                ),
              ] else if (primaryItem != null) ...[
                // Global Assembly Areas Map Action
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      state.setShowToplanmaGeometrileri(true);
                      state.requestMapFocus(
                        LatLng(primaryItem.area.enlem, primaryItem.area.boylam),
                      );
                      state.selectTab(4);
                    },
                    icon: const Icon(
                      Icons.map_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                    label: const Text(
                      'Toplanma Alanlarını Haritada Göster',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.safeEmerald,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Primary Assembly Area Card
                _buildPrimaryCard(
                  context: context,
                  item: primaryItem,
                  onNavigateToMap: () {
                    state.requestMapFocus(
                      LatLng(primaryItem.area.enlem, primaryItem.area.boylam),
                    );
                    state.selectTab(4);
                  },
                ),

                // Secondary Nearby Assembly Areas List
                if (secondaryItems.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_outlined,
                        size: 18,
                        color: AppColors.safeEmeraldAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Yakındaki Diğer Toplanma Alanları (${secondaryItems.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...secondaryItems.map(
                    (secItem) => Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: _buildSecondaryTile(
                        context: context,
                        item: secItem,
                        onNavigateToMap: () {
                          state.requestMapFocus(
                            LatLng(secItem.area.enlem, secItem.area.boylam),
                          );
                          state.selectTab(4);
                        },
                      ),
                    ),
                  ),
                ],
              ] else ...[
                const EmptyStateCard(
                  icon: Icons.shield_outlined,
                  iconColor: AppColors.warningAmber,
                  title: 'Toplanma Alanı Verisi Bulunamadı',
                  description: 'Seçili konum için kayıtlı toplanma alanı verisi bulunamadı.',
                ),
              ],
            ] else ...[
              // User-Friendly Empty State (No Location Selected)
              EmptyStateCard(
                icon: Icons.nature_people_outlined,
                iconColor: AppColors.safeEmeraldAccent,
                title: 'Konum Seçimi Gerekli',
                description: 'Yakındaki toplanma alanlarını görüntülemek için Nüfus sekmesinden bir mahalle veya ilçe seçin.',
                actionLabel: 'Nüfus Sekmesinden Konum Seç',
                actionIcon: Icons.search_rounded,
                onAction: () => state.selectTab(0),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _buildPrimaryCard({
    required BuildContext context,
    required _ToplanmaItem item,
    required VoidCallback onNavigateToMap,
  }) {
    final area = item.area;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge Label
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppColors.safeEmeraldAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'En Yakın Toplanma Alanı',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.safeEmeraldAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Area Name
          Text(
            area.ad,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Distance Display (if distanceKm available)
          if (item.distanceKm != null) ...[
            Text(
              formatDistance(item.distanceKm!),
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -1,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Seçili konuma kuş uçuşu uzaklık',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.dividerColor),
            const SizedBox(height: 14),
          ],

          // Existing Address / Neighborhood / Details
          if (area.adres.isNotEmpty) ...[
            DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Adres',
              value: area.adres,
            ),
            const SizedBox(height: AppTokens.s8),
          ],
          DetailRow(
            icon: Icons.holiday_village_outlined,
            label: 'Mahalle / İlçe',
            value: '${area.mahalle} / ${area.ilce}',
          ),
          if (area.alanM2 != null && area.alanM2! > 0) ...[
            const SizedBox(height: AppTokens.s8),
            DetailRow(
              icon: Icons.square_foot_outlined,
              label: 'Alan Büyüklüğü',
              value: '${area.alanM2!.toStringAsFixed(0)} m²',
            ),
          ],
          if (area.aciklama.isNotEmpty) ...[
            const SizedBox(height: AppTokens.s8),
            DetailRow(
              icon: Icons.info_outline,
              label: 'Açıklama',
              value: area.aciklama,
            ),
          ],

          // Infrastructure Chips (if available)
          if (area.su == true || area.elektrik == true || area.wc == true) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (area.su == true) _buildChip('Su'),
                if (area.elektrik == true) _buildChip('Elektrik'),
                if (area.wc == true) _buildChip('WC'),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Action Buttons: Haritada Göster & Yol Tarifi
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: onNavigateToMap,
                    icon: const Icon(
                      Icons.map_outlined,
                      size: 18,
                      color: AppColors.safeEmeraldAccent,
                    ),
                    label: const Text(
                      'Haritada Göster',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.cardDark,
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _launchDirections(area.enlem, area.boylam),
                    icon: const Icon(
                      Icons.directions_outlined,
                      size: 18,
                      color: AppColors.accentCyan,
                    ),
                    label: const Text(
                      'Yol Tarifi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.cardDark,
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildSecondaryTile({
    required BuildContext context,
    required _ToplanmaItem item,
    required VoidCallback onNavigateToMap,
  }) {
    final area = item.area;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  area.ad,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.distanceKm != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    formatDistance(item.distanceKm!),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.safeEmeraldAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            area.adres.isNotEmpty
                ? area.adres
                : '${area.mahalle} / ${area.ilce}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onNavigateToMap,
                icon: const Icon(
                  Icons.map_outlined,
                  size: 15,
                  color: AppColors.safeEmeraldAccent,
                ),
                label: const Text(
                  'Harita',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.safeEmeraldAccent,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _launchDirections(area.enlem, area.boylam),
                icon: const Icon(
                  Icons.directions_outlined,
                  size: 15,
                  color: AppColors.accentCyan,
                ),
                label: const Text(
                  'Yol Tarifi',
                  style: TextStyle(fontSize: 12, color: AppColors.accentCyan),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}

class _ToplanmaItem {
  final ToplanmaAlani area;
  final double? distanceKm;

  const _ToplanmaItem({required this.area, this.distanceKm});
}
