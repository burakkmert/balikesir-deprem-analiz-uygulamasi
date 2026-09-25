import '../../core/utils/app_utils.dart';
import '../../domain/entities/toplanma_alani.dart';

class ToplanmaAlaniDto {
  static ToplanmaAlani fromJson(Map<String, dynamic> json) {
    final props = (json['properties'] as Map<String, dynamic>?) ?? json;

    return ToplanmaAlani(
      id: props['id']?.toString() ?? props['OBJECTID']?.toString() ?? '',
      ad:
          props['ad']?.toString() ??
          props['AD']?.toString() ??
          props['name']?.toString() ??
          '',
      ilce: props['ilce']?.toString() ?? props['ILCE']?.toString() ?? '',
      mahalle:
          props['mahalle']?.toString() ?? props['MAHALLE']?.toString() ?? '',
      adres: props['adres']?.toString() ?? props['ADRES']?.toString() ?? '',
      enlem: AppUtils.parseDouble(
        props['enlem'] ?? props['latitude'] ?? props['lat'],
      ),
      boylam: AppUtils.parseDouble(
        props['boylam'] ?? props['longitude'] ?? props['lng'] ?? props['lon'],
      ),
      alanM2: props['alanM2'] != null || props['alan_m2'] != null
          ? AppUtils.parseDouble(props['alanM2'] ?? props['alan_m2'])
          : null,
      su: props['su'] as bool?,
      elektrik: props['elektrik'] as bool?,
      wc: props['wc'] as bool?,
      isPerAreaAttributeMatched: props['is_per_area_attribute_matched'] == true,
      aciklama:
          props['aciklama']?.toString() ?? props['note']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> toJson(ToplanmaAlani entity) {
    return {
      'id': entity.id,
      'ad': entity.ad,
      'ilce': entity.ilce,
      'mahalle': entity.mahalle,
      'adres': entity.adres,
      'enlem': entity.enlem,
      'boylam': entity.boylam,
      'alan_m2': entity.alanM2,
      'su': entity.su,
      'elektrik': entity.elektrik,
      'wc': entity.wc,
      'is_per_area_attribute_matched': entity.isPerAreaAttributeMatched,
      'aciklama': entity.aciklama,
    };
  }
}
