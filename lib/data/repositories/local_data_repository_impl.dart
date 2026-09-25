import '../../core/utils/app_utils.dart';
import '../../domain/entities/demografi.dart';
import '../../domain/entities/fay_segmenti.dart';
import '../../domain/entities/ilce_demografi.dart';
import '../../domain/entities/mahalle_nufus.dart';
import '../../domain/entities/toplanma_alani.dart';
import '../../domain/entities/toplanma_geometri.dart';
import '../../domain/entities/toplanma_metadata.dart';
import '../../domain/repositories/local_data_repository.dart';
import '../datasources/asset_local_datasource.dart';

class LocalDataRepositoryImpl implements LocalDataRepository {
  final AssetLocalDataSource _assetDataSource;

  List<MahalleNufus> _mahalleNufusList = [];
  List<IlceDemografi> _ilceDemografiList = [];
  List<ToplanmaGeometri> _toplanmaGeometrileriList = [];
  List<FaySegmenti> _faySegmentleriList = [];
  ToplanmaMetadata? _toplanmaMetadata;

  bool _isMahalleNufusLoaded = false;
  bool _isIlceDemografiLoaded = false;
  bool _isToplanmaLoaded = false;
  bool _isFayLoaded = false;

  Object? _mahalleNufusError;
  Object? _ilceDemografiError;
  Object? _toplanmaError;
  Object? _fayError;

  LocalDataRepositoryImpl({AssetLocalDataSource? assetDataSource})
    : _assetDataSource = assetDataSource ?? AssetLocalDataSource();

  @override
  bool get isDemografiLoaded => _isMahalleNufusLoaded || _isIlceDemografiLoaded;

  @override
  bool get isToplanmaLoaded => _isToplanmaLoaded;

  @override
  bool get isFayLoaded => _isFayLoaded;

  @override
  Object? get demografiError => _mahalleNufusError ?? _ilceDemografiError;

  @override
  Object? get toplanmaError => _toplanmaError;

  @override
  Object? get fayError => _fayError;

  @override
  bool get isToplanmaAttributeSufficient =>
      _isToplanmaLoaded &&
      _toplanmaError == null &&
      (_toplanmaMetadata?.isPerAreaAttributeMatched ?? false);

  @override
  ToplanmaMetadata? get toplanmaMetadata => _toplanmaMetadata;

  @override
  List<MahalleNufus> get mahalleNufusList =>
      List.unmodifiable(_mahalleNufusList);

  @override
  List<IlceDemografi> get ilceDemografiList =>
      List.unmodifiable(_ilceDemografiList);

  @override
  List<Demografi> get demografiList {
    return _mahalleNufusList.map((nufus) {
      final ilceDemo = getIlceDemografi(nufus.ilceAd);
      return Demografi(mahalleNufus: nufus, ilceDemografi: ilceDemo);
    }).toList();
  }

  @override
  List<ToplanmaAlani> get toplanmaAlanlariList => const [];

  @override
  List<ToplanmaGeometri> get toplanmaGeometrileriList =>
      List.unmodifiable(_toplanmaGeometrileriList);

  @override
  List<FaySegmenti> get faySegmentleriList =>
      List.unmodifiable(_faySegmentleriList);

  @override
  Future<void> loadLocalData() async {
    // 1. Mahalle Population loading
    if (!_isMahalleNufusLoaded) {
      try {
        _mahalleNufusList = await _assetDataSource.loadMahalleNufusData();
        _isMahalleNufusLoaded = true;
        _mahalleNufusError = null;
      } catch (e) {
        _mahalleNufusError = e;
        _isMahalleNufusLoaded = false;
      }
    }

    // 2. District Demography loading (independent retry)
    if (!_isIlceDemografiLoaded) {
      try {
        _ilceDemografiList = await _assetDataSource.loadIlceDemografiData();
        _isIlceDemografiLoaded = true;
        _ilceDemografiError = null;
      } catch (e) {
        _ilceDemografiError = e;
        _isIlceDemografiLoaded = false;
      }
    }

    // 3. Load Assembly Areas Metadata and Geometries independently
    if (!_isToplanmaLoaded) {
      _toplanmaError = null;
      try {
        _toplanmaMetadata = await _assetDataSource.loadToplanmaMetadata();
        _toplanmaGeometrileriList = await _assetDataSource
            .loadToplanmaGeometrileriData();
        _isToplanmaLoaded = true;
      } catch (e) {
        _isToplanmaLoaded = false;
        _toplanmaError = e;
        _toplanmaMetadata = null;
        _toplanmaGeometrileriList = [];
      }
    }

    // 4. Load Fault Lines independently
    if (!_isFayLoaded) {
      _fayError = null;
      try {
        _faySegmentleriList = await _assetDataSource.loadFayHatlariData();
        _isFayLoaded = true;
      } catch (e) {
        _isFayLoaded = false;
        _fayError = e;
        _faySegmentleriList = [];
      }
    }
  }

