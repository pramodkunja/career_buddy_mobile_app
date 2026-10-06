import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';

class _QuickStartLink {
  const _QuickStartLink(this.label, this.category, this.icon);
  final String label;
  final String category;
  final IconData icon;
}

/// Mirrors the web dashboard's "Quick Start" sidebar card
/// (`dashboard.html:276-306`) exactly — the same 7 fixed category links, in
/// the same order, each opening the Activities list pre-filtered to that
/// category (`?category=...`). These category values are the exact
/// `Activity.CATEGORY_CHOICES` keys (`activities/models.py`), not invented.
class QuickStartSection extends StatelessWidget {
  const QuickStartSection({super.key});

  static const _links = [
    _QuickStartLink('Speaking', 'speaking', Icons.mic_none_outlined),
    _QuickStartLink('Writing', 'writing', Icons.edit_outlined),
    _QuickStartLink('Vocabulary', 'vocabulary', Icons.extension_outlined),
    _QuickStartLink('Negotiation', 'negotiation', Icons.handshake_outlined),
    _QuickStartLink('Communication', 'communication', Icons.public_outlined),
    _QuickStartLink('Analysis', 'analysis', Icons.pie_chart_outline),
    _QuickStartLink('Workshop', 'workshop', Icons.groups_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Start', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          // `.quick-links{display:grid;grid-template-columns:1fr 1fr;
          // gap:.75rem}` (`static/css/style.css:1468-1472`) — a fixed
          // 2-column grid, not a wrap of variable-width chips.
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.4,
            children: [for (final link in _links) _QuickStartTile(link: link)],
          ),
        ),
      ],
    );
  }
}

/// `.quick-link-item` (`static/css/style.css:1474-1492`): a solid
/// `#E5E5E5`-filled, radius-8 tile (icon above label, both centered), icon
/// colored navy (`var(--primary)`, post-rebrand) — not an outlined pill
/// with a blue icon.
class _QuickStartTile extends StatelessWidget {
  const _QuickStartTile({required this.link});

  final _QuickStartLink link;

  static const _fill = Color(0xFFE5E5E5);
  static const _text = Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(RoutePaths.activitiesWithCategory(link.category)),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(color: _fill, borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(link.icon, size: 19, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              link.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _text, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
