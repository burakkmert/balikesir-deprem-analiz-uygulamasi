import '../entities/demografi.dart';
import '../entities/fay_segmenti.dart';
import '../entities/ilce_demografi.dart';
import '../entities/mahalle_nufus.dart';
import '../entities/toplanma_alani.dart';
import '../entities/toplanma_geometri.dart';
import '../entities/toplanma_metadata.dart';

abstract class LocalDataRepository {
  Future<void> loadLocalData();
  bool get isDemografiLoaded;
  bool get isToplanmaLoaded;
  bool get isFayLoaded;
  bool get isToplanmaAttributeSufficient;

  Object? get demografiError;
  Object? get toplanmaError;
  Object? get fayError;

  ToplanmaMetadata? get toplanmaMetadata;

  List<MahalleNufus> get mahalleNufusList;
  List<IlceDemografi> get ilceDemografiList;
  List<Demografi> get demografiList;
  List<ToplanmaAlani> get toplanmaAlanlariList;
  List<ToplanmaGeometri> get toplanmaGeometrileriList;
  List<FaySegmenti> get faySegmentleriList;

  Demografi? getDemografi(String ilce, String mahalle);
  Demografi? getDemografiByCode(String mahalleKodu);
  MahalleNufus? getMahalleNufusByCode(String mahalleKodu);
  IlceDemografi? getIlceDemografi(String ilce);
  List<Demografi> filterDemografi({String? ilce, String? mahalle});
  List<ToplanmaAlani> getToplanmaAlanlari({String? ilce, String? mahalle});
  List<FaySegmenti> getFayHatlari();
  List<String> getIlceler();
  List<String> getMahalleler(String ilce);
}
