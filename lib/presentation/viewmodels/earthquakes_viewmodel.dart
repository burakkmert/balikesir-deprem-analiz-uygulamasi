// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/deprem_olayi.dart';
import '../../domain/entities/earthquake_query.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/repositories/afad_repository.dart';
import 'view_state.dart';

class EarthquakesViewModel extends ChangeNotifier {
  final AfadRepository _afadRepository;
  final Duration debounceDuration;

  bool _disposed = false;
  int _generation = 0;
  Timer? _debounceTimer;

  ViewState _state = ViewState.initial;
  GeoPoint? _currentPoint;
  EarthquakeQuery? _currentQuery;
  List<DepremOlayi> _earthquakes = [];

  bool _isFromCache = false;
  bool _isPartial = false;
  bool _isRefreshing = false;
  DateTime? _fetchedAt;
  String? _afadStatusMessage;
  String? _errorMessage;
  String? _statusNotice;

  EarthquakesViewModel({
    required AfadRepository afadRepository,
    this.debounceDuration = const Duration(milliseconds: 350),
  }) : _afadRepository = afadRepository;

  bool get isDisposed => _disposed;
  GeoPoint? get currentPoint => _currentPoint;
  EarthquakeQuery? get currentQuery => _currentQuery;
  ViewState get state => _state;
  bool get isLoading => _state == ViewState.loading;
  bool get isRefreshing => _isRefreshing;
  List<DepremOlayi> get earthquakes => _earthquakes;
  bool get isFromCache => _isFromCache;
  bool get isPartial => _isPartial;
  DateTime? get fetchedAt => _fetchedAt;
  String? get afadStatusMessage => _afadStatusMessage;
  String? get errorMessage => _errorMessage;
  String? get statusNotice => _statusNotice;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  /// Called on point selection change with 350ms debounce
  void onPointSelected({
    required GeoPoint? point,
    double radius = 150.0,
    double minMagnitude = 1.5,
  }) {
    _generation++;
    _debounceTimer?.cancel();

    if (point == null) {
      clearEarthquakes();
      return;
    }

    _currentPoint = point;
    _currentQuery = EarthquakeQuery.relative(
      center: point,
      radiusKm: radius,
      minMagnitude: minMagnitude,
    );

    // Immediately unbind old events & set loading state
    _earthquakes = [];
    _isFromCache = false;
    _isPartial = false;
    _isRefreshing = false;
    _fetchedAt = null;
    _afadStatusMessage = null;
    _errorMessage = null;
    _statusNotice = null;
    _state = ViewState.loading;
    notifyListeners();

    final currentGen = _generation;
    _debounceTimer = Timer(debounceDuration, () {
      if (_disposed || currentGen != _generation || _currentPoint != point) {
        return;
      }
      fetchEarthquakes(
        point: point,
        radius: radius,
        minMagnitude: minMagnitude,
      );
    });
  }

  Future<void> fetchEarthquakes({
    required GeoPoint? point,
    double radius = 150.0,
    double minMagnitude = 1.5,
    bool forceRefresh = false,
  }) async {
    _debounceTimer?.cancel();
    final int thisGen = ++_generation;

    if (point == null) {
      clearEarthquakes();
      return;
    }

    final newQuery = EarthquakeQuery.relative(
      center: point,
      radiusKm: radius,
      minMagnitude: minMagnitude,
    );
    final bool isPointOrQueryChanged =
        _currentPoint != point || _currentQuery != newQuery;
    _currentPoint = point;
    _currentQuery = newQuery;

    if (isPointOrQueryChanged || _earthquakes.isEmpty) {
      _earthquakes = [];
      _state = ViewState.loading;
      _isRefreshing = false;
    } else {
      _isRefreshing = true;
    }
    notifyListeners();

    try {
      final response = await _afadRepository.fetchEarthquakes(
        query: newQuery,
        forceRefresh: forceRefresh,
      );

      if (_disposed || thisGen != _generation || _currentPoint != point) {
        return;
      }

      _isRefreshing = false;
      _isFromCache = response.isFromCache;
      _isPartial = response.isPartial;
      _fetchedAt = response.fetchedAt;
      _afadStatusMessage = response.errorMessage;
      _statusNotice = response.statusNotice;

      if (!response.isSuccess) {
        if (response.events.isNotEmpty) {
          _earthquakes = response.events;
          _state = ViewState.success;
          _errorMessage = response.errorMessage;
        } else {
          _earthquakes = [];
          _state = ViewState.error;
          _errorMessage =
              response.errorMessage ??
              'AFAD canlı veri sunucusundan veri alınamadı.';
        }
      } else {
        _earthquakes = response.events;
        _errorMessage = null;
        if (_earthquakes.isEmpty) {
          _state = ViewState.empty;
        } else {
          _state = ViewState.success;
        }
      }
    } catch (e) {
      if (_disposed || thisGen != _generation || _currentPoint != point) {
        return;
      }
      _isRefreshing = false;
      if (_earthquakes.isEmpty) {
        _earthquakes = [];
        _state = ViewState.error;
      }
      _errorMessage = 'AFAD veri yükleme hatası: $e';
    } finally {
      if (!_disposed && thisGen == _generation && _currentPoint == point) {
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  Future<void> clearCacheAndRefresh({required GeoPoint? point}) async {
    _debounceTimer?.cancel();
    _generation++;
    final int preGen = _generation;

    await _afadRepository.clearCache();

    if (_disposed || preGen != _generation || _currentPoint != point) {
      return;
    }

    if (point != null) {
      await fetchEarthquakes(point: point, forceRefresh: true);
    } else {
      clearEarthquakes();
    }
  }

  void clearEarthquakes() {
    _generation++;
    _debounceTimer?.cancel();
    _currentPoint = null;
    _currentQuery = null;
    _earthquakes = [];
    _state = ViewState.initial;
    _errorMessage = null;
    _afadStatusMessage = null;
    _statusNotice = null;
    _isFromCache = false;
    _isPartial = false;
    _isRefreshing = false;
    _fetchedAt = null;
    notifyListeners();
  }
}
