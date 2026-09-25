class MahalleNufus {
  final String mahalleKodu;
  final String mahalleAd;
  final String ilceAd;
  final int nufus;
  final int yil;

  const MahalleNufus({
    required this.mahalleKodu,
    required this.mahalleAd,
    required this.ilceAd,
    required this.nufus,
    required this.yil,
  });

  @override
  String toString() {
    return 'MahalleNufus($mahalleAd, $ilceAd: $nufus [$yil])';
  }
}
