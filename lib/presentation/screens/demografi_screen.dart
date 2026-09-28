import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../domain/entities/ilce_demografi.dart';
import '../viewmodels/app_state_viewmodel.dart';
import '../widgets/ui_components.dart';

class DemografiScreen extends StatelessWidget {
  const DemografiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateViewModel>();
    final ilceDemo = state.currentIlceDemografi;
    final selectedIlce = state.selectedIlce;
    final selectedMahalle = state.selectedMahalle;

    final bool hasAdministrativeSelection = selectedIlce != null;
    final bool isNeighborhoodSelection =
        selectedIlce != null && selectedMahalle != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: StandardPageLayout(
        title: 'Demografi',
        subtitle: 'Balıkesir ilçe düzeyi yaş bağımlılık göstergeleri',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Branch on selection state ──────────────────────────────────
            if (!hasAdministrativeSelection)
              EmptyStateCard(
                icon: Icons.location_off_outlined,
                iconColor: AppColors.textMuted,
                title: 'Konum Seçimi Gerekli',
                description: 'Demografik göstergeleri görüntülemek için Nüfus sekmesinden bir ilçe veya mahalle seçin.',
                actionLabel: 'Nüfus Sekmesinden Konum Seç',
                actionIcon: Icons.search_outlined,
                onAction: () => context.read<AppStateViewModel>().selectTab(0),
              )
            else if (ilceDemo == null)
              EmptyStateCard(
                icon: Icons.info_outline,
                iconColor: AppColors.textMuted,
                title: 'İlçe Demografi Verisi Bulunamadı',
                description:
                    '$selectedIlce ilçesi için yaş bağımlılık verisi veri setinde mevcut değil.',
              )
            else
              _buildDemografiContent(
                context: context,
                ilceDemo: ilceDemo,
                selectedIlce: selectedIlce,
                selectedMahalle: selectedMahalle,
                isNeighborhoodSelection: isNeighborhoodSelection,
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MAIN DEMOGRAFI CONTENT
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildDemografiContent({
    required BuildContext context,
    required IlceDemografi ilceDemo,
    required String selectedIlce,
    required String? selectedMahalle,
    required bool isNeighborhoodSelection,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Location Context Card ──────────────────────────────────────────
        _buildLocationCard(
          selectedIlce: selectedIlce,
          selectedMahalle: selectedMahalle,
          isNeighborhoodSelection: isNeighborhoodSelection,
          ilceAd: ilceDemo.ilceAd,
        ),
        const SizedBox(height: 16),

        // ── Primary Metric — Toplam Bağımlılık ────────────────────────────
        _buildPrimaryMetric(ilceDemo),
        const SizedBox(height: 12),

        // ── Secondary Metrics Row ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _buildSecondaryMetric(
                label: 'Çocuk Bağımlılık',
                tooltip: '0–14 yaş / 15–64 yaş',
                value: ilceDemo.cocukBagimlilik,
                icon: Icons.child_care_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSecondaryMetric(
                label: 'Yaşlı Bağımlılık',
                tooltip: '65+ yaş / 15–64 yaş',
                value: ilceDemo.yasliBagimlilik,
                icon: Icons.elderly_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Data Source / Year ────────────────────────────────────────────
        _buildSourceFooter(ilceDemo),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LOCATION CONTEXT CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildLocationCard({
    required String selectedIlce,
    required String? selectedMahalle,
    required bool isNeighborhoodSelection,
    required String ilceAd,
  }) {
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
          // Location line
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: AppColors.safeEmeraldAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNeighborhoodSelection && selectedMahalle != null) ...[
                      Text(
                        selectedMahalle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      Text(
                        '$selectedIlce / Balıkesir',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ] else ...[
                      Text(
                        '$selectedIlce İlçesi',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Balıkesir',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // District-level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.safeEmerald.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.safeEmeraldAccent.withAlpha(100),
                  ),
                ),
                child: const Text(
                  'İlçe Düzeyi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.safeEmeraldAccent,
                  ),
                ),
              ),
            ],
          ),

          // Fallback explanation (only when neighbourhood selected)
          if (isNeighborhoodSelection) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.dividerColor, height: 1),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mahalle düzeyinde yaş verisi bulunmadığından demografik oranlar $ilceAd ilçe düzeyinde gösterilmektedir.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PRIMARY METRIC — TOPLAM BAĞIMLILIK
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPrimaryMetric(IlceDemografi ilceDemo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          const Text(
            'Demografik Göstergeler',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),

          // Primary value row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Large value
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Toplam Yaş Bağımlılık Oranı',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '%${ilceDemo.toplamBagimlilik.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.5,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(
                  Icons.people_outline,
                  color: AppColors.safeEmeraldAccent,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Explanation
          const Text(
            'Çalışma çağı nüfusuna (15–64 yaş) oranla bağımlı nüfusun yüzdesi.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SECONDARY METRIC CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSecondaryMetric({
    required String label,
    required String tooltip,
    required double value,
    required IconData icon,
  }) {
    return Container(
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
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '%${value.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tooltip,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DATA SOURCE FOOTER
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSourceFooter(IlceDemografi ilceDemo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.dataset_outlined,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _sourceChip('Kaynak: TÜİK'),
                _sourceChip('Veri Yılı: ${ilceDemo.yil}'),
                _sourceChip('Coğrafi Düzey: İlçe'),
                _sourceChip('İlçe Kodu: ${ilceDemo.ilceKodu}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceChip(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
    );
  }
}
