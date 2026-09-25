import 'package:flutter_test/flutter_test.dart';
import 'package:afet_analiz/app/app.dart';
import 'package:afet_analiz/domain/entities/demografi.dart';
import 'package:afet_analiz/domain/entities/deprem_olayi.dart';
import 'package:afet_analiz/domain/entities/fay_segmenti.dart';
import 'package:afet_analiz/domain/entities/earthquake_query.dart';
import 'package:afet_analiz/domain/entities/geo_point.dart';
import 'package:afet_analiz/domain/entities/ilce_demografi.dart';
import 'package:afet_analiz/domain/entities/mahalle_nufus.dart';
import 'package:afet_analiz/domain/entities/toplanma_alani.dart';
import 'package:afet_analiz/domain/entities/toplanma_geometri.dart';
import 'package:afet_analiz/domain/entities/toplanma_metadata.dart';
import 'package:afet_analiz/domain/repositories/afad_repository.dart';
import 'package:afet_analiz/domain/repositories/local_data_repository.dart';
import 'package:afet_analiz/presentation/viewmodels/app_state_viewmodel.dart';
import 'package:afet_analiz/presentation/viewmodels/earthquakes_viewmodel.dart';
import 'package:afet_analiz/presentation/viewmodels/regional_metrics_viewmodel.dart';
import 'package:afet_analiz/presentation/viewmodels/selection_viewmodel.dart';
import 'package:afet_analiz/presentation/viewmodels/view_state.dart';

class FakeLocalDataRepository implements LocalDataRepository {
  bool _demoLoaded = false;
  bool _toplanmaLoaded = false;
  bool _fayLoaded = false;

  final List<MahalleNufus> _mahalleNufus = [
    const MahalleNufus(
      mahalleKodu: '10308',
      mahalleAd: 'ATATÜRK',
      ilceAd: 'KARESI',
      nufus: 25000,
      yil: 2025,
    ),
    const MahalleNufus(
      mahalleKodu: '10311',
      mahalleAd: 'BAHÇELİEVLER',
      ilceAd: 'ALTIEYLÜL',
      nufus: 42000,
      yil: 2025,
    ),
  ];

  final List<IlceDemografi> _ilceDemografi = [
    const IlceDemografi(
      ilceKodu: '2078',
      ilceAd: 'KARESI',
      cocukBagimlilik: 25.03,
      toplamBagimlilik: 45.25,
      yasliBagimlilik: 20.22,
      yil: 2025,
    ),
    const IlceDemografi(
      ilceKodu: '2077',
      ilceAd: 'ALTIEYLÜL',
      cocukBagimlilik: 23.73,
      toplamBagimlilik: 42.87,
      yasliBagimlilik: 19.14,
      yil: 2025,
    ),
  ];

  final List<ToplanmaAlani> _toplanma = [
    const ToplanmaAlani(
      id: 'T1',
      ad: 'Atatürk Parkı',
      ilce: 'KARESI',
      mahalle: 'ATATÜRK',
      adres: 'Atatürk Cad. No:1',
      enlem: 39.6484,
      boylam: 27.8826,
    ),
  ];

  final List<FaySegmenti> _faylar = [
    const FaySegmenti(
      id: 'F1',
      slipType: 'Strike-Slip',
      subLines: [
        [GeoPoint(39.6000, 27.8000), GeoPoint(39.7000, 27.9000)],
      ],
    ),
  ];

  @override
  bool get isDemografiLoaded => _demoLoaded;

  @override
  bool get isToplanmaLoaded => _toplanmaLoaded;

  @override
  bool get isFayLoaded => _fayLoaded;

  @override
  bool get isToplanmaAttributeSufficient => false;

  @override
  Object? get demografiError => null;

  @override
  Object? get toplanmaError => null;

  @override
  Object? get fayError => null;

  @override
  ToplanmaMetadata? get toplanmaMetadata => null;

  @override
  List<MahalleNufus> get mahalleNufusList => _mahalleNufus;

