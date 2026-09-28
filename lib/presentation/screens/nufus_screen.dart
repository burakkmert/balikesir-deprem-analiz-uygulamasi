import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/app_utils.dart';
import '../../domain/entities/demografi.dart';
import '../viewmodels/app_state_viewmodel.dart';
import '../widgets/neighborhood_search_bar.dart';
import '../widgets/ui_components.dart';

class NufusScreen extends StatelessWidget {
  const NufusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateViewModel>();
    final demografi = state.currentDemografi;
    final selectedPoint = state.selectedPoint;
    final selectedIlce = state.selectedIlce;
    final selectedMahalle = state.selectedMahalle;

    final districtDemografis = selectedIlce != null
        ? state.demografiList.where((d) => d.ilce == selectedIlce).toList()
        : const <Demografi>[];
    int districtTotalPopulation = 0;
    for (final d in districtDemografis) {
      districtTotalPopulation += d.nufus.toInt();
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: StandardPageLayout(
        title: 'Nüfus',
        subtitle: 'Balıkesir ilçe ve mahalle nüfus bilgileri',
        headerAction: const NeighborhoodSearchBar(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedMahalle != null && demografi != null) ...[
              // Selected Neighborhood Location Card
              LocationContextCard(
                selectedMahalle: selectedMahalle,
                selectedIlce: selectedIlce,
                selectedPoint: selectedPoint,
              ),
              const SizedBox(height: AppTokens.s16),
              // Population Metric Block
              _buildPopulationCard(
                context: context,
                label: 'Mahalle Nüfusu',
                populationValue: AppUtils.formatNumber(demografi.nufus),
                details: [
                  const DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'TÜİK Veri Yılı',
                    value: '2023', // Hardcoded for this screen or dynamically from demografi.yil
                  ),
                  DetailRow(
                    icon: Icons.badge_outlined,
                    label: 'Mahalle Kodu',
                    value: demografi.mahalleNufus.mahalleKodu,
                  ),
                  DetailRow(
                    icon: Icons.location_city_outlined,
                    label: 'Bağlı İlçe',
                    value: selectedIlce ?? '-',
                  ),
                ],
              ),
            ] else if (selectedIlce != null) ...[
              // Selected District Location Card
              LocationContextCard(
                selectedMahalle: selectedMahalle,
                selectedIlce: selectedIlce,
                selectedPoint: selectedPoint,
              ),
              const SizedBox(height: AppTokens.s16),
              // District Population Metric Block
              _buildPopulationCard(
                context: context,
                label: 'İlçe Toplam Nüfusu',
                populationValue: AppUtils.formatNumber(districtTotalPopulation),
                details: [
                  DetailRow(
                    icon: Icons.holiday_village_outlined,
                    label: 'Kapsanan Mahalle',
                    value: '${districtDemografis.length} Mahalle',
                  ),
                  const DetailRow(
                    icon: Icons.map_outlined,
                    label: 'İl',
                    value: 'Balıkesir',
                  ),
                ],
                notice: 'Mahalle bazlı nüfus verisi için yukarıdaki arama alanından bir mahalle seçiniz.',
              ),
            ] else if (selectedPoint != null) ...[
              // Selected Coordinate Header Card
              LocationContextCard(
                selectedMahalle: selectedMahalle,
                selectedIlce: selectedIlce,
                selectedPoint: selectedPoint,
              ),
              const SizedBox(height: AppTokens.s16),
              _buildNoticeCard(
                icon: Icons.info_outline,
                message: 'Haritadan seçilen koordinat için doğrudan nüfus kaydı bulunmamaktadır. Detaylı nüfus verisi için yukarıdaki arama alanından mahalle veya ilçe seçebilirsiniz.',
              ),
            ] else ...[
              // User-Friendly Empty State (No Location Selected)
              const EmptyStateCard(
                icon: Icons.manage_search_rounded,
                title: 'Nüfus Bilgisi İçin Seçim Yapın',
                description: 'Bir mahalle veya ilçe seçerek nüfus bilgilerini görüntüleyin.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _buildPopulationCard({
    required BuildContext context,
    required String label,
    required String populationValue,
    required List<DetailRow> details,
    String? notice,
  }) {
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
          Row(
            children: [
              const Icon(
                Icons.people_alt_outlined,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            populationValue,
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.dividerColor),
          const SizedBox(height: 14),
          ...details.map(
            (detail) => Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.s8),
              child: detail,
            ),
          ),
          if (notice != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notice,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildNoticeCard({
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.warningAmber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
