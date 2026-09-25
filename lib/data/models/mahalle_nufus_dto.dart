import '../../domain/entities/mahalle_nufus.dart';

class MahalleNufusDto {
  static MahalleNufus fromJson(Map<String, dynamic> json) {
    final mahalleKodu = json['mahalle_kodu']?.toString();
    final mahalleAd = json['mahalle_ad']?.toString();
    final ilceAd = json['ilce_ad']?.toString();
    final rawNufus = json['nufus'];
    final rawYil = json['yil'];

    if (mahalleKodu == null ||
        mahalleKodu.isEmpty ||
        mahalleAd == null ||
        mahalleAd.isEmpty ||
        ilceAd == null ||
        ilceAd.isEmpty ||
        rawNufus == null ||
        rawYil == null) {
      throw const FormatException(
        'MahalleNufusDto required fields are missing or empty',
      );
    }

    final num? nufusNum = rawNufus is num
        ? rawNufus
        : num.tryParse(rawNufus.toString());
    final int? yilInt = rawYil is int
        ? rawYil
        : int.tryParse(rawYil.toString());

    if (nufusNum == null ||
        nufusNum.isNaN ||
        nufusNum.isInfinite ||
        nufusNum < 0 ||
        nufusNum != nufusNum.toInt()) {
      throw FormatException(
        'MahalleNufusDto invalid population value: $rawNufus',
      );
    }

    if (yilInt == null || yilInt <= 0) {
      throw FormatException('MahalleNufusDto invalid year value: $rawYil');
    }

    return MahalleNufus(
      mahalleKodu: mahalleKodu,
      mahalleAd: mahalleAd,
      ilceAd: ilceAd,
      nufus: nufusNum.toInt(),
      yil: yilInt,
    );
  }

  static Map<String, dynamic> toJson(MahalleNufus entity) {
    return {
      'mahalle_kodu': entity.mahalleKodu,
      'mahalle_ad': entity.mahalleAd,
      'ilce_ad': entity.ilceAd,
      'nufus': entity.nufus,
      'yil': entity.yil,
    };
  }
}