  @override
  List<IlceDemografi> get ilceDemografiList => _ilceDemografi;

  @override
  List<Demografi> get demografiList {
    return _mahalleNufus.map((nufus) {
      final ilceDemo = getIlceDemografi(nufus.ilceAd);
      return Demografi(mahalleNufus: nufus, ilceDemografi: ilceDemo);
    }).toList();
  }

  @override
  List<ToplanmaAlani> get toplanmaAlanlariList => _toplanma;

  @override
  List<ToplanmaGeometri> get toplanmaGeometrileriList => const [];

  @override
  List<FaySegmenti> get faySegmentleriList => _faylar;

  @override
  Future<void> loadLocalData() async {
    _demoLoaded = true;
    _toplanmaLoaded = true;
    _fayLoaded = true;
  }

  @override
  Demografi? getDemografi(String ilce, String mahalle) {
    for (final nufus in _mahalleNufus) {
      if (nufus.ilceAd == ilce && nufus.mahalleAd == mahalle) {
        return Demografi(
          mahalleNufus: nufus,
          ilceDemografi: getIlceDemografi(ilce),
        );
      }
    }
    return null;
  }

  @override
  Demografi? getDemografiByCode(String mahalleKodu) {
    for (final nufus in _mahalleNufus) {
      if (nufus.mahalleKodu == mahalleKodu) {
        return Demografi(
          mahalleNufus: nufus,
          ilceDemografi: getIlceDemografi(nufus.ilceAd),
        );
      }
    }
    return null;
  }

  @override
  MahalleNufus? getMahalleNufusByCode(String mahalleKodu) {
    for (final nufus in _mahalleNufus) {
      if (nufus.mahalleKodu == mahalleKodu) {
        return nufus;
      }
    }
    return null;
  }

  @override
  IlceDemografi? getIlceDemografi(String ilce) {
    for (final d in _ilceDemografi) {
      if (d.ilceAd == ilce) return d;
    }
    return null;
  }

  @override
  List<Demografi> filterDemografi({String? ilce, String? mahalle}) {
    return demografiList
        .where((d) => (ilce == null || d.ilce == ilce))
        .toList();
  }

  @override
  List<ToplanmaAlani> getToplanmaAlanlari({String? ilce, String? mahalle}) {
    return _toplanma.where((t) => (ilce == null || t.ilce == ilce)).toList();
  }

  @override
  List<FaySegmenti> getFayHatlari() => _faylar;

  @override
  List<String> getIlceler() => ['ALTIEYLÜL', 'KARESI'];

  @override
  List<String> getMahalleler(String ilce) {
    if (ilce == 'KARESI') return ['ATATÜRK'];
    if (ilce == 'ALTIEYLÜL') return ['BAHÇELİEVLER'];
    return [];
  }
}

class FakeAfadRepository implements AfadRepository {
  bool shouldFail = false;
  bool returnEmpty = false;

  @override
  Future<AfadApiResponse> fetchEarthquakes({
    double lat = 39.6484,
    double lng = 27.8826,
    double radius = 150.0,
    double minMagnitude = 1.5,
    DateTime? startDate,
    DateTime? endDate,
    EarthquakeQuery? query,
    bool forceRefresh = false,
  }) async {
    if (shouldFail) {
      return AfadApiResponse(
        events: [],
        isFromCache: false,
        isSuccess: false,
        errorMessage: 'Bağlantı Zaman Aşımı',
      );
    }
    if (returnEmpty) {
      return AfadApiResponse(events: [], isFromCache: false, isSuccess: true);
    }
    return AfadApiResponse(
      events: [
        DepremOlayi(
          eventID: 'EQ-001',
          enlem: 39.65,
          boylam: 27.88,
          derinlik: 5.0,
          buyukluk: 3.5,
          yer: 'KARESI (BALIKESİR)',
          tarih: DateTime.now(),
        ),
      ],
      isFromCache: false,
      isSuccess: true,
    );
  }

  @override
  Future<void> clearCache() async {}
}

