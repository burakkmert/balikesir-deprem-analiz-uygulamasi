class SingleSourceRecord {
  final String id;
  final String ad;
  final String il;
  final String ilce;
  final String mahalle;
  final double? enlem;
  final double? boylam;
  final double? alanM2;
  final bool? su;
  final bool? elektrik;
  final bool? wc;
  final String? tabelaKod;
  final bool? yolDurumu;
  final String? veriUretim;
  final String rawOznitelik;

  const SingleSourceRecord({
    required this.id,
    required this.ad,
    required this.il,
    required this.ilce,
    required this.mahalle,
    this.enlem,
    this.boylam,
    this.alanM2,
    this.su,
    this.elektrik,
    this.wc,
    this.tabelaKod,
    this.yolDurumu,
    this.veriUretim,
    this.rawOznitelik = '',
  });
}

class ToplanmaMetadata {
  final int schemaVersion;
  final String sourceFilename;
  final String sourceSha256;
  final String datasetUrl;
  final int placemarkCount;
  final int polygonCount;
  final int innerBoundaryCount;
  final int? officialDistinctAreasCount;
  final bool isPerAreaAttributeMatched;
  final SingleSourceRecord? singleSourceRecord;

  const ToplanmaMetadata({
    required this.schemaVersion,
    required this.sourceFilename,
    required this.sourceSha256,
    required this.datasetUrl,
    required this.placemarkCount,
    required this.polygonCount,
    required this.innerBoundaryCount,
    this.officialDistinctAreasCount,
    required this.isPerAreaAttributeMatched,
    this.singleSourceRecord,
  });
}
