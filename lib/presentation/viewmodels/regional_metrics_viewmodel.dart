// ignore_for_file: prefer_initializing_formals
import 'package:flutter/material.dart';

import '../../domain/entities/demografi.dart';
import '../../domain/entities/fay_segmenti.dart';
import '../../domain/entities/fault_distance_result.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/ilce_demografi.dart';
import '../../domain/entities/toplanma_alani.dart';
import '../../domain/entities/toplanma_geometri.dart';
import '../../domain/entities/toplanma_metadata.dart';
import '../../domain/repositories/local_data_repository.dart';
import '../../domain/services/spatial_analysis_service.dart';
import 'view_state.dart';

class RegionalMetricsViewModel extends ChangeNotifier {
  final LocalDataRepository _localDataRepository;
  bool _disposed = false;

  ViewState _state = ViewState.initial;
  String? _errorMessage;

  Demografi? _currentDemografi;
  IlceDemografi? _currentIlceDemografi;
  List<Demografi> _demografiList = [];
  List<ToplanmaAlani> _toplanmaAlanlari = [];
  List<ToplanmaAlaniWithDistance> _closestToplanmaAlanlari = [];
  List<FaySegmenti> _faySegmentleri = [];
  double _minFaultDistanceKm = double.infinity;
  FaultDistanceResult _faultDistanceResult = const FaultDistanceResult(
    status: FaultDistanceStatus.noFaultData,
    calculationPoint: null,
  );

  RegionalMetricsViewModel({required LocalDataRepository localDataRepository})
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

  ViewState get state => _state;
  bool get isLoading => _state == ViewState.loading;
  String? get errorMessage => _errorMessage;

  bool get isToplanmaLoaded => _localDataRepository.isToplanmaLoaded;
  bool get isToplanmaAttributeSufficient =>
      _localDataRepository.isToplanmaAttributeSufficient;
  Object? get toplanmaError => _localDataRepository.toplanmaError;

  ToplanmaMetadata? get toplanmaMetadata =>
      _localDataRepository.toplanmaMetadata;
  List<ToplanmaGeometri> get toplanmaGeometrileri =>
      _localDataRepository.toplanmaGeometrileriList;

  Demografi? get currentDemografi => _currentDemografi;
  IlceDemografi? get currentIlceDemografi => _currentIlceDemografi;
  List<Demografi> get demografiList => _demografiList;
  List<ToplanmaAlani> get toplanmaAlanlari => _toplanmaAlanlari;
  List<ToplanmaAlaniWithDistance> get closestToplanmaAlanlari =>
      _closestToplanmaAlanlari;
  List<FaySegmenti> get faySegmentleri => _faySegmentleri;
  double get minFaultDistanceKm => _minFaultDistanceKm;
  FaultDistanceResult get faultDistanceResult => _faultDistanceResult;

  Future<void> loadRegionalData() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _localDataRepository.loadLocalData();
      _faySegmentleri = _localDataRepository.getFayHatlari();
      _demografiList = _localDataRepository.demografiList;

      _state = _demografiList.isEmpty && _faySegmentleri.isEmpty
          ? ViewState.empty
          : ViewState.success;
    } catch (e) {
      _state = ViewState.error;
      _errorMessage = 'Bölgesel veri yükleme hatası: $e';
    } finally {
      notifyListeners();
    }
  }

  void recalculateMetrics({
    required String? selectedIlce,
    required String? selectedMahalle,
    String? selectedMahalleKodu,
    required GeoPoint? selectedPoint,
  }) {
    if (selectedMahalleKodu != null) {
      _currentDemografi = _localDataRepository.getDemografiByCode(
        selectedMahalleKodu,
      );
      _currentIlceDemografi =
          _currentDemografi?.ilceDemografi ??
          (selectedIlce != null
              ? _localDataRepository.getIlceDemografi(selectedIlce)
              : null);
    } else if (selectedIlce != null && selectedMahalle != null) {
      _currentDemografi = _localDataRepository.getDemografi(
        selectedIlce,
        selectedMahalle,
      );
      _currentIlceDemografi =
          _currentDemografi?.ilceDemografi ??
          _localDataRepository.getIlceDemografi(selectedIlce);
    } else if (selectedIlce != null) {
      _currentDemografi = null;
      _currentIlceDemografi = _localDataRepository.getIlceDemografi(
        selectedIlce,
      );
    } else {
      _currentDemografi = null;
      _currentIlceDemografi = null;
    }

    _toplanmaAlanlari = _localDataRepository.getToplanmaAlanlari(
      ilce: selectedIlce,
      mahalle: selectedMahalle,
    );

    if (selectedPoint != null) {
      final allAreas = _localDataRepository.toplanmaAlanlariList;
      _closestToplanmaAlanlari =
          SpatialAnalysisService.getClosestToplanmaAlanlari(
            selectedPoint,
            allAreas,
            count: 3,
          );

      _faultDistanceResult =
          SpatialAnalysisService.calculateFaultDistanceResult(
            selectedPoint,
            _faySegmentleri,
          );
      _minFaultDistanceKm = _faultDistanceResult.distanceKm ?? double.infinity;
    } else {
      _closestToplanmaAlanlari = [];
      _faultDistanceResult = const FaultDistanceResult(
        status: FaultDistanceStatus.noFaultData,
        calculationPoint: null,
      );
      _minFaultDistanceKm = double.infinity;
    }

    notifyListeners();
  }
}
