import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/sub_activity_summary.dart';

/// Mirrors the web sub-activity page's Previous/Next controls
/// (`templates/activities/sub_activity.html:188-207`). Unlike the
/// Activity-level nav bar (which simply omits a missing side), this one
/// **always** shows both buttons — at a boundary, Previous falls back to
/// "Back to Activity" and Next falls back to a distinctly-styled "Finish
/// Activity", both routing to the parent Activity Detail screen, exactly
/// matching the web's fallback `<a>` tags.
class SubActivityNavigationBar extends StatelessWidget {
  const SubActivityNavigationBar({
    required this.previous,
    required this.next,
    required this.onSelectSibling,
    required this.onBackToActivity,
    required this.onFinishActivity,
    super.key,
  });

  final SubActivitySummary? previous;
  final SubActivitySummary? next;
  final ValueChanged<int> onSelectSibling;
  final VoidCallback onBackToActivity;
  final VoidCallback onFinishActivity;

  // Matches the web's `|truncatechars:20` on both titles.
  static String _truncate(String title) => title.length <= 20 ? title : '${title.substring(0, 19)}…';

  @override
  Widget build(BuildContext context) {
    final previous = this.previous;
    final next = this.next;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: previous == null ? onBackToActivity : () => onSelectSibling(previous.id),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_back, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    previous == null ? 'Back to Activity' : _truncate(previous.title),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: next == null
              ? FilledButton(
                  onPressed: onFinishActivity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.flag_outlined, size: 18),
                      SizedBox(width: 8),
                      Flexible(child: Text('Finish Activity', overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                )
              : OutlinedButton(
                  onPressed: () => onSelectSibling(next.id),
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
}
