class DepremOlayi {
  final String eventID;
  final double enlem;
  final double boylam;
  final double? derinlik;
  final double buyukluk;
  final String? yer;
  final String? tip;
  final DateTime tarih;
  final DateTime? fetchedAt;
  final bool isTimezoneVerified;

  const DepremOlayi({
    required this.eventID,
    required this.enlem,
    required this.boylam,
    this.derinlik,
    required this.buyukluk,
    this.yer,
    this.tip,
    required this.tarih,
    this.fetchedAt,
    this.isTimezoneVerified = false,
  });

  @override
  String toString() {
    return 'DepremOlayi(eventID: $eventID, buyukluk: $buyukluk, yer: $yer, tarih: $tarih)';
  }
}
