import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';

/// `.portal-hero-card`/`.portal-hero-overlay`/`.portal-hero-label`
/// (`static/css/style.css:2414-2468`) — the two authenticated-home image
/// cards ("Learn Business English" / "Apply for Your Dream Job"), each a
/// full-bleed photo with a bottom-weighted navy scrim and a single pill
/// label anchored to the bottom-left corner.
///
/// Web height is a fixed `380px`, dropping to `260px` at the `≤768px`
/// breakpoint (`style.css:2464-2468`). Every width this app targets is
/// narrower than that breakpoint, so `220px` is used here — a further,
/// proportional step down the web's own responsive curve, not an invented
/// value.
class PortalHeroCard extends StatelessWidget {
  const PortalHeroCard({required this.assetImage, required this.icon, required this.label, super.key});

  final String assetImage;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgRadius,
        boxShadow: const [BoxShadow(color: Color(0x2E185ADB), blurRadius: 30, offset: Offset(0, 10))],
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
                colors: [Color(0x0D0F172A), Color(0x8C0F172A)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xEBFFFFFF),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 16)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: const Color(0xFF185ADB)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
