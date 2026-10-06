import 'package:flutter/material.dart';

/// `.module-hero` — the AI-module header shared by Speaking/Writing/
/// Listening/Reading (each module's own inline `<style>` block, e.g.
/// `templates/activities/modules/speaking.html:26-52`). Structurally
/// distinct from [ExerciseHero]: a pill badge, an `<h1>`/`<p>` title+
/// subtitle pair, and the breadcrumb sits *below* them — reproduced as its
/// own component per that real markup difference, not shared with
/// [ExerciseHero].
///
/// Every value below is fixed per module (the gradient, badge icon/text,
/// and breadcrumb link color are hardcoded in each module's own template —
/// never derived from `Activity.color_class`, unlike [ExerciseHero]), so
/// this widget takes them all as plain parameters rather than looking
/// anything up itself; each of the 4 AI screens supplies its own.
class ModuleHero extends StatelessWidget {
  const ModuleHero({
    required this.gradientStart,
    required this.gradientEnd,
    required this.badgeIcon,
    required this.badgeLabel,
    required this.activityTitle,
    required this.breadcrumbLinkColor,
    this.activityObjective,
    super.key,
  });

  final Color gradientStart;
  final Color gradientEnd;

  /// `.module-badge`'s icon, e.g. `fa-microphone` for Speaking
  /// (`speaking.html:312`).
  final IconData badgeIcon;

  /// `.module-badge`'s text, e.g. "Speaking Module".
  final String badgeLabel;

  /// `{{ activity.title }}` — the `<h1>`.
  final String activityTitle;

  /// `{{ activity.objective }}` — the `<p>` subtitle. `null` when
  /// unavailable (no existing Flutter data flow currently carries the
  /// parent Activity's `objective` down to this screen — see the module
  /// screens' own doc comments) — hidden entirely rather than showing a
  /// placeholder, matching the "don't fabricate" rule.
  final String? activityObjective;

  /// The breadcrumb's non-active link color — verified per module by
  /// reading the actual class each one applies (`text-info` for Speaking,
  /// resolving to Bootstrap's default `#0dcaf0`; `text-green-200`/
  /// `text-cyan-200`/`text-yellow-100` for Writing/Listening/Reading,
  /// which have **no matching CSS rule anywhere in the project** —
  /// confirmed by grep — so those three actually render Bootstrap's
  /// default link blue, `#0d6efd`, not a module-tinted color. A genuine
  /// web quirk, reproduced rather than "fixed".
  final Color breadcrumbLinkColor;

  static const _breadcrumbActive = Colors.white;
  static const _breadcrumbSeparator = Color(0x66FFFFFF); // rgba(255,255,255,.4), Bootstrap default divider look

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      // `.module-hero{padding:2.5rem 0 3rem}` = 40px/48px — reproduced as
      // this widget's own padding since there's no second desktop navbar
      // to additionally clear.
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [gradientStart, gradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `.module-badge` (`speaking.html:43-52`): pill, translucent
          // white bg/border.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF), // rgba(255,255,255,.15)
              border: Border.all(color: const Color(0x4DFFFFFF)), // rgba(255,255,255,.3)
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(badgeLabel, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 13),
          // `.module-hero h1{font-size:1.9rem;font-weight:800}`.
          Text(
            activityTitle,
            style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          if (activityObjective != null) ...[
            const SizedBox(height: 6),
            // `.module-hero p{opacity:.85}`.
            Text(activityObjective!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xD9FFFFFF))),
          ],
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Activities', style: theme.textTheme.bodySmall?.copyWith(color: breadcrumbLinkColor, fontSize: 13)),
              const Text(' / ', style: TextStyle(color: _breadcrumbSeparator, fontSize: 13)),
              // `Wrap` only accepts plain children, not `Flex`-only widgets
              // like `Flexible`/`Expanded` — a long title just wraps onto
              // its own line within the `Wrap` instead.
              Text(activityTitle, style: theme.textTheme.bodySmall?.copyWith(color: breadcrumbLinkColor, fontSize: 13)),
              const Text(' / ', style: TextStyle(color: _breadcrumbSeparator, fontSize: 13)),
              const Text('Practice', style: TextStyle(color: _breadcrumbActive, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
