import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';

/// Same visual/interaction pattern as `ActivityDetailScreen`'s private
/// `_LockedState` (that class can't be imported from here, being
/// file-private) — shown defensively if a `ForbiddenFailure` is ever
/// returned by a JAM call. See `ApiEndpoints`'s JAM doc comment for why
/// this is a defensive fallback rather than something the real
/// `jam_session`/`save_audio`/etc. endpoints are confirmed to return today
/// — the actual gate (`_can_access_workshop`) only exists on
/// `jam:home`/`jam:dashboard`, neither called by this client; access is
/// effectively already gated one layer up, wherever a human wires this
/// feature's entry point from `ActivityDetailScreen` (which itself shows
/// its own `_LockedState` before this screen would ever be reached).
class JamLockedView extends StatelessWidget {
  const JamLockedView({required this.message, super.key});

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
