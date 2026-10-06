import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

class PortalCardStat {
  const PortalCardStat({required this.number, required this.label});

  final String number;
  final String label;
}

class PortalCardAction {
  const PortalCardAction({required this.label, required this.onTap, this.icon, this.isPrimary = false});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// `.btn-candidate-reg`/`.btn-employer-reg` (solid orange, `#ff9800`) vs
  /// `.btn-candidate-login`/`.btn-employer-login` (translucent white
  /// outline) — `home.html:432-476`.
  final bool isPrimary;
}

/// `.portal-card` (`templates/home.html:305-513`) — the two guest-only
/// hero cards on `/` ("for job seekers" / "for clients"), each a
/// full-bleed background photo (`assetImage`) under the same 3-stop navy
/// scrim (`linear-gradient(180deg, rgba(15,23,42,.1) 0%, rgba(15,23,42,.4)
/// 40%, rgba(15,23,42,.92) 100%)`, `home.html:335-339`), a pill badge top
/// left, and a bottom content block (title/description/actions/stat
/// bubbles).
class PortalCard extends StatelessWidget {
  const PortalCard({
    required this.assetImage,
    required this.badgeIcon,
    required this.badgeLabel,
    required this.title,
    required this.description,
    required this.actions,
    required this.stats,
    super.key,
  });

  final String assetImage;
  final IconData badgeIcon;
  final String badgeLabel;
  final String title;
  final String description;
  final List<PortalCardAction> actions;
  final List<PortalCardStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      // `.portal-card{min-height:440px}` (`home.html:315`) exists so both
      // cards in the web's side-by-side row match height. Stacked
      // vertically in a scrolling column here instead (see `PublicHomeBody`),
      // there's no sibling to match, and a `min-height` inside an
      // unbounded-height scroll parent leaves `Stack`'s `StackFit.expand`
      // children (the background `Image.asset`) unbounded too — a fixed
      // height is required, not just an adaptation choice.
      height: 400,
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgRadius,
        boxShadow: const [BoxShadow(color: Color(0x260F172A), blurRadius: 30, offset: Offset(0, 12))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(assetImage, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x1A0F172A), Color(0x660F172A), Color(0xEB0F172A)],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // `.portal-card-badge-label` — translucent blue pill.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x4D185ADB),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 12, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        badgeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // `.portal-card-main-title` — lowercase per the web's own
                // `text-transform: lowercase` (`home.html:390`).
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _PortalActionButton(action: actions[i])),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.xs),
                      Expanded(child: _StatBubble(stat: stats[i])),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalActionButton extends StatelessWidget {
  const _PortalActionButton({required this.action});

  final PortalCardAction action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: action.onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: action.isPrimary ? const Color(0xFFFF9800) : const Color(0x29FFFFFF),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
            side: action.isPrimary ? BorderSide.none : const BorderSide(color: Color(0x40FFFFFF)),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action.icon != null) ...[Icon(action.icon, size: 13), const SizedBox(width: 5)],
            Flexible(child: Text(action.label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  const _StatBubble({required this.stat});

  final PortalCardStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stat.number,
            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 1),
          Text(
            stat.label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 9, letterSpacing: 0.3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
