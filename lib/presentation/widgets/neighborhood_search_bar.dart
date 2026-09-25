import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/app_utils.dart';
import '../viewmodels/app_state_viewmodel.dart';

class NeighborhoodSearchBar extends StatefulWidget {
  const NeighborhoodSearchBar({super.key});

  @override
  State<NeighborhoodSearchBar> createState() => _NeighborhoodSearchBarState();
}

class _NeighborhoodSearchBarState extends State<NeighborhoodSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isOverlayOpen = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateViewModel>();
    final allIlceler = state.ilceler;

    final List<Map<String, String>> searchResults = [];
    if (_query.trim().isNotEmpty) {
      final q = AppUtils.normalizeTurkish(_query);
      for (final demo in state.demografiList) {
        final nufus = demo.mahalleNufus;
        if (AppUtils.normalizeTurkish(nufus.mahalleAd).contains(q) ||
            AppUtils.normalizeTurkish(nufus.ilceAd).contains(q)) {
          searchResults.add({
            'ilce': nufus.ilceAd,
            'mahalle': nufus.mahalleAd,
            'mahalleKodu': nufus.mahalleKodu,
          });
          if (searchResults.length >= 25) break;
        }
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withAlpha(235),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(120),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(
                Icons.search_rounded,
                color: AppColors.safeEmeraldAccent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: state.selectedMahalle != null
                        ? '${state.selectedIlce} / ${state.selectedMahalle}'
                        : 'Balıkesir mahalle veya ilce ara...',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _query = val;
                      _isOverlayOpen = val.isNotEmpty;
                    });
                  },
                  onTap: () {
                    if (_searchController.text.isNotEmpty) {
                      setState(() => _isOverlayOpen = true);
                    }
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _isOverlayOpen = false;
                    });
                  },
                )
              else
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  color: AppColors.surfaceDark,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  tooltip: 'İlce Hızlı Seçim',
                  onSelected: (ilce) {
                    state.selectIlce(ilce);
                    _searchController.clear();
                  },
                  itemBuilder: (context) {
                    return allIlceler.map((ilce) {
                      final isSelected = ilce == state.selectedIlce;
                      return PopupMenuItem<String>(
                        value: ilce,
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 16,
                              color: isSelected
                                  ? AppColors.safeEmeraldAccent
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              ilce,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        if (_isOverlayOpen && searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withAlpha(245),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(160),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              itemCount: searchResults.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppColors.dividerColor),
              itemBuilder: (context, index) {
                final item = searchResults[index];
                final ilce = item['ilce']!;
                final mahalle = item['mahalle']!;

                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.safeEmeraldAccent,
                  ),
                  title: Text(
                    mahalle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '$ilce İlcesi',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    state.selectIlceAndMahalle(
                      ilce,
                      mahalle,
                      mahalleKodu: item['mahalleKodu'],
                    );
                    _focusNode.unfocus();
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _isOverlayOpen = false;
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
