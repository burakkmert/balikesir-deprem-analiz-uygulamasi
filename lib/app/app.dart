import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/utils/rate_limiter.dart';
import '../data/datasources/afad_remote_datasource.dart';
import '../data/datasources/asset_local_datasource.dart';
import '../data/datasources/cache_datasource.dart';
import '../data/repositories/afad_repository_impl.dart';
import '../data/repositories/local_data_repository_impl.dart';
import '../domain/repositories/afad_repository.dart';
import '../domain/repositories/local_data_repository.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/viewmodels/app_state_viewmodel.dart';
import '../presentation/viewmodels/earthquakes_viewmodel.dart';
import '../presentation/viewmodels/regional_metrics_viewmodel.dart';
import '../presentation/viewmodels/selection_viewmodel.dart';

class AfetAnalizAppModule {
  final http.Client _httpClient;
  final bool _ownsClient;

  AfetAnalizAppModule({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  /// Create singletons and wire dependencies
  AppStateViewModel createAppState({
    AssetLocalDataSource? assetDataSource,
    CacheDataSource? cacheDataSource,
    RateLimiter? rateLimiter,
    LocalDataRepository? localDataRepository,
    AfadRepository? afadRepository,
  }) {
    final assetSource = assetDataSource ?? AssetLocalDataSource();
    final cacheSource = cacheDataSource ?? CacheDataSource();
    final limiter = rateLimiter ?? RateLimiter();

    final localRepo =
        localDataRepository ??
        LocalDataRepositoryImpl(assetDataSource: assetSource);

    final afadRepo =
        afadRepository ??
        AfadRepositoryImpl(
          remoteDataSource: AfadRemoteDataSource(client: _httpClient),
          cacheDataSource: cacheSource,
          rateLimiter: limiter,
        );

    final selectionVM = SelectionViewModel(localDataRepository: localRepo);
    final regionalMetricsVM = RegionalMetricsViewModel(
      localDataRepository: localRepo,
    );
    final earthquakesVM = EarthquakesViewModel(afadRepository: afadRepo);

    return AppStateViewModel(
      localDataRepository: localRepo,
      afadRepository: afadRepo,
      selectionViewModel: selectionVM,
      regionalMetricsViewModel: regionalMetricsVM,
      earthquakesViewModel: earthquakesVM,
    );
  }

  void dispose() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }
}

class AfetAnalizApp extends StatelessWidget {
  const AfetAnalizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
