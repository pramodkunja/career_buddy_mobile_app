import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

/// `.trust-strip` (`templates/landing.html:6607-6605`), the 5-item band
/// directly under the hero. Background is the vibrant-layer's final
/// override (`linear-gradient(90deg, #1e3a8a, #5b21b6 50%, #be185d)`,
/// confirmed as the active rule — the earlier plain `var(--navy)` base rule
/// is overridden by it, same cascade pattern as [HomeHero]'s background).
/// Icon color is `var(--amber)` (`#f59e0b`, `landing.html`'s own local
/// root), text is plain white. Uses a [Wrap] rather than the web's `flex;
/// flex-wrap:wrap` row — same effect, idiomatic Flutter.
///
/// The web's own strip is full-bleed, edge to edge; this app already
/// renders the hero and cards above/below it as rounded, inset sections
/// (inside `PublicHomeBody`'s own padding) rather than true full-bleed —
/// rounded here too, for visual consistency with the rest of this screen,
/// rather than an abrupt switch to edge-to-edge for this one band alone.
class HomeTrustStrip extends StatelessWidget {
  const HomeTrustStrip({super.key});

  static const _items = [
    (Icons.school_outlined, 'Professional Learning'),
    (Icons.smart_toy_outlined, 'AI Career Assistance'),
    (Icons.description_outlined, 'Resume & Interview Prep'),
    (Icons.work_outline, 'Job Opportunities'),
    (Icons.workspace_premium_outlined, 'Certifications'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF5B21B6), Color(0xFFBE185D)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: AppRadius.lgRadius,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          for (final (icon, label) in _items)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: const Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
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