  @override
  Demografi? getDemografi(String ilce, String mahalle) {
    final ilceClean = AppUtils.normalizeTurkish(ilce);
    final mahalleClean = AppUtils.normalizeTurkish(mahalle);

    for (final nufus in _mahalleNufusList) {
      if (AppUtils.normalizeTurkish(nufus.ilceAd) == ilceClean &&
          AppUtils.normalizeTurkish(nufus.mahalleAd) == mahalleClean) {
        final ilceDemo = getIlceDemografi(nufus.ilceAd);
        return Demografi(mahalleNufus: nufus, ilceDemografi: ilceDemo);
      }
    }
    return null;
  }

  @override
  Demografi? getDemografiByCode(String mahalleKodu) {
    for (final nufus in _mahalleNufusList) {
      if (nufus.mahalleKodu == mahalleKodu) {
        final ilceDemo = getIlceDemografi(nufus.ilceAd);
        return Demografi(mahalleNufus: nufus, ilceDemografi: ilceDemo);
      }
    }
    return null;
  }

  @override
  MahalleNufus? getMahalleNufusByCode(String mahalleKodu) {
    for (final nufus in _mahalleNufusList) {
      if (nufus.mahalleKodu == mahalleKodu) {
        return nufus;
      }
    }
    return null;
  }

  @override
  IlceDemografi? getIlceDemografi(String ilce) {
    final ilceClean = AppUtils.normalizeTurkish(ilce);
    for (final demo in _ilceDemografiList) {
      if (AppUtils.normalizeTurkish(demo.ilceAd) == ilceClean) {
        return demo;
      }
    }
    return null;
  }

  @override
  List<Demografi> filterDemografi({String? ilce, String? mahalle}) {
    return demografiList.where((d) {
      if (ilce != null &&
          ilce.isNotEmpty &&
          AppUtils.normalizeTurkish(d.ilce) !=
              AppUtils.normalizeTurkish(ilce)) {
        return false;
      }
      if (mahalle != null &&
          mahalle.isNotEmpty &&
          AppUtils.normalizeTurkish(d.mahalle) !=
              AppUtils.normalizeTurkish(mahalle)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  List<ToplanmaAlani> getToplanmaAlanlari({String? ilce, String? mahalle}) {
    return const [];
  }

  @override
  List<FaySegmenti> getFayHatlari() {
    return _faySegmentleriList;
  }

  @override
  List<String> getIlceler() {
    final Set<String> ilceler = {};
    for (final d in _mahalleNufusList) {
      if (d.ilceAd.isNotEmpty) ilceler.add(d.ilceAd);
    }
    final result = ilceler.toList()..sort((a, b) => a.compareTo(b));
    return result;
  }

  @override
  List<String> getMahalleler(String ilce) {
    final Set<String> mahalleler = {};
    final ilceClean = AppUtils.normalizeTurkish(ilce);

    for (final d in _mahalleNufusList) {
      if (AppUtils.normalizeTurkish(d.ilceAd) == ilceClean &&
          d.mahalleAd.isNotEmpty) {
        mahalleler.add(d.mahalleAd);
      }
    }
    final result = mahalleler.toList()..sort((a, b) => a.compareTo(b));
    return result;
  }
}