void main() {
  group('Clean Architecture Component & ViewModel Tests', () {
    late FakeLocalDataRepository fakeLocalRepo;
    late FakeAfadRepository fakeAfadRepo;

    setUp(() {
      fakeLocalRepo = FakeLocalDataRepository();
      fakeAfadRepo = FakeAfadRepository();
    });

    test('1. SelectionViewModel works without HTTP or asset IO', () {
      final selectionVM = SelectionViewModel(
        localDataRepository: fakeLocalRepo,
      );
      expect(selectionVM.selectedIlce, isNull);

      selectionVM.initializeSelection();
      expect(selectionVM.selectedIlce, isNull);
      expect(selectionVM.selectedMahalle, isNull);

      selectionVM.selectIlce('ALTIEYLÜL');
      expect(selectionVM.selectedIlce, equals('ALTIEYLÜL'));
      expect(selectionVM.selectedMahalle, isNull);

      selectionVM.selectMahalle('BAHÇELİEVLER');
      expect(selectionVM.selectedMahalle, equals('BAHÇELİEVLER'));
    });

    test(
      '2. RegionalMetricsViewModel operates correctly with fake repository',
      () async {
        final regionalVM = RegionalMetricsViewModel(
          localDataRepository: fakeLocalRepo,
        );
        expect(regionalVM.state, equals(ViewState.initial));

        await regionalVM.loadRegionalData();
        expect(regionalVM.state, equals(ViewState.success));
        expect(regionalVM.demografiList.length, equals(2));

        regionalVM.recalculateMetrics(
          selectedIlce: 'KARESI',
          selectedMahalle: 'ATATÜRK',
          selectedPoint: const GeoPoint(39.6484, 27.8826),
        );

        expect(regionalVM.currentDemografi?.ilce, equals('KARESI'));
        expect(regionalVM.minFaultDistanceKm.isFinite, isTrue);
      },
    );

    test(
      '3. EarthquakesViewModel transforms repository error into error state',
      () async {
        fakeAfadRepo.shouldFail = true;
        final eqVM = EarthquakesViewModel(afadRepository: fakeAfadRepo);

        await eqVM.fetchEarthquakes(point: const GeoPoint(39.6484, 27.8826));

        expect(eqVM.state, equals(ViewState.error));
        expect(eqVM.errorMessage, contains('Bağlantı Zaman Aşımı'));
      },
    );

    test(
      '4. Earthquake failure does NOT corrupt loaded regional metrics state',
      () async {
        fakeAfadRepo.shouldFail = true;
        final coordinator = AppStateViewModel(
          localDataRepository: fakeLocalRepo,
          afadRepository: fakeAfadRepo,
        );

        await coordinator.initialize();
        coordinator.selectIlceAndMahalle('KARESI', 'ATATÜRK');

        expect(coordinator.regionalMetricsVM.state, equals(ViewState.success));
        expect(coordinator.currentDemografi, isNotNull);
        expect(coordinator.currentDemografi?.nufus, equals(25000));
      },
    );

    test(
      '5. Successful empty result and repository error are kept distinct',
      () async {
        fakeAfadRepo.returnEmpty = true;
        final eqVM = EarthquakesViewModel(afadRepository: fakeAfadRepo);

        await eqVM.fetchEarthquakes(point: const GeoPoint(39.6484, 27.8826));

        expect(eqVM.state, equals(ViewState.empty));
        expect(eqVM.errorMessage, isNull);
      },
    );

    test('6. AfetAnalizAppModule correctly wires dependencies via constructor injection', () {
      final module = AfetAnalizAppModule();
      final appState = module.createAppState(
        localDataRepository: fakeLocalRepo,
        afadRepository: fakeAfadRepo,
      );

      expect(appState, isNotNull);
      expect(appState.selectionVM, isNotNull);
      expect(appState.regionalMetricsVM, isNotNull);
      expect(appState.earthquakesVM, isNotNull);
      module.dispose();
    });
  });
}
