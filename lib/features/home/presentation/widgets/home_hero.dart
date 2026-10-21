import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

/// The updated web's unified hero (`templates/landing.html:6536-6588`).
///
/// Phase 37 — rebuilt from the *actual current* source after tracing its
/// full CSS cascade, not just its markup. `landing.html` defines its own
/// local `:root` (lines 22-36, a light content palette) which a later,
/// still-active "VIBRANT THEME LAYER" block (same `<style>` tag, ~line
/// 1299 onward) overrides again for `.hero`, `.hero h1`, `.eyebrow`, and
/// `.btn-primary` — this is the final, currently-rendered state, confirmed
/// by checking there is no further override after it. That same layer also
/// sets `.hero .hero-visual{visibility:hidden}` unconditionally, and
/// `display:none` at `≤960px` — every width this app targets is well
/// inside that breakpoint, so the hero's photo illustration and its 3
/// floating quote chips are **not shown on the real site at any mobile
/// width either**; they are deliberately not reproduced here. (An earlier,
/// shallower read of just the HTML markup — without tracing this override —
/// had assumed they would need reproducing; tracing the full cascade
/// corrects that.)
///
/// Landing-page parity phase: the 2 guest-only "I'm a Job Seeker"/"I'm an
/// Employer" role pills (`landing.html:6556-6563`, `{% if not user.is_
/// authenticated %}`-gated) are now reproduced via [onJobSeeker]/
/// [onEmployer] — both nullable so this widget stays shared, unchanged,
/// between the guest and authenticated-student views (`PublicHomeBody`
/// passes them, `AuthenticatedHomeBody` leaves them `null` and the pills
/// simply don't render), matching the real web's own `{% if %}` exactly
/// rather than adding an auth lookup inside this widget. Confirmed directly:
/// both pills link to the exact same destinations as "Get Started Free"
/// (`/users/register/`) and "Create Resume"'s neighboring employer
/// equivalent (`/employer/accounts/employer/register/`) — i.e. the same
/// [onJobSeeker]≈`onRegister`/[onEmployer]≈`onEmployerRegister` callbacks
/// `PublicHomeBody` already has, not new destinations.
class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.onGetStarted,
    required this.onFindJobs,
    required this.onCreateResume,
    this.onJobSeeker,
    this.onEmployer,
    super.key,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onFindJobs;
  final VoidCallback onCreateResume;
  final VoidCallback? onJobSeeker;
  final VoidCallback? onEmployer;

  /// `--grad` (`linear-gradient(135deg, #185adb 0%, #7c3aed 60%, #db2777
  /// 100%)`) — the vibrant layer's final `.btn-primary` background.
  static const _ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF185ADB), Color(0xFF7C3AED), Color(0xFFDB2777)],
  );

  /// `.hero h1` (`background: linear-gradient(120deg, #14213d 10%, #3730a3
  /// 55%, #9d174d 100%); background-clip: text`).
  static const _headlineGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF14213D), Color(0xFF3730A3), Color(0xFF9D174D)],
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.lgRadius,
      child: Stack(
        children: [
          // `.hero` background: a light linear base
          // (`linear-gradient(180deg,#eef2ff 0%,#fdf2f8 100%)`) plus 3 soft
          // radial accents (violet top-right, blue top-left, amber bottom)
          // — the vibrant layer's actual current `.hero` rule.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEEF2FF), Color(0xFFFDF2F8)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, -0.8),
                  radius: 1.1,
                  colors: [
                    const Color(0xFFA855F7).withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.9, -0.6),
                  radius: 1.0,
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.26),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.2, 1.0),
                  radius: 1.0,
                  colors: [
                    const Color(0xFFFBBF24).withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // `.eyebrow` (vibrant-layer override): light blue-to-pink
                // tint background, purple (`#5b21b6`) text.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF185ADB).withValues(alpha: 0.12),
                        const Color(0xFFEC4899).withValues(alpha: 0.14),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 13,
                        color: Color(0xFF5B21B6),
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'AI-powered career platform',
                          style: TextStyle(
                            color: Color(0xFF5B21B6),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // `.hero h1` — gradient-clipped text
                // (`background-clip:text`), reproduced with `ShaderMask`.
                ShaderMask(
                  shaderCallback: (bounds) =>
                      _headlineGradient.createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: const Text(
                    'Build skills. Craft capability. Claim your career.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'CareerBuddy brings professional learning, AI resume tools, interview practice and skill '
                  'certifications together — so you walk into every interview ready, and every hiring decision '
                  'easier.',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // `.hero-ctas .btn` — full-pill buttons (`border-radius:
                // 999px`), stacked full-width (the web's own horizontal row
                // never fits any width this app targets).
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: _ctaGradient,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: onGetStarted,
                      icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                      label: const Text('Get Started Free'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // `.btn-outline` — unchanged by the vibrant layer: a neutral
                // border and dark ink text.
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: onFindJobs,
                    icon: const Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                    label: const Text(
                      'Find Jobs',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.border,
                        width: 1.5,
                      ),
                      backgroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // `.btn-navy` — unchanged by the vibrant layer: solid navy.
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onCreateResume,
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Create Resume'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                if (onJobSeeker != null && onEmployer != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _RolePill(
                          icon: Icons.school_outlined,
                          label: "I'm a Job Seeker",
                          onTap: onJobSeeker!,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _RolePill(
                          icon: Icons.apartment_outlined,
                          label: "I'm an Employer",
                          onTap: onEmployer!,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.role-pill` (`landing.html:6556-6563`).
class _RolePill extends StatelessWidget {
  const _RolePill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: AppColors.textPrimary),
      label: Text(
        label,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        side: const BorderSide(color: AppColors.border),
        backgroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
    );
  }
}
