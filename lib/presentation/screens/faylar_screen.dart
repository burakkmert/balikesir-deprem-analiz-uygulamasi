import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../domain/entities/fay_segmenti.dart';
import '../../domain/entities/fault_distance_result.dart';
import '../viewmodels/app_state_viewmodel.dart';
import '../widgets/ui_components.dart';

class FaylarScreen extends StatelessWidget {
  const FaylarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateViewModel>();
    final faultResult = state.faultDistanceResult;
    final selectedPoint = state.selectedPoint;
    final selectedIlce = state.selectedIlce;
    final selectedMahalle = state.selectedMahalle;

    final bool hasLocation =
        selectedMahalle != null ||
        selectedIlce != null ||
        selectedPoint != null;

    FaySegmenti? nearestFault;
    if (faultResult.isSuccess && faultResult.nearestFaultId != null) {
      try {
        nearestFault = state.faySegmentleri.firstWhere(
          (f) => f.id == faultResult.nearestFaultId,
        );
      } catch (_) {}
    }

    final String faultName =
        nearestFault?.catalogName ??
        (faultResult.nearestFaultCatalogId != null
            ? 'GEM Katalog ID: ${faultResult.nearestFaultCatalogId}'
            : (faultResult.nearestFaultId != null
                  ? 'Fay Segmenti ID: ${faultResult.nearestFaultId}'
                  : 'Haritalanmış Diri Fay Çizgisi'));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: StandardPageLayout(
        title: 'Faylar',
        subtitle: 'Seçili konuma en yakın diri fay hattı ve mesafe analizi',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasLocation) ...[
              // Location Context Card
              LocationContextCard(
                selectedMahalle: selectedMahalle,
                selectedIlce: selectedIlce,
                selectedPoint: selectedPoint,
              ),
              const SizedBox(height: AppTokens.s16),

              if (faultResult.isSuccess) ...[
                // Primary Fault Distance Card
                _buildPrimaryFaultCard(
                  context: context,
                  faultName: faultName,
                  distanceKm: faultResult.distanceKm!,
                  nearestFault: nearestFault,
                  catalogId:
                      faultResult.nearestFaultCatalogId ??
                      faultResult.nearestFaultId,
                  onNavigateToMap: () => state.selectTab(4),
                ),
              ] else if (faultResult.status ==
                  FaultDistanceStatus.outOfScope) ...[
                const EmptyStateCard(
                  icon: Icons.explore_off_outlined,
                  iconColor: AppColors.warningAmber,
                  title: 'Kapsam Dışı Konum',
                  description: 'Seçilen konum Balıkesir ili diri fay kapsama alanının dışındadır.',
                ),
              ] else ...[
                const EmptyStateCard(
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.warningAmber,
                  title: 'Fay Verisi Bulunamadı',
                  description: 'Seçili konum için kullanılabilir fay verisi bulunamadı veya mesafe hesaplanamadı.',
                ),
              ],
            ] else ...[
              // User-Friendly Empty State (No Location Selected)
              EmptyStateCard(
                icon: Icons.location_searching_rounded,
                iconColor: AppColors.warningAmber,
                title: 'Konum Seçimi Gerekli',
                description: 'En yakın diri fay bilgisini ve mesafeyi hesaplamak için Nüfus sekmesinden bir mahalle veya ilçe seçin.',
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

  static Widget _buildPrimaryFaultCard({
    required BuildContext context,
    required String faultName,
    required double distanceKm,
    required FaySegmenti? nearestFault,
    required String? catalogId,
    required VoidCallback onNavigateToMap,
  }) {
    final String slipTypeStr =
        (nearestFault?.slipType != null && nearestFault!.slipType!.isNotEmpty)
        ? nearestFault.slipType!
        : 'Belirtilmemiş';

    final String geometryStr = nearestFault != null
        ? '${nearestFault.subLines.length} Çizgi Segmenti (${nearestFault.coordinates.length} Nokta)'
        : 'Haritalanmış Çizgi';

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
          // Header Label
          const Row(
            children: [
              Icon(
                Icons.show_chart_rounded,
                color: AppColors.warningAmber,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'En Yakın Diri Fay',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Fault Name
          Text(
            faultName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Distance Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                distanceKm.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'km',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warningAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Seçili konuma kuş uçuşu en yakın fay hattı mesafesi',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.dividerColor),
          const SizedBox(height: 14),

          // Existing Secondary Details
          DetailRow(
            icon: Icons.fingerprint,
            label: 'Katalog / Segment ID',
            value: catalogId ?? '-',
          ),
          const SizedBox(height: AppTokens.s8),
          DetailRow(
            icon: Icons.alt_route_rounded,
            label: 'Fay Karakteri / Tipi',
            value: slipTypeStr,
          ),
          const SizedBox(height: AppTokens.s8),
          DetailRow(
            icon: Icons.polyline_outlined,
            label: 'Geometri Verisi',
            value: geometryStr,
          ),
          const SizedBox(height: AppTokens.s8),
          const DetailRow(
            icon: Icons.dataset_outlined,
            label: 'Veri Kaynağı',
            value: 'MTA / GEM Diri Fay Kataloğu',
          ),

          const SizedBox(height: AppTokens.s20),

          ActionButton(
            onPressed: onNavigateToMap,
            icon: Icons.map_outlined,
            label: 'Haritada Göster',
          ),
        ],
      ),
    );
  }
}
