import 'package:career_buddy_lms/features/aria_chat/domain/aria_welcome_catalog.g.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/aria_welcome_translations.g.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_welcome_card.dart';
import 'package:career_buddy_lms/features/aria_chat/presentation/aria_action_routes.dart';
import 'package:career_buddy_lms/features/aria_chat/presentation/aria_welcome_reply.dart';
import 'package:flutter_test/flutter_test.dart';

const _nonEnglish = ['hindi', 'vietnam', 'arabic', 'russian'];

List<AriaWelcomeCard> _allCards() {
  final cards = <AriaWelcomeCard>[];
  for (final group in kAriaWelcomeSectionContext.values) {
    cards.addAll(group.quickActions);
    cards.addAll(group.recommendations);
  }
  for (final group in kAriaWelcomeRoleContext.values) {
    cards.addAll(group.quickActions);
    cards.addAll(group.recommendations);
  }
  return cards;
}

void main() {
  group('aria welcome data integrity', () {
    test('every card id is unique', () {
      final cards = _allCards();
      final ids = cards.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate card id found');
    });

    test('every card\'s actionKey exists in kAriaActionCatalog', () {
      for (final card in _allCards()) {
        expect(
          kAriaActionCatalog.containsKey(card.actionKey),
          isTrue,
          reason: '${card.id} references unknown actionKey "${card.actionKey}"',
        );
      }
    });

    test('every card\'s actionKey route resolves to a real in-app screen for both portals', () {
      for (final card in _allCards()) {
        final route = kAriaActionCatalog[card.actionKey]!.route;
        final seekerRoute = ariaActionFlutterRoute(route, isEmployer: false);
        final employerRoute = ariaActionFlutterRoute(route, isEmployer: true);
        expect(
          seekerRoute != null || employerRoute != null,
          isTrue,
          reason: '${card.id}\'s actionKey "${card.actionKey}" (route "$route") has no Flutter screen mapped',
        );
      }
    });

    test('every card has full non-English context translation coverage', () {
      for (final card in _allCards()) {
        for (final lang in _nonEnglish) {
          final localized = card.localizedContext(lang);
          expect(localized, isNotEmpty, reason: '${card.id} missing a "$lang" context translation');
          expect(localized, isNot(card.context), reason: '${card.id} "$lang" context fell back to English');
        }
      }
    });

    test('a section card (present in kAriaWelcomeTitleI18n) has full title translation coverage', () {
      for (final card in _allCards()) {
        if (!kAriaWelcomeTitleI18n.containsKey(card.id)) continue;
        for (final lang in _nonEnglish) {
          final localized = card.localizedTitle(lang);
          expect(localized, isNotEmpty, reason: '${card.id} missing a "$lang" title translation');
          expect(localized, isNot(card.title), reason: '${card.id} "$lang" title fell back to English');
        }
      }
    });

    test('a role card (absent from kAriaWelcomeTitleI18n) resolves its title via kAriaWelcomeRoleTitleTranslations', () {
      for (final card in _allCards()) {
        if (kAriaWelcomeTitleI18n.containsKey(card.id)) continue;
        for (final lang in _nonEnglish) {
          expect(
            kAriaWelcomeRoleTitleTranslations[lang]?.containsKey(card.title),
            isTrue,
            reason: '${card.id}\'s title "${card.title}" has no "$lang" role-title translation',
          );
        }
      }
    });

    test('ariaWelcomeOpeningResponse never returns an empty string for any card, in any language', () {
      for (final card in _allCards()) {
        final action = kAriaActionCatalog[card.actionKey]!;
        for (final lang in ['english', ..._nonEnglish]) {
          final reply = ariaWelcomeOpeningResponse(
            actionKey: card.actionKey,
            label: action.label,
            response: action.response,
            language: lang,
          );
          expect(reply, isNotEmpty, reason: '${card.id} ("${card.actionKey}") empty opening response for "$lang"');
        }
      }
    });

    test('buildAriaWelcomeReply composes the localized context and the opening confirmation together', () {
      final card = kAriaWelcomeSectionContext['home']!.quickActions.first;
      final reply = buildAriaWelcomeReply(card: card, language: 'english');
      expect(reply, startsWith(card.context));
      expect(reply.length, greaterThan(card.context.length));
    });
  });
}
