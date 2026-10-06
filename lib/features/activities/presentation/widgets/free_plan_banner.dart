import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/activity_summary.dart';

/// Mirrors the web list page's Free-Plan alert banner
/// (`templates/activities/list.html:52-84`). [claimedActivity] is the
/// single Free-Plan activity the user has already opened, derived the same
/// way the web does — a Free-Plan user can access exactly one of the 4
/// Free-Plan activities, so `is_locked` on the other 3 flips to `true` the
/// moment one is claimed (`activities/views.py:_can_access_activity`).
/// `null` means no activity has been claimed yet (every card still
/// unlocked). Not read from a dedicated API field — the existing
/// `activity_list_api` response never exposes "which one was claimed"
/// directly (see `docs/BACKEND_CONTRACT_activities.md`), but it's fully
/// derivable from the `is_locked` flags already in the response.
class FreePlanBanner extends StatelessWidget {
  const FreePlanBanner({required this.claimedActivity, required this.totalActivities, super.key});

  final ActivitySummary? claimedActivity;
  final int totalActivities;

  @override
  Widget build(BuildContext context) {
    final claimed = claimedActivity;
    final message = claimed != null
        ? 'You have used your one free activity on "${claimed.title}" — the other 3 are now locked. '
              'Upgrade to Normal User (₹499/yr) or Pro User (₹999/yr) to unlock all $totalActivities activities!'
        : 'You are on the Free Plan — pick any one of the 4 activities below to start free. Once you '
              'open it, the remaining 3 will be locked. Upgrade to Normal User (₹499/yr) or Pro User '
              '(₹999/yr) to unlock all $totalActivities activities!';

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.card_giftcard, color: AppColors.accentDark),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Free Trial Preview Active', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Upgrade Plan',
                  icon: Icons.workspace_premium_outlined,
                  fullWidth: false,
                  onPressed: () => context.push(RoutePaths.pro),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
