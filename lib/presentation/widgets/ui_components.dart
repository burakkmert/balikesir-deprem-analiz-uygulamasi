import 'package:flutter/material.dart';

import '../../core/theme.dart';

import 'package:latlong2/latlong.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const ScreenHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.displayLarge
              ?.copyWith(fontSize: 24),
        ),
        const SizedBox(height: AppTokens.s4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class LocationContextCard extends StatelessWidget {
  final String? selectedMahalle;
  final String? selectedIlce;
  final dynamic selectedPoint; // LatLng or GeoPoint
  final IconData? overrideIcon;
  final Color? overrideIconColor;

  const LocationContextCard({
    super.key,
    required this.selectedMahalle,
    required this.selectedIlce,
    required this.selectedPoint,
    this.overrideIcon,
    this.overrideIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final String locationTitle;
    final String locationSubtitle;
    final String tag;

    if (selectedMahalle != null) {
      locationTitle = selectedMahalle!;
      locationSubtitle = '$selectedIlce İlçesi / BALIKESİR';
      tag = 'Mahalle';
    } else if (selectedIlce != null) {
      locationTitle = '$selectedIlce İlçesi';
      locationSubtitle = 'BALIKESİR';
      tag = 'İlçe Genel';
    } else if (selectedPoint != null) {
      locationTitle = 'Haritadan Seçilen Nokta';
      if (selectedPoint is LatLng) {
        locationSubtitle =
            '${selectedPoint.latitude.toStringAsFixed(4)}, ${selectedPoint.longitude.toStringAsFixed(4)}';
      } else {
        locationSubtitle =
            '${selectedPoint.latitude.toStringAsFixed(4)}, ${selectedPoint.longitude.toStringAsFixed(4)}';
      }
      tag = 'Koordinat';
    } else {
      locationTitle = 'Balıkesir Genel';
      locationSubtitle = 'Konum seçilmedi';
      tag = 'Bölge';
    }

    final Color iconColor = overrideIconColor ?? AppColors.safeEmeraldAccent;
    final Color bgColor = iconColor.withAlpha(50);
    final IconData icon = overrideIcon ?? Icons.location_on_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppTokens.r16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppTokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontSize: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  locationSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (selectedPoint != null ||
              selectedIlce != null ||
              selectedMahalle != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s8,
                vertical: AppTokens.s4,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(AppTokens.r8),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final VoidCallback? onAction;
  final String? actionLabel;
  final IconData? actionIcon;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor = AppColors.safeEmeraldAccent,
    this.onAction,
    this.actionLabel,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s20,
        vertical: AppTokens.s32,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppTokens.r16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.s16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withAlpha(80)),
            ),
            child: Icon(icon, size: 40, color: iconColor),
          ),
          const SizedBox(height: AppTokens.s16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 17),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: AppTokens.s20),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.search_rounded, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.safeEmerald,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor ?? AppColors.textMuted),
        const SizedBox(width: AppTokens.s8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;

  const SectionLabel({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 18),
        const SizedBox(width: AppTokens.s8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class StandardPageLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? headerAction; // like the search bar

  const StandardPageLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16,
          vertical: AppTokens.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(title: title, subtitle: subtitle),
            if (headerAction != null) ...[
              const SizedBox(height: AppTokens.s16),
              headerAction!,
            ],
            const SizedBox(height: AppTokens.s20),
            child,
          ],
        ),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;

  const ActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.safeEmerald,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.r12),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18, color: AppColors.safeEmeraldAccent),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.cardDark,
                side: const BorderSide(color: AppColors.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.r12),
                ),
              ),
            ),
    );
  }
}
