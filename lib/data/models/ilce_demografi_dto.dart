import '../../domain/entities/ilce_demografi.dart';

class IlceDemografiDto {
  static IlceDemografi fromJson(Map<String, dynamic> json) {
    final ilceKodu = json['ilce_kodu']?.toString();
    final ilceAd = json['ilce_ad']?.toString();
    final rawCocuk = json['cocuk_bagimlilik'];
    final rawToplam = json['toplam_bagimlilik'];
    final rawYasli = json['yasli_bagimlilik'];
    final rawYil = json['yil'];

    if (ilceKodu == null ||
        ilceKodu.isEmpty ||
        ilceAd == null ||
        ilceAd.isEmpty ||
        rawCocuk == null ||
        rawToplam == null ||
        rawYasli == null ||
        rawYil == null) {
      throw const FormatException(
        'IlceDemografiDto required fields are missing or empty',
      );
    }

    final double? cocuk = rawCocuk is num
        ? rawCocuk.toDouble()
        : double.tryParse(rawCocuk.toString());
    final double? toplam = rawToplam is num
        ? rawToplam.toDouble()
        : double.tryParse(rawToplam.toString());
    final double? yasli = rawYasli is num
        ? rawYasli.toDouble()
        : double.tryParse(rawYasli.toString());
    final int? yilInt = rawYil is int
        ? rawYil
        : int.tryParse(rawYil.toString());

    if (cocuk == null ||
        cocuk.isNaN ||
        cocuk.isInfinite ||
        cocuk < 0 ||
        toplam == null ||
        toplam.isNaN ||
        toplam.isInfinite ||
        toplam < 0 ||
        yasli == null ||
        yasli.isNaN ||
        yasli.isInfinite ||
        yasli < 0) {
      throw FormatException(
        'IlceDemografiDto invalid dependency values in: $json',
      );
    }

    if (yilInt == null || yilInt <= 0) {
      throw FormatException('IlceDemografiDto invalid year value: $rawYil');
    }

    return IlceDemografi(
      ilceKodu: ilceKodu,
      ilceAd: ilceAd,
      cocukBagimlilik: cocuk,
      toplamBagimlilik: toplam,
      yasliBagimlilik: yasli,
      yil: yilInt,
    );
  }

  static Map<String, dynamic> toJson(IlceDemografi entity) {
    return {
      'ilce_kodu': entity.ilceKodu,
      'ilce_ad': entity.ilceAd,
      'cocuk_bagimlilik': entity.cocukBagimlilik,
      'toplam_bagimlilik': entity.toplamBagimlilik,
      'yasli_bagimlilik': entity.yasliBagimlilik,
      'yil': entity.yil,
    };
  }
}
