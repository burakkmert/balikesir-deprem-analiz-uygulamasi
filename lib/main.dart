import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'presentation/viewmodels/app_state_viewmodel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RootApp());
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  late final AfetAnalizAppModule _module;
  late final AppStateViewModel _appStateViewModel;

  @override
  void initState() {
    super.initState();
    _module = AfetAnalizAppModule();
    _appStateViewModel = _module.createAppState()..initialize();
  }

  @override
  void dispose() {
    _appStateViewModel.dispose();
    _module.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppStateViewModel>.value(
      value: _appStateViewModel,
      child: const AfetAnalizApp(),
    );
  }
}
