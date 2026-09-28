import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../viewmodels/app_state_viewmodel.dart';
import 'demografi_screen.dart';
import 'faylar_screen.dart';
import 'harita_screen.dart';
import 'nufus_screen.dart';
import 'toplanma_screen.dart';

class HomeScreen extends StatefulWidget {
  final TileProvider? tileProvider;
  const HomeScreen({super.key, this.tileProvider});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateViewModel>();

    if (state.isRegionalLoading && !state.isLoaded) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.safeEmeraldAccent.withAlpha(100),
                  ),
                ),
                child: const CircularProgressIndicator(
                  color: AppColors.safeEmeraldAccent,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Balıkesir Afet Analiz Sistemi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Demografi, Fay Hatları ve Toplanma Alanları Yükleniyor...',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: IndexedStack(
        index: state.currentTabIndex,
        children: [
          const NufusScreen(),
          const FaylarScreen(),
          const ToplanmaScreen(),
          const DemografiScreen(),
          HaritaScreen(tileProvider: widget.tileProvider),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: state.currentTabIndex,
            onTap: (index) {
              state.selectTab(index);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.surfaceDark,
            selectedItemColor: AppColors.safeEmeraldAccent,
            unselectedItemColor: AppColors.textMuted,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            iconSize: 22,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.people_alt_outlined),
                activeIcon: Icon(Icons.people_alt),
                label: 'Nüfus',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.warning_amber_rounded),
                activeIcon: Icon(Icons.warning_rounded),
                label: 'Faylar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined),
                activeIcon: Icon(Icons.shield),
                label: 'Toplanma',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.family_restroom_outlined),
                activeIcon: Icon(Icons.family_restroom),
                label: 'Demografi',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: 'Harita',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
