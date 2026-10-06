import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';

/// Shown when `GD_app:create_session` redirects to `/activities/?locked=1`
/// because `_can_access_workshop(user, 'gd')` denied access — unlike
/// Roleplay/JAM, this is the one real, confirmed, enforced plan gate on
/// this feature's actual client-called endpoint (re-verified directly
/// against `GD_app/views.py`), not a defensive fallback. Same visual
/// pattern as `RoleplayLockedView`/`JamLockedView`/`ActivityDetailScreen`'s
/// own private `_LockedState`.
class GdLockedView extends StatelessWidget {
  const GdLockedView({required this.message, super.key});

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
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Back to Activities',
              variant: AppButtonVariant.text,
              fullWidth: false,
              onPressed: () => context.go(RoutePaths.activities),
            ),
          ],
        ),
      ),
    );
  }
}
