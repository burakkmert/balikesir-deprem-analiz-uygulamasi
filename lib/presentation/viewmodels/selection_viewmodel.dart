// ignore_for_file: prefer_initializing_formals
import 'package:flutter/material.dart';

import '../../core/utils/app_utils.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/repositories/local_data_repository.dart';

class SelectionViewModel extends ChangeNotifier {
  final LocalDataRepository _localDataRepository;
  bool _disposed = false;

  String? _selectedIlce;
  String? _selectedMahalle;
  String? _selectedMahalleKodu;
  GeoPoint? _selectedPoint;

  SelectionViewModel({required LocalDataRepository localDataRepository})
    : _localDataRepository = localDataRepository;

  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  String? get selectedIlce => _selectedIlce;
  String? get selectedMahalle => _selectedMahalle;
  String? get selectedMahalleKodu => _selectedMahalleKodu;
  GeoPoint? get selectedPoint => _selectedPoint;

  bool get hasPointSelection => _selectedPoint != null;
  bool get hasAdministrativeSelection => _selectedIlce != null;
  bool get hasAnySelection => hasPointSelection || hasAdministrativeSelection;

  String? get pointSourceLabel =>
      hasPointSelection ? 'Haritadan seçildi' : null;

  List<String> get ilceler => _localDataRepository.getIlceler();
  List<String> get mahalleler => _selectedIlce != null
      ? _localDataRepository.getMahalleler(_selectedIlce!)
      : [];
  List<String> mahallelerForIlce(String ilce) =>
      _localDataRepository.getMahalleler(ilce);

  void initializeSelection() {
    // Initial launch: No auto-selected district/neighborhood or point
    _selectedIlce = null;
    _selectedMahalle = null;
    _selectedMahalleKodu = null;
    _selectedPoint = null;
    notifyListeners();
  }

  void selectIlce(String ilce) {
    if (_selectedIlce == ilce &&
        _selectedMahalle == null &&
        _selectedPoint == null) {
      return;
    }

    _selectedIlce = ilce;
    _selectedMahalle = null;
    _selectedMahalleKodu = null;
    _selectedPoint = null; // Clear map point when picking district

    notifyListeners();
  }

  void selectMahalle(String mahalle) {
    if (_selectedIlce == null) return;
    final demo = _localDataRepository.getDemografi(_selectedIlce!, mahalle);
    if (demo == null) return;
    _selectedMahalle = demo.mahalleNufus.mahalleAd;
    _selectedMahalleKodu = demo.mahalleNufus.mahalleKodu;
    _selectedPoint = null;
    notifyListeners();
  }

  void selectMahalleByCode(String mahalleKodu, {String? expectedIlce}) {
    final nufus = _localDataRepository.getMahalleNufusByCode(mahalleKodu);
    if (nufus == null) return;
    if (expectedIlce != null &&
        AppUtils.normalizeTurkish(nufus.ilceAd) !=
            AppUtils.normalizeTurkish(expectedIlce)) {
      return;
    }
    _selectedIlce = nufus.ilceAd;
    _selectedMahalle = nufus.mahalleAd;
    _selectedMahalleKodu = nufus.mahalleKodu;
    _selectedPoint = null;
    notifyListeners();
  }

  void selectIlceAndMahalle(
    String ilce,
    String mahalle, {
    String? mahalleKodu,
  }) {
    if (mahalleKodu != null) {
      final nufus = _localDataRepository.getMahalleNufusByCode(mahalleKodu);
      if (nufus == null) return;
      if (AppUtils.normalizeTurkish(nufus.ilceAd) !=
          AppUtils.normalizeTurkish(ilce)) {
        return;
      }
      _selectedIlce = nufus.ilceAd;
      _selectedMahalle = nufus.mahalleAd;
      _selectedMahalleKodu = nufus.mahalleKodu;
      _selectedPoint = null;
      notifyListeners();
      return;
    }

    final demo = _localDataRepository.getDemografi(ilce, mahalle);
    if (demo == null) return;
    _selectedIlce = demo.mahalleNufus.ilceAd;
    _selectedMahalle = demo.mahalleNufus.mahalleAd;
    _selectedMahalleKodu = demo.mahalleNufus.mahalleKodu;
    _selectedPoint = null;
    notifyListeners();
  }

  void updateSelectedPoint(GeoPoint point) {
    if (point.latitude.isNaN ||
        point.latitude.isInfinite ||
        point.longitude.isNaN ||
        point.longitude.isInfinite ||
        point.latitude < -90.0 ||
        point.latitude > 90.0 ||
        point.longitude < -180.0 ||
        point.longitude > 180.0) {
      return; // Ignore invalid/non-finite coordinates
    }

    _selectedPoint = point;
    _selectedIlce =
        null; // Clear administrative selection when map point is tapped
    _selectedMahalle = null;
    _selectedMahalleKodu = null;

    notifyListeners();
  }

  void clearSelection() {
    _selectedIlce = null;
    _selectedMahalle = null;
    _selectedMahalleKodu = null;
    _selectedPoint = null;
    notifyListeners();
  }
}
