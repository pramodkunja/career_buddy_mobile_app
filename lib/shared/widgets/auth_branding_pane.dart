import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// `.auth-banner-left` (`static/css/style.css:2059-2118`) — the blue-
/// gradient branding pane shared by both the student (`templates/users/
/// login.html:7-23`) and employer (`templates/employer_login/login.html:
/// 17-32`) sign-in pages on the updated website. Both templates use the
/// exact same markup shell (brand mark + "Career**Buddy**" wordmark +
/// "Since 2026" tagline + an `<h2>` + a paragraph + a 4-item check-list) —
/// only the heading text, paragraph, and feature list differ per screen.
/// Extracted here (Phase 68, fixing `UI-A-006`) so both screens share one
/// implementation instead of drifting independently, matching the two
/// real templates' own shared-markup relationship.
///
/// Colors/gradient/radius/spacing are the literal values from
/// `style.css`'s `.auth-*` block — this pane is genuinely blue (`#185adb`
/// → `#1d4ed8`) on the real site regardless of the app's generic navy
/// theme, confirmed by reading the cascade to the end of the file.
class AuthBrandingPane extends StatelessWidget {
  const AuthBrandingPane({
    required this.compact,
    required this.heading,
    required this.subtitle,
    required this.features,
    super.key,
  });

  /// `true` below the web's own 860px stacking breakpoint
  /// (`style.css:2197-2210`) — same padding reduction the web applies
  /// there (`3.5rem 3rem` → `2.5rem 2rem`).
  final bool compact;

  final String heading;
  final String subtitle;
  final List<String> features;

  static const _blue = Color(0xFF185ADB);
  static const _blueDark = Color(0xFF1D4ED8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: compact
          ? const EdgeInsets.fromLTRB(32, 40, 32, 40)
          : const EdgeInsets.fromLTRB(48, 56, 48, 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_blue, _blueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // `templates/users/login.html:10`/`employer_login/login.html:19`
              // — both templates render the exact same real asset
              // (`{% static 'img/logo-mark-light.png' %}`), the bare gold
              // mark with no background, for this dark/navy surface —
              // matching `pubspec.yaml`'s own documented asset choice.
              Image.asset(
                'assets/images/logo-mark-light.png',
                width: 30,
                height: 30,
              ),
              const SizedBox(width: 10),
              // `.auth-banner-brand .brand-copy` (`style.css:2852-2892`):
              // "Career" in the surrounding (white) color, "Buddy" in the
              // brand gold, with a small letter-spaced "SINCE 2026"
              // tagline beneath — the decorative divider lines either side
              // of the tagline on the real page are a desktop flourish,
              // left out here as a reasonable mobile simplification, not a
              // content omission.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          height: 1.08,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Career',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'Buddy',
                            style: TextStyle(color: AppColors.accent),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'SINCE 2026',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            heading,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF34D399),
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      feature,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
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
