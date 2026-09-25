import '../../core/utils/app_utils.dart';
import '../../domain/entities/toplanma_metadata.dart';

class ToplanmaMetadataDto {
  static ToplanmaMetadata fromJson(Map<String, dynamic> json) {
    SingleSourceRecord? singleRecord;
    if (json.containsKey('single_source_record') &&
        json['single_source_record'] is Map) {
      final rec = json['single_source_record'] as Map<String, dynamic>;
      singleRecord = SingleSourceRecord(
        id: rec['id']?.toString() ?? '',
        ad: rec['ad']?.toString() ?? '',
        il: rec['il']?.toString() ?? '',
        ilce: rec['ilce']?.toString() ?? '',
        mahalle: rec['mahalle']?.toString() ?? '',
        enlem: rec['enlem'] != null ? AppUtils.parseDouble(rec['enlem']) : null,
        boylam: rec['boylam'] != null
            ? AppUtils.parseDouble(rec['boylam'])
            : null,
        alanM2: rec['alan_m2'] != null
            ? AppUtils.parseDouble(rec['alan_m2'])
            : null,
        su: rec['su'] as bool?,
        elektrik: rec['elektrik'] as bool?,
        wc: rec['wc'] as bool?,
        tabelaKod: rec['tabela_kod']?.toString(),
        yolDurumu: rec['yol_durumu'] as bool?,
        veriUretim: rec['veri_uretim']?.toString(),
        rawOznitelik: rec['raw_oznitelik']?.toString() ?? '',
      );
    }

    return ToplanmaMetadata(
      schemaVersion: AppUtils.parseInt(json['schema_version'], 1),
      sourceFilename: json['source_filename']?.toString() ?? '',
      sourceSha256: json['source_sha256']?.toString() ?? '',
      datasetUrl: json['dataset_url']?.toString() ?? '',
      placemarkCount: AppUtils.parseInt(json['placemark_count']),
      polygonCount: AppUtils.parseInt(json['polygon_count']),
      innerBoundaryCount: AppUtils.parseInt(json['inner_boundary_count']),
      officialDistinctAreasCount: json['official_distinct_areas_count'] != null
          ? AppUtils.parseInt(json['official_distinct_areas_count'])
          : null,
      isPerAreaAttributeMatched: json['is_per_area_attribute_matched'] == true,
      singleSourceRecord: singleRecord,
    );
  }
}
