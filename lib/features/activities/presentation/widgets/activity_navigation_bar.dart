import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/adjacent_activities.dart';

/// Mirrors the web activity-detail page's Previous/Next controls
/// (`templates/activities/detail.html:152-164`) — either side is simply
/// omitted when there's no neighbor (first/last activity), matching the
/// web exactly (an empty `<span>` in place of a missing "previous").
class ActivityNavigationBar extends StatelessWidget {
  const ActivityNavigationBar({required this.adjacent, required this.onSelect, super.key});

  final AdjacentActivities adjacent;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final previous = adjacent.previous;
    final next = adjacent.next;
    if (previous == null && next == null) return const SizedBox.shrink();

    return Row(
      children: [
        if (previous != null)
          Expanded(
            child: OutlinedButton(
              onPressed: () => onSelect(previous.id),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_back, size: 18),
                  const SizedBox(width: 8),
                  Flexible(child: Text(_truncate(previous.title), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        if (previous != null && next != null) const SizedBox(width: AppSpacing.sm),
        if (next != null)
          Expanded(
            child: OutlinedButton(
              onPressed: () => onSelect(next.id),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text(_truncate(next.title), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Matches the web's `|truncatechars:25` on both titles.
  static String _truncate(String title) => title.length <= 25 ? title : '${title.substring(0, 24)}…';
}
