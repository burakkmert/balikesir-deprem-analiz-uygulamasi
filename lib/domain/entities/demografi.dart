import 'ilce_demografi.dart';
import 'mahalle_nufus.dart';

class Demografi {
  final MahalleNufus mahalleNufus;
  final IlceDemografi? ilceDemografi;

  const Demografi({required this.mahalleNufus, this.ilceDemografi});

  String get ilce => mahalleNufus.ilceAd;
  String get mahalle => mahalleNufus.mahalleAd;
  int get nufus => mahalleNufus.nufus;
  int get yil => mahalleNufus.yil;

  double get cocukBagimlilik => ilceDemografi?.cocukBagimlilik ?? 0.0;
  double get toplamBagimlilik => ilceDemografi?.toplamBagimlilik ?? 0.0;
  double get yasliBagimlilik => ilceDemografi?.yasliBagimlilik ?? 0.0;

  @override
  String toString() {
    return 'Demografi(${mahalleNufus.mahalleAd}, ${mahalleNufus.ilceAd}: ${mahalleNufus.nufus})';
  }
}
