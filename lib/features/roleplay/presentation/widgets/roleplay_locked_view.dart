import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';

/// Same visual/interaction pattern as `ActivityDetailScreen`'s private
/// `_LockedState` (that class can't be imported from here, being
/// file-private) — see that file's own doc comment for the reasoning.
/// Shown when `roleplay_practice` (`POST /roleplay/practice/`) returns 403
/// because `_can_access_workshop(user, 'roleplay')` denied access — the one
/// real, confirmed plan gate on this feature (`analyze_roleplay` itself has
/// no such check — see `ApiEndpoints.analyzeRoleplay`'s doc comment).
class RoleplayLockedView extends StatelessWidget {
  const RoleplayLockedView({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'View Plans',
              icon: Icons.workspace_premium_outlined,
              fullWidth: false,
              onPressed: () => context.push(RoutePaths.pro),
            ),
          ],
        ),
      ),
    );
  }
}
