class AppConstants {
  static const String appName = 'AfetAnaliz Balıkesir';

  // Balıkesir Center Geolocation
  static const double balikesirLat = 39.6484;
  static const double balikesirLng = 27.8826;
  static const double defaultZoom = 9.5;

  // AFAD API Config
  static const String afadApiBaseUrl =
      'https://deprem.afad.gov.tr/apiv2/event/filter';

  // Asset Paths
  static const String mahalleNufusJsonPath =
      'assets/data/balikesir_mahalle_nufus.json';
  static const String ilceDemografiJsonPath =
      'assets/data/balikesir_ilce_demografi.json';
  static const String toplanmaMetadataJsonPath =
      'assets/data/balikesir_toplanma_metadata.json';
  static const String toplanmaGeometrileriGeoJsonPath =
      'assets/data/balikesir_toplanma_geometrileri.geojson';
  static const String fayHatlariGeoJsonPath =
      'assets/data/balikesir_fay_hatlari.geojson';
}
