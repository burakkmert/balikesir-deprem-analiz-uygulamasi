import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../domain/entities/deprem_olayi.dart';
import '../viewmodels/app_state_viewmodel.dart';
import '../viewmodels/view_state.dart';
import 'status_badge.dart';

class RecentEarthquakesSheet extends StatelessWidget {
  const RecentEarthquakesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateViewModel>();
    final earthquakesVM = state.earthquakesVM;

    return DraggableScrollableSheet(
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.15, 0.4, 0.75],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withAlpha(245),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTokens.r20),
            ),
            border: Border.all(color: AppColors.cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(160),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Handle & Header (Pinned) ──────────────────────────────────
              GestureDetector(
                onTap: () {
                  // A simple tap on header could toggle size, but we rely on drag.
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: Colors.transparent, // expand tap area
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.waves,
                                color: AppColors.warningAmber,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Son Depremler',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (state.isFromCache) ...[
                                const StatusBadge(
                                  label: 'Önbellek',
                                  type: StatusType.warning,
                                  icon: Icons.bolt,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                '${state.earthquakes.length} Olay',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: AppColors.cardBorder, height: 1),

              // ── Scrollable Content ────────────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (state.isEarthquakesLoading)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.warningAmber,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    else if (earthquakesVM.state == ViewState.error)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.alertBrickRed.withAlpha(120),
                          ),
                        ),
                        child: Text(
                          earthquakesVM.errorMessage ??
                              'AFAD canlı verileri alınamadı.',
                          style: const TextStyle(
                            color: AppColors.alertBrickRed,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (earthquakesVM.state == ViewState.empty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Text(
                          'Kayıt bulunamadı.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else ...[
                      // Cache Warning
                      if (earthquakesVM.isFromCache &&
                          earthquakesVM.afadStatusMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningAmber.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warningAmber),
                          ),
                          child: Text(
                            'Önceki veri — güncelleme başarısız (${earthquakesVM.afadStatusMessage})',
                            style: const TextStyle(
                              color: AppColors.warningAmber,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else if (earthquakesVM.statusNotice != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningAmber.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warningAmber),
                          ),
                          child: Text(
                            earthquakesVM.statusNotice!,
                            style: const TextStyle(
                              color: AppColors.warningAmber,
                              fontSize: 12,
                            ),
                          ),
                        ),

                      // List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.earthquakes.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final eq = state.earthquakes[index];
                          return _buildEarthquakeTile(context, state, eq);
                        },
                      ),

                      // Footer
                      if (earthquakesVM.fetchedAt != null) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Son güncelleme: ${_formatDate(earthquakesVM.fetchedAt!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEarthquakeTile(
    BuildContext context,
    AppStateViewModel state,
    DepremOlayi eq,
  ) {
    StatusType magType = StatusType.safe;
    if (eq.buyukluk >= 4.0) {
      magType = StatusType.alert;
    } else if (eq.buyukluk >= 3.0) {
      magType = StatusType.warning;
    }

    final depthStr = eq.derinlik != null
        ? '${eq.derinlik!.toStringAsFixed(1)} km'
        : 'Bilinmiyor';

    return InkWell(
      onTap: () {
        // Keep selected analytical state unchanged, just request camera focus.
        state.requestMapFocus(LatLng(eq.enlem, eq.boylam));
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: _getMagColor(magType).withAlpha(40),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getMagColor(magType).withAlpha(120)),
              ),
              child: Text(
                'M ${eq.buyukluk.toStringAsFixed(1)}',
                style: TextStyle(
                  color: _getMagColor(magType),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eq.yer ?? 'Bilinmiyor',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Derinlik: $depthStr • ${_formatDate(eq.tarih)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Color _getMagColor(StatusType type) {
    switch (type) {
      case StatusType.safe:
        return AppColors.textSecondary;
      case StatusType.warning:
        return AppColors.warningAmber;
      case StatusType.alert:
        return AppColors.alertBrickRed;
    }
  }

  static String _formatDate(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(dt.day)}.${twoDigits(dt.month)} ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
  }
}
