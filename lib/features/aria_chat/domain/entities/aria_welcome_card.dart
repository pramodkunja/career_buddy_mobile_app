import '../aria_welcome_translations.g.dart';

/// One "predefined question" card from the real web's persistent welcome
/// panel (`#riya-welcome-panel`, `static/js/BOTscript.js`'s
/// `renderPersistentWelcome()`/`SECTION_CONTEXT`/`WELCOME_CONTEXT`) —
/// confirmed by fetching the actual deployed `BOTscript.js` directly
/// (`?v=riya-welcome-voice-v22`), since this feature exists only in
/// production and not in the checked-out Django repo's copy of the file.
///
/// [title] reads as a question/prompt the user might ask (e.g. "Which jobs
/// match my profile?"); tapping it sends that exact text as the user's
/// "message" and replies with [context] (localized) plus a short "Opening
/// X." confirmation — see `aria_welcome_reply.dart`'s
/// `buildAriaWelcomeReply`. [description] is the short subtitle shown under
/// the title and is never translated — confirmed directly: the real web has
/// no per-language override for it anywhere (`TITLE_I18N`/`CONTEXT_I18N`
/// only cover title/context).
class AriaWelcomeCard {
  const AriaWelcomeCard({
    required this.id,
    required this.actionKey,
    required this.icon,
    required this.title,
    required this.description,
    required this.context,
  });

  /// Stable id (e.g. `"sec-home-jobs"`) — the key into
  /// [kAriaWelcomeTitleI18n]/[kAriaWelcomeContextI18n].
  final String id;

  /// Key into `kAriaActionCatalog` (`aria_welcome_catalog.g.dart`) — the
  /// same action-key space the real `ACTION_DEFINITIONS`/this app's own
  /// `AriaChatAction.key` already use.
  final String actionKey;

  /// One of `AriaWelcomeIcons`' keys (`aria_welcome_icons.dart`).
  final String icon;

  final String title;
  final String description;
  final String context;

  /// `TITLE_I18N[id]?.[lang] || RECOMMENDATION_TRANSLATIONS[lang]?.[title] ||
  /// title` — re-read directly from `renderPersistentWelcome()`'s
  /// `buildWelcomeCard`. Section cards resolve via [kAriaWelcomeTitleI18n];
  /// role cards (no entry there) fall through to
  /// [kAriaWelcomeRoleTitleTranslations], keyed by this card's own English
  /// [title] — English itself needs neither map (both already default to
  /// [title] unchanged).
  String localizedTitle(String language) {
    if (language == 'english') return title;
    return kAriaWelcomeTitleI18n[id]?[language] ?? kAriaWelcomeRoleTitleTranslations[language]?[title] ?? title;
  }

  /// `lang === "english" ? card.context : CONTEXT_I18N[card.id]?.[lang]` —
  /// re-read directly from `buildWelcomeReply()`. Every card this app ships
  /// has full non-English coverage (confirmed against the live data during
  /// extraction), so the `?? context` fallback below is defensive only and
  /// should never actually trigger.
  String localizedContext(String language) {
    if (language == 'english') return context;
    return kAriaWelcomeContextI18n[id]?[language] ?? context;
  }
}

/// A page/section's two card groups — mirrors one `SECTION_CONTEXT`/
/// `WELCOME_CONTEXT` entry. [recommendations] renders as a second grid right
/// under [quickActions]' grid, with no heading in between — confirmed
/// directly: `renderPersistentWelcome()` never reads the `heading`/
/// `recommendationHeading` fields the real data still carries, and the CSS
/// classes for a heading/mascot/"See more" button (`.riya-welcome-heading`,
/// `.riya-welcome-mascot`, `.riya-welcome-rec-head`, `.riya-welcome-seemore`)
/// are dead — never applied by any JS, so this app reproduces what the real
/// widget actually renders today, not those unused leftovers.
class AriaWelcomeCardGroup {
  const AriaWelcomeCardGroup({required this.quickActions, this.recommendations = const []});

  final List<AriaWelcomeCard> quickActions;
  final List<AriaWelcomeCard> recommendations;
}
