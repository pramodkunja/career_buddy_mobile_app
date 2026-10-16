import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

class PortalHighlight {
  const PortalHighlight({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

/// `#job-seeker` / `#employer` — the updated web's real "story" sections
/// (`templates/landing.html:6839-6945`).
///
/// Phase 37 — a full rebuild, replacing the previous version of this
/// widget, which (per its own prior doc comment) reproduced the OLD,
/// already-removed `templates/home.html:305-513` full-bleed photo-card
/// design, including stat-number bubbles with no equivalent anywhere on
/// the current site. The current web's own section is a two-column
/// "story" layout (`.story`, `landing.html:814-articles`): an eyebrow,
/// headline, body paragraph and 4-item checklist on one side, and a
/// content panel (not a photo) on the other — 3 small real-content
/// "mini-cards" plus a purely decorative stacked-avatar row
/// (`aria-hidden="true"` on the web itself, confirmed directly — not an
/// informational element, so reproduced here as plain colored circles
/// rather than invented illustration art).
///
/// The web's own panel is a solid-color card (`.story-visual`, navy for
/// job-seeker / light tint for employer) — not a photo background — so no
/// image asset is used or needed here, unlike the old design this replaces.
class PortalCard extends StatelessWidget {
  const PortalCard({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.checklist,
    required this.ctaLabel,
    required this.onCta,
    required this.ctaFallbackColor,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.highlights,
    required this.caption,
    required this.avatarColors,
    required this.isDarkVisual,
    this.ctaGradient,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<String> checklist;
  final String ctaLabel;
  final VoidCallback onCta;
  final Gradient? ctaGradient;
  final Color ctaFallbackColor;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final List<PortalHighlight> highlights;
  final String caption;
  final List<Color> avatarColors;
  final bool isDarkVisual;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `.eyebrow` (base, unaffected by the hero-only vibrant override).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.action.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(
            eyebrow,
            style: const TextStyle(
              color: AppColors.action,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          description,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final item in checklist)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ctaGradient != null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: ctaGradient,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onCta,
                    icon: const Icon(Icons.arrow_forward, size: 17),
                    label: Text(ctaLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      shape: const StadiumBorder(),
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: onCta,
                  icon: const Icon(Icons.arrow_forward, size: 17),
                  label: Text(ctaLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ctaFallbackColor,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    shape: const StadiumBorder(),
                  ),
                ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onSecondary,
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: Text(secondaryLabel),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // `.story-visual` — a solid-color content panel, not a photo.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isDarkVisual ? AppColors.primary : AppColors.background,
            borderRadius: AppRadius.lgRadius,
            border: isDarkVisual ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // `.avs` — purely decorative on the web itself
              // (`aria-hidden="true"`), so a plain colored-circle stack
              // stands in for the illustrated avatars.
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 32,
                    child: Stack(
                      children: [
                        for (var i = 0; i < avatarColors.length; i++)
                          Positioned(
                            left: i * 16.0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: avatarColors[i],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      caption,
                      style: TextStyle(
                        color: isDarkVisual
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final highlight in highlights)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _MiniHighlightCard(
                    highlight: highlight,
                    isDarkVisual: isDarkVisual,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniHighlightCard extends StatelessWidget {
  const _MiniHighlightCard({
    required this.highlight,
    required this.isDarkVisual,
  });

  final PortalHighlight highlight;
  final bool isDarkVisual;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkVisual
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(
          color: isDarkVisual
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            highlight.icon,
            size: 18,
            color: isDarkVisual ? Colors.white : AppColors.action,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  highlight.title,
                  style: TextStyle(
                    color: isDarkVisual ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  highlight.description,
                  style: TextStyle(
                    color: isDarkVisual
                        ? const Color(0xD9FFFFFF)
                        : AppColors.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
