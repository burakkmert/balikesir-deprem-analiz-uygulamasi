class IlceDemografi {
  final String ilceKodu;
  final String ilceAd;
  final double cocukBagimlilik;
  final double toplamBagimlilik;
  final double yasliBagimlilik;
  final int yil;

  const IlceDemografi({
    required this.ilceKodu,
    required this.ilceAd,
    required this.cocukBagimlilik,
    required this.toplamBagimlilik,
    required this.yasliBagimlilik,
    required this.yil,
  });

  @override
  String toString() {
    return 'IlceDemografi($ilceAd: Toplam %$toplamBagimlilik [$yil])';
  }
}
