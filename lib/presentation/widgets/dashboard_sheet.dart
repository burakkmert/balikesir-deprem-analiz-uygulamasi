import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/app_utils.dart';
import '../../domain/entities/deprem_olayi.dart';
import '../../domain/entities/fault_distance_result.dart';
import '../viewmodels/app_state_viewmodel.dart';
import '../viewmodels/view_state.dart';
import 'metric_card.dart';
import 'status_badge.dart';

class DashboardSheet extends StatelessWidget {
  const DashboardSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateViewModel>();
    final demografi = state.currentDemografi;
    final ilceDemo = state.currentIlceDemografi;
    final faultResult = state.faultDistanceResult;
    final closestAreas = state.closestToplanmaAlanlari;
    final selectedPoint = state.selectedPoint;

    // 1. Header Title & Subtitle logic
    final String titleText;
    final String subtitleText;

    if (selectedPoint != null) {
      titleText = 'Haritadan Seçilen Nokta';
      subtitleText =
          '${selectedPoint.latitude.toStringAsFixed(4)}, ${selectedPoint.longitude.toStringAsFixed(4)} | Harita Koordinatı';
    } else if (state.selectedMahalle != null) {
      titleText = state.selectedMahalle!;
      subtitleText = '${state.selectedIlce} / BALIKESİR Demografik Panel';
    } else if (state.selectedIlce != null) {
      titleText = '${state.selectedIlce} İlcesi';
      subtitleText = 'İlçe Demografik Görünümü / BALIKESİR';
    } else {
      titleText = 'Balıkesir Afet Analizi';
      subtitleText = 'Mahalle veya haritadan nokta seçin';
    }

    // 2. Population metric string logic
    final String popString;
    final String? popSubtitle;
    if (state.selectedMahalle != null && demografi != null) {
      popString = AppUtils.formatNumber(demografi.nufus);
      popSubtitle =
          'Kod: ${demografi.mahalleNufus.mahalleKodu} (${demografi.yil})';
    } else if (selectedPoint != null) {
      popString = 'Noktaya Ait Değil';
      popSubtitle = 'Mahalle nüfusu koordinata atanmaz';
    } else if (state.selectedIlce != null) {
      popString = 'Mahalle Seçin';
      popSubtitle = 'İlçe nüfusu için mahalle seçiniz';
    } else {
      popString = 'Seçim Yok';
      popSubtitle = 'Mahalle veya nokta seçiniz';
    }

    // 3. Fault Distance string & status logic
    final String faultVal;
    final String faultBadgeText;
    final StatusType faultBadgeType;

    if (selectedPoint == null) {
      faultVal = 'Nokta Seçilmedi';
      faultBadgeText = 'Hesaplama Noktası Yok';
      faultBadgeType = StatusType.safe;
    } else if (faultResult.isSuccess) {
      faultVal = '${faultResult.distanceKm!.toStringAsFixed(1)} km';
      faultBadgeText = 'Mesafe Bilgisi';
      faultBadgeType = StatusType.warning;
    } else if (faultResult.status == FaultDistanceStatus.outOfScope) {
      faultVal = 'Kapsam Dışı';
      faultBadgeText = 'Kapsam Dışı';
      faultBadgeType = StatusType.alert;
    } else {
      faultVal = 'Veri Yok';
      faultBadgeText = 'Veri Yok';
      faultBadgeType = StatusType.alert;
    }

    final closestAreaDist = closestAreas.isNotEmpty
        ? '${closestAreas.first.distanceKm.toStringAsFixed(1)} km'
        : '-';

    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.25, 0.35, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(180),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                titleText,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (state.isFromCache) ...[
                              const SizedBox(width: 8),
                              const StatusBadge(
                                label: 'Önbellek',
                                type: StatusType.warning,
                                icon: Icons.bolt,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedPoint != null)
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.accentCyan,
                      ),
                      tooltip: 'Yenile / AFAD Canlı Çek',
                      onPressed: () => state.refreshEarthquakes(),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  // 1. Mahalle Nüfusu
                  MetricCard(
                    title: 'Mahalle Nüfusu',
                    value: popString,
                    subtitle: popSubtitle,
                    icon: Icons.people_alt_outlined,
                    badge: StatusBadge(
                      label: demografi != null
                          ? 'TÜİK ${demografi.yil}'
                          : 'Bilgi Yok',
                      type: StatusType.safe,
                    ),
                  ),

                  // 2. En Yakın Diri Fay
                  MetricCard(
                    title: 'En Yakın Diri Fay',
                    value: faultVal,
                    subtitle: faultResult.isSuccess
                        ? (faultResult.nearestFaultCatalogId != null
                              ? 'GEM Katalog ID: ${faultResult.nearestFaultCatalogId}'
                              : 'Haritalanmış Fay Çizgisi')
                        : (selectedPoint == null
                              ? 'Hesaplama noktası seçilmedi'
                              : null),
                    icon: Icons.warning_amber_rounded,
                    badge: StatusBadge(
                      label: faultBadgeText,
                      type: faultBadgeType,
                    ),
                  ),

