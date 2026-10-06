import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/sub_activity_summary.dart';
import '../../domain/entities/sub_activity_status.dart';

/// Mobile equivalent of the web's "Activity Progress" sidebar
/// (`templates/activities/sub_activity.html:210-224`) — every sub-activity
/// of the current activity, with the current one highlighted, as a
/// collapsed-by-default expandable list rather than a permanent sidebar
/// column (there's no room for a persistent sidebar on a phone width, but
/// the same destinations/information are preserved, just one tap away).
class SubActivityNavList extends StatelessWidget {
  const SubActivityNavList({required this.siblings, required this.currentId, required this.onSelect, super.key});

  final List<SubActivitySummary> siblings;
  final int currentId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (siblings.isEmpty) return const SizedBox.shrink();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            title: Row(
              children: [
                const Icon(Icons.map_outlined, size: 18, color: AppColors.action),
                const SizedBox(width: AppSpacing.xs),
                Text('Activity Progress', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            children: [
              for (final sibling in siblings)
                _SubNavItem(sibling: sibling, isActive: sibling.id == currentId, onTap: () => onSelect(sibling.id)),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubNavItem extends StatelessWidget {
  const _SubNavItem({required this.sibling, required this.isActive, required this.onTap});

  final SubActivitySummary sibling;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isActive ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
          color: isActive ? AppColors.action.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${sibling.order}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isActive ? AppColors.action : AppColors.textMuted,
                  fontWeight: isActive ? FontWeight.bold : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                sibling.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isActive ? AppColors.action : null,
                  fontWeight: isActive ? FontWeight.bold : null,
                ),
              ),
            ),
            if (sibling.status == SubActivityStatus.completed)
              const Icon(Icons.check_circle, size: 16, color: AppColors.success),
          ],
        ),
      ),
    );
  }
}
