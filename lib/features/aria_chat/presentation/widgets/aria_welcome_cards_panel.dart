import 'package:flutter/material.dart';

import '../../domain/entities/aria_welcome_card.dart';

/// `#riya-welcome-panel` (`templates/includes/aria_assistant.html`,
/// `static/css/riya_assistant.css`) — the real web's persistent
/// "predefined question" cards, re-read directly against the live,
/// deployed site (not the stale Django repo checkout — see
/// `aria_welcome_card.dart`'s doc comment for why). Sits between the
/// message transcript and the text input, "intentionally outside the
/// conversation stream so they remain visible after every user message"
/// (the real template's own comment, reproduced verbatim) — this app
/// renders it the same way, as a fixed panel below the scrollable message
/// list rather than as part of it.
///
/// Two 2-column grids — [group]'s `quickActions` then (if non-empty)
/// `recommendations`, with no heading between them (see
/// [AriaWelcomeCardGroup]'s doc comment for why: the real heading/"See
/// more" markup is dead CSS the real JS never applies). Internally
/// scrollable with a capped height, matching `.riya-welcome-panel`'s own
/// `max-height: 270px; overflow-y: auto` — this app's floating panel has
/// far less total height to share with the message list than the real
/// web's full-height widget, so a smaller cap (150) is used instead of a
/// literal pixel match, while preserving the same "its own scroll region,
/// independent of the transcript above it" behavior.
class AriaWelcomeCardsPanel extends StatelessWidget {
  const AriaWelcomeCardsPanel({required this.group, required this.language, required this.onCardTap, super.key});

  final AriaWelcomeCardGroup group;
  final String language;
  final void Function(AriaWelcomeCard card) onCardTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 150),
      child: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF2F7)))),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardGrid(cards: group.quickActions, language: language, startIndex: 0, onCardTap: onCardTap),
              if (group.recommendations.isNotEmpty) ...[
                const SizedBox(height: 10),
                _CardGrid(
                  cards: group.recommendations,
                  language: language,
                  startIndex: group.quickActions.length,
                  onCardTap: onCardTap,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `.riya-welcome-grid` — a 2-column grid of [_WelcomeCardTile]s. Icon
/// circle colors cycle blue/red/purple/green every 4 cards
/// (`.riya-welcome-card:nth-child(2n|3n|4n)`), counted across *both* grids
/// in a section (continuing from `startIndex`), matching the real CSS
/// selector, which counts every `.riya-welcome-card` sibling inside
/// `#riya-welcome-panel` regardless of which grid it's in.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.cards, required this.language, required this.startIndex, required this.onCardTap});

  final List<AriaWelcomeCard> cards;
  final String language;
  final int startIndex;
  final void Function(AriaWelcomeCard card) onCardTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // The real CSS's `min-height: 86px` is a floor, free to grow; this
        // grid's fixed extent isn't, so it needs enough headroom for a
        // worst-case 2-line title at this panel's narrowest supported
        // width — 86 itself clipped a 2-line title by exactly the 10px a
        // real device/test run then reported.
        mainAxisExtent: 100,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return _WelcomeCardTile(
          card: card,
          language: language,
          colorIndex: startIndex + index,
          onTap: () => onCardTap(card),
        );
      },
    );
  }
}

/// `.riya-welcome-card` — an icon circle, a bold title + chevron, and a
/// description, matching the real CSS's spacing/radius/colors exactly
/// (`border-radius: 16px`, icon circle `38px`, title `14px/700`,
/// description `11.5px` grey).
class _WelcomeCardTile extends StatelessWidget {
  const _WelcomeCardTile({required this.card, required this.language, required this.colorIndex, required this.onTap});

  final AriaWelcomeCard card;
  final String language;
  final int colorIndex;
  final VoidCallback onTap;

  static const _icons = <String, IconData>{
    'briefcase': Icons.work_outline,
    'user': Icons.person_outline,
    'users': Icons.groups_outlined,
    'resume': Icons.description_outlined,
    'cap': Icons.school_outlined,
    'interview': Icons.record_voice_over_outlined,
    'book': Icons.menu_book_outlined,
    'building': Icons.apartment_outlined,
    'sparkle': Icons.auto_awesome_outlined,
    'chart': Icons.bar_chart_outlined,
    'code': Icons.code_outlined,
  };

  // `.riya-welcome-card:nth-child(2n|3n|4n) .riya-welcome-card-icon` —
  // 1-indexed in CSS, so index 0 here (the 1st card) matches neither
  // selector and keeps the default blue.
  static const _ringColors = [Color(0xFFE8F0FF), Color(0xFFFFF0F0), Color(0xFFF1EAFF), Color(0xFFEAF8EF)];
  static const _iconColors = [Color(0xFF2563EB), Color(0xFFE25555), Color(0xFF7C3AED), Color(0xFF16A34A)];

  @override
  Widget build(BuildContext context) {
    // CSS applies `nth-child(2n)`, then `(3n)`, then `(4n)` in that source
    // order, each one overriding the last on a match (not mutually
    // exclusive) — e.g. the 12th card matches all three, so `(4n)`, being
    // last, wins (green). Reproduced here as sequential overrides, not an
    // if/else-if chain, for exactly that reason.
    final position = colorIndex + 1;
    var paletteIndex = 0;
    if (position % 2 == 0) paletteIndex = 1;
    if (position % 3 == 0) paletteIndex = 2;
    if (position % 4 == 0) paletteIndex = 3;
    final icon = _icons[card.icon] ?? Icons.arrow_forward_ios;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5EAF3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: _ringColors[paletteIndex], shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: _iconColors[paletteIndex]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            card.localizedTitle(language),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF17213A)),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