                  // 3. Toplanma Alanı
                  MetricCard(
                    title: 'Toplanma Alanı',
                    value: state.toplanmaError != null
                        ? 'Yükleme Hatası'
                        : (state.isToplanmaAttributeSufficient
                              ? '${state.toplanmaAlanlari.length} Lokasyon'
                              : 'Veri Yetersiz'),
                    subtitle: state.toplanmaError != null
                        ? 'Veri dosyası yüklenemedi'
                        : (state.isToplanmaAttributeSufficient
                              ? (selectedPoint != null
                                    ? 'En yakın: $closestAreaDist'
                                    : 'Mevcut lokasyonlar')
                              : 'Alan bazında resmî eşleşme yok'),
                    icon: Icons.shield_outlined,
                    badge: StatusBadge(
                      label: state.toplanmaError != null
                          ? 'Yükleme Hatası'
                          : (state.isToplanmaAttributeSufficient
                                ? (state.toplanmaAlanlari.isNotEmpty
                                      ? 'Mevcut'
                                      : 'Bölgesel Yakın')
                                : 'Veri Yetersiz'),
                      type: state.toplanmaError != null
                          ? StatusType.alert
                          : (state.isToplanmaAttributeSufficient
                                ? (state.toplanmaAlanlari.isNotEmpty
                                      ? StatusType.safe
                                      : StatusType.warning)
                                : StatusType.warning),
                    ),
                  ),

                  // 4. İlçe Yaş Bağımlılığı
                  MetricCard(
                    title: 'İlçe Yaş Bağımlılığı',
                    value: ilceDemo != null
                        ? '%${ilceDemo.toplamBagimlilik.toStringAsFixed(1)}'
                        : 'Veri Yok',
                    subtitle: ilceDemo != null
                        ? '${ilceDemo.ilceAd} (${ilceDemo.yil}) | Yaşlı: %${ilceDemo.yasliBagimlilik.toStringAsFixed(1)} | Çocuk: %${ilceDemo.cocukBagimlilik.toStringAsFixed(1)}'
                        : null,
                    icon: Icons.family_restroom_outlined,
                    badge: StatusBadge(
                      label: ilceDemo != null
                          ? 'TÜİK ${ilceDemo.yil}'
                          : 'Veri Yok',
                      type: StatusType.safe,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bu uygulama bölgesel bilgi ve farkındalık amaçlıdır. Bina güvenliği değerlendirmesi veya resmî tahliye talimatı değildir.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                        'Son depremler (AFAD)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${state.earthquakes.length} Olay',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (selectedPoint == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Text(
                    'AFAD canlı deprem verisi ve mesafe hesabı için haritadan bir nokta seçin veya arama çubuğunu kullanın.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (state.isEarthquakesLoading)
                Container(
                  padding: const EdgeInsets.all(24),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.warningAmber,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (state.earthquakesVM.state == ViewState.error)
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
                    state.earthquakesVM.errorMessage ??
                        'AFAD canlı verileri alınamadı.',
                    style: const TextStyle(
                      color: AppColors.alertBrickRed,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (state.earthquakesVM.state == ViewState.empty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Text(
                    'Seçilen tarih, büyüklük ve mesafe filtrelerinde kayıt bulunamadı.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                if (state.earthquakesVM.isFromCache &&
                    state.earthquakesVM.afadStatusMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningAmber.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warningAmber),
                    ),
                    child: Text(
                      'Önceki veri — güncelleme başarısız (${state.earthquakesVM.afadStatusMessage})',
                      style: const TextStyle(
                        color: AppColors.warningAmber,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (state.earthquakesVM.statusNotice != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningAmber.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warningAmber),
                    ),
                    child: Text(
                      state.earthquakesVM.statusNotice!,
                      style: const TextStyle(
                        color: AppColors.warningAmber,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.earthquakes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final eq = state.earthquakes[index];
                    return _buildEarthquakeTile(eq);
                  },
                ),
                if (state.earthquakesVM.fetchedAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Son alma zamanı: ${_formatDate(state.earthquakesVM.fetchedAt!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEarthquakeTile(DepremOlayi eq) {
    StatusType magType = StatusType.safe;
    if (eq.buyukluk >= 4.0) {
      magType = StatusType.alert;
    } else if (eq.buyukluk >= 3.0) {
      magType = StatusType.warning;
    }

    final depthStr = eq.derinlik != null
        ? '${eq.derinlik!.toStringAsFixed(1)} km'
        : 'Bilinmiyor';
    final tzNotice = eq.isTimezoneVerified
        ? ''
        : ' (Kaynak saati — saat dilimi doğrulanmadı)';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          StatusBadge(
            label: 'M ${eq.buyukluk.toStringAsFixed(1)}',
            type: magType,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eq.yer ?? 'Bilinmiyor',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Derinlik: $depthStr | ${_formatDate(eq.tarih)}$tzNotice',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(dt.day)}.${twoDigits(dt.month)} ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
  }
}
