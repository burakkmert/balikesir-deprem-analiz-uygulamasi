import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/demografi.dart';
import '../../domain/entities/deprem_olayi.dart';
import '../../domain/entities/fay_segmenti.dart';
import '../../domain/entities/fault_distance_result.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/ilce_demografi.dart';
import '../../domain/entities/toplanma_alani.dart';
import '../../domain/entities/toplanma_geometri.dart';
import '../../domain/repositories/afad_repository.dart';
import '../../domain/repositories/local_data_repository.dart';
import '../../domain/services/spatial_analysis_service.dart';
import 'earthquakes_viewmodel.dart';
import 'regional_metrics_viewmodel.dart';
import 'selection_viewmodel.dart';
import 'view_state.dart';

class AppStateViewModel extends ChangeNotifier {
  final SelectionViewModel selectionVM;
  final RegionalMetricsViewModel regionalMetricsVM;
  final EarthquakesViewModel earthquakesVM;
  bool _disposed = false;

  AppStateViewModel({
    required LocalDataRepository localDataRepository,
    required AfadRepository afadRepository,
    SelectionViewModel? selectionViewModel,
    RegionalMetricsViewModel? regionalMetricsViewModel,
    EarthquakesViewModel? earthquakesViewModel,
  }) : selectionVM =
           selectionViewModel ??
           SelectionViewModel(localDataRepository: localDataRepository),
       regionalMetricsVM =
           regionalMetricsViewModel ??
           RegionalMetricsViewModel(localDataRepository: localDataRepository),
       earthquakesVM =
           earthquakesViewModel ??
           EarthquakesViewModel(afadRepository: afadRepository) {
    selectionVM.addListener(_onSelectionChanged);
    regionalMetricsVM.addListener(notifyListeners);
    earthquakesVM.addListener(notifyListeners);
  }

  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    selectionVM.removeListener(_onSelectionChanged);
    regionalMetricsVM.removeListener(notifyListeners);
    earthquakesVM.removeListener(notifyListeners);
    selectionVM.dispose();
    regionalMetricsVM.dispose();
    earthquakesVM.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // Unified getters for widget binding
  ViewState get viewState => regionalMetricsVM.state;
  bool get isRegionalLoading => regionalMetricsVM.isLoading;
  bool get isEarthquakesLoading => earthquakesVM.isLoading;
  bool get isLoading =>
      isRegionalLoading; // Map does not unmount during AFAD refresh
  bool get isLoaded =>
      regionalMetricsVM.state == ViewState.success ||
      regionalMetricsVM.state == ViewState.empty;
  String? get errorMessage =>
      regionalMetricsVM.errorMessage ?? earthquakesVM.errorMessage;
  String? get afadStatusMessage => earthquakesVM.afadStatusMessage;

  String? get selectedIlce => selectionVM.selectedIlce;
  String? get selectedMahalle => selectionVM.selectedMahalle;
  String? get selectedMahalleKodu => selectionVM.selectedMahalleKodu;
  LatLng? get selectedPoint {
    final pt = selectionVM.selectedPoint;
    return pt != null ? LatLng(pt.latitude, pt.longitude) : null;
  }

  Demografi? get currentDemografi => regionalMetricsVM.currentDemografi;
  IlceDemografi? get currentIlceDemografi =>
      regionalMetricsVM.currentIlceDemografi;
  List<Demografi> get demografiList => regionalMetricsVM.demografiList;
  List<ToplanmaAlani> get toplanmaAlanlari =>
      regionalMetricsVM.toplanmaAlanlari;
  List<ToplanmaAlaniWithDistance> get closestToplanmaAlanlari =>
      regionalMetricsVM.closestToplanmaAlanlari;
  List<FaySegmenti> get faySegmentleri => regionalMetricsVM.faySegmentleri;
  List<DepremOlayi> get earthquakes => earthquakesVM.earthquakes;
  double get minFaultDistanceKm => regionalMetricsVM.minFaultDistanceKm;
  FaultDistanceResult get faultDistanceResult =>
      regionalMetricsVM.faultDistanceResult;
  bool get isFromCache => earthquakesVM.isFromCache;
  bool get isToplanmaAttributeSufficient =>
      regionalMetricsVM.isToplanmaAttributeSufficient;
  Object? get toplanmaError => regionalMetricsVM.toplanmaError;
  List<ToplanmaGeometri> get toplanmaGeometrileri =>
      regionalMetricsVM.toplanmaGeometrileri;

  List<String> get ilceler => selectionVM.ilceler;
  List<String> get mahalleler => selectionVM.mahalleler;
  List<String> mahallelerForIlce(String ilce) =>
      selectionVM.mahallelerForIlce(ilce);

  /// Coordinate initialization across ViewModels
  Future<void> initialize() async {
    await regionalMetricsVM.loadRegionalData();
    selectionVM.initializeSelection();
    await _recalculateAndFetch();
  }

  void selectIlce(String ilce) {
    selectionVM.selectIlce(ilce);
  }

  void selectMahalle(String mahalle) {
    selectionVM.selectMahalle(mahalle);
  }

  void selectIlceAndMahalle(
    String ilce,
    String mahalle, {
    String? mahalleKodu,
  }) {
    selectionVM.selectIlceAndMahalle(ilce, mahalle, mahalleKodu: mahalleKodu);
  }

  void updateSelectedPoint(LatLng point) {
    selectionVM.updateSelectedPoint(GeoPoint(point.latitude, point.longitude));
  }

  void clearSelection() {
    selectionVM.clearSelection();
  }

  Future<void> refreshEarthquakes() async {
    final pt = selectionVM.selectedPoint;
    if (pt != null) {
      await earthquakesVM.fetchEarthquakes(point: pt, forceRefresh: true);
    }
  }

  Future<void> clearCacheAndRefresh() async {
    final pt = selectionVM.selectedPoint;
    if (pt != null) {
      await earthquakesVM.clearCacheAndRefresh(point: pt);
    }
  }

  void _onSelectionChanged() {
    if (_disposed) return;
    _recalculateAndFetch();
    notifyListeners();
  }

  Future<void> _recalculateAndFetch() async {
    if (_disposed) return;

    regionalMetricsVM.recalculateMetrics(
      selectedIlce: selectionVM.selectedIlce,
      selectedMahalle: selectionVM.selectedMahalle,
      selectedMahalleKodu: selectionVM.selectedMahalleKodu,
      selectedPoint: selectionVM.selectedPoint,
    );

    final pt = selectionVM.selectedPoint;
    if (pt != null) {
      earthquakesVM.onPointSelected(point: pt);
    } else {
      earthquakesVM.clearEarthquakes();
    }
  }
}

typedef AppState = AppStateViewModel;
