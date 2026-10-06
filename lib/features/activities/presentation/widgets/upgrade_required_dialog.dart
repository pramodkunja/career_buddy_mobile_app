import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';

/// Mirrors the web list page's "Upgrade Required" pop-up
/// (`templates/activities/list.html:168-193`) — shown when a Free-Plan
/// user taps a locked activity card (their one free slot is already used
/// on a different activity), instead of navigating anywhere.
Future<void> showUpgradeRequiredDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(child: Text('Upgrade Required')),
        ],
      ),
      content: const Text(
        'You have already used your one free activity. Upgrade your plan to '
        'unlock and access all 3 remaining activities.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            context.push(RoutePaths.pro);
          },
          icon: const Icon(Icons.workspace_premium_outlined),
          label: const Text('View Plans'),
        ),
      ],
    ),
  );
}
