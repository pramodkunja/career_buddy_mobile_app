import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

/// One `.feature-card` entry — shared by both `#features` (Platform
/// Overview) and `#buddy` (Meet Buddy), which use the exact same markup
/// class on the real web. [iconBackground]/[iconColor] are the literal
/// inline-style hex values from `templates/landing.html` (e.g.
/// `background:#fde3e3;color:#dc4848`), not approximated.
class HomeFeatureCardData {
  const HomeFeatureCardData({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String description;

  /// Null for Meet Buddy's cards — the real web's `.feature-card` only
  /// carries a link inside `#features`; `#buddy`'s cards are plain
  /// (informational), with the one "Ask Buddy" action below the whole grid
  /// instead (see `HomeMeetBuddySection`).
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// `.feature-grid` — a single-column stack of [HomeFeatureCardData] cards
/// (the real web's multi-column grid collapses to one column well before
/// any width this app targets).
class HomeFeatureGrid extends StatelessWidget {
  const HomeFeatureGrid({required this.cards, super.key});

  final List<HomeFeatureCardData> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final card in cards)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _FeatureCard(data: card),
          ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.data});

  final HomeFeatureCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: data.iconBackground,
              borderRadius: AppRadius.mdRadius,
            ),
            child: Icon(data.icon, color: data.iconColor, size: 24),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            data.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            data.description,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          if (data.actionLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: data.onAction,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      data.actionLabel!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.action,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: AppColors.action,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
