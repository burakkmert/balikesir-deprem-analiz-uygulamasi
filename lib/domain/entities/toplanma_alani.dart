class ToplanmaAlani {
  final String id;
  final String ad;
  final String ilce;
  final String mahalle;
  final String adres;
  final double enlem;
  final double boylam;
  final double? alanM2;
  final bool? su;
  final bool? elektrik;
  final bool? wc;
  final bool isPerAreaAttributeMatched;
  final String aciklama;

  const ToplanmaAlani({
    required this.id,
    required this.ad,
    required this.ilce,
    required this.mahalle,
    required this.adres,
    required this.enlem,
    required this.boylam,
    this.alanM2,
    this.su,
    this.elektrik,
    this.wc,
    this.isPerAreaAttributeMatched = false,
    this.aciklama = '',
  });

  @override
  String toString() {
    return 'ToplanmaAlani(id: $id, ad: $ad, ilce: $ilce, mahalle: $mahalle)';
  }
}
