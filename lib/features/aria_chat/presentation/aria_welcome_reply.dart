import '../domain/aria_welcome_catalog.g.dart';
import '../domain/aria_welcome_translations.g.dart';
import '../domain/entities/aria_welcome_card.dart';

/// Six actions with an exact, hand-written localized confirmation in every
/// language — re-read directly from `getLocalizedActionResponse()`'s own
/// `responses` map (`static/js/BOTscript.js`), checked *before* the generic
/// [kAriaSectionNames]-based path below. English entries exist here too
/// (unlike [kAriaSectionNames], which the real function skips entirely for
/// English) because the real map covers English the same way.
const _kAriaOpeningOverrides = <String, Map<String, String>>{
  'english': {
    'mock_interview': 'Taking you to the Resume Builder for your AI Mock Interview.',
    'resume_builder': 'Opening the Resume Builder.',
    'aptitude': 'Taking you to the Aptitude section.',
    'tech': 'Taking you to the Tech section.',
    'grammar': 'Opening the Grammar section.',
    'profile': 'Opening your dashboard.',
  },
  'hindi': {
    'mock_interview': 'आपको AI Mock Interview के लिए Resume Builder पर ले जा रहा हूँ।',
    'resume_builder': 'आपको Resume Builder पर ले जा रहा हूँ।',
    'aptitude': 'आपको Aptitude सेक्शन में ले जा रहा हूँ।',
    'tech': 'आपको Tech सेक्शन में ले जा रहा हूँ।',
    'grammar': 'आपको Grammar सेक्शन में ले जा रहा हूँ।',
    'profile': 'आपका Dashboard खोल रहा हूँ।',
  },
  'vietnam': {
    'mock_interview': 'Đang đưa bạn đến Resume Builder cho AI Mock Interview.',
    'resume_builder': 'Đang mở Resume Builder.',
    'aptitude': 'Đang đưa bạn đến phần Aptitude.',
    'tech': 'Đang đưa bạn đến phần Tech.',
    'grammar': 'Đang mở phần Grammar.',
    'profile': 'Đang mở Dashboard của bạn.',
  },
  'arabic': {
    'mock_interview': 'سأنقلك إلى Resume Builder لإجراء AI Mock Interview.',
    'resume_builder': 'جارٍ فتح Resume Builder.',
    'aptitude': 'سأنقلك إلى قسم Aptitude.',
    'tech': 'سأنقلك إلى قسم Tech.',
    'grammar': 'جارٍ فتح قسم Grammar.',
    'profile': 'جارٍ فتح لوحة التحكم الخاصة بك.',
  },
  'russian': {
    'mock_interview': 'Перевожу вас в Resume Builder для AI Mock Interview.',
    'resume_builder': 'Открываю Resume Builder.',
    'aptitude': 'Перевожу вас в раздел Aptitude.',
    'tech': 'Перевожу вас в раздел Tech.',
    'grammar': 'Открываю раздел Grammar.',
    'profile': 'Открываю вашу панель управления.',
  },
};

/// English-only generic label translations — re-read directly from
/// `getLocalizedActionResponse()`'s own `labels.english` map. Reached only
/// when [_kAriaOpeningOverrides] misses *and* the action's label isn't one
/// of these (English never consults [kAriaSectionNames], unlike every other
/// language — that function returns `""` immediately for English).
const _kAriaGenericEnglishLabels = <String, String>{
  'Home': 'home',
  'Go to Activities': 'the activities page',
  'Speaking & Presentation': 'speaking and presentation',
  'Writing and Correspondence': 'writing and correspondence',
  'Vocabulary & Idioms': 'vocabulary and idioms',
  'Negotiation & Meetings': 'negotiation and meetings',
  'Professional Communication': 'professional communication',
  'Analysis & Reporting': 'analysis and reporting',
  'View Dashboard': 'your dashboard',
  'Job Seeker Sign-In': 'the job seeker sign-in page',
  'Employer Login': 'the employer portal',
  'Grammar': 'the grammar section',
  'Resume Builder': 'resume builder',
  'Membership': 'membership plans',
  'AI Mock Interview': 'AI Mock Interview',
};

/// `OPENING_FRAMES[lang](name)` — the sentence template each language wraps
/// a (possibly translated) section/label name in.
String _ariaOpeningFrame(String language, String name) {
  switch (language) {
    case 'hindi':
      return '$name खोल रहा हूँ।';
    case 'vietnam':
      return 'Đang mở $name.';
    case 'arabic':
      return 'جارٍ فتح $name.';
    case 'russian':
      return 'Открываю $name.';
    default:
      return 'Opening $name.';
  }
}

/// `getLocalizedActionResponse(action)` — the short "Opening X." (or
/// equivalent) confirmation appended after a welcome card's own answer. The
/// real function's fallback chain, re-read directly and reproduced exactly
/// (`static/js/BOTscript.js`):
/// 1. [_kAriaOpeningOverrides] — six actions with a hand-written line in
///    every language, including English.
/// 2. Non-English only: [kAriaSectionNames]'s localized display name for
///    [actionKey], wrapped in [_ariaOpeningFrame].
/// 3. English only: [_kAriaGenericEnglishLabels]'s translation of [label],
///    wrapped as `"Opening X."`.
/// 4. Final fallback: [response] (the action's own canned, already-English
///    `"Opening X."`-shaped text) — English only, since every actionKey this
///    app's cards reference has a [kAriaSectionNames] entry, making step 2
///    exhaustive for every other language (confirmed during source
///    extraction: 49/49 `ACTION_DEFINITIONS` keys are covered).
String ariaWelcomeOpeningResponse({
  required String actionKey,
  required String label,
  required String response,
  required String language,
}) {
  final override = _kAriaOpeningOverrides[language]?[actionKey];
  if (override != null) return override;

  if (language != 'english') {
    final sectionNameKey = language == 'vietnam' ? 'vietnamese' : language;
    final name = kAriaSectionNames[actionKey]?[sectionNameKey];
    if (name != null && name.isNotEmpty) return _ariaOpeningFrame(language, name);
  }

  final translatedLabel = _kAriaGenericEnglishLabels[label];
  if (translatedLabel != null) return 'Opening $translatedLabel.';
  return response.isNotEmpty ? response : 'Opening $label.';
}

/// `buildWelcomeReply(card, action, lang)` — the full spoken/displayed
/// assistant reply for a tapped welcome card: the card's own (localized)
/// answer, then the action's opening confirmation.
String buildAriaWelcomeReply({required AriaWelcomeCard card, required String language}) {
  final action = kAriaActionCatalog[card.actionKey];
  final opening = action == null
      ? ''
      : ariaWelcomeOpeningResponse(
          actionKey: card.actionKey,
          label: action.label,
          response: action.response,
          language: language,
        );
  final context = card.localizedContext(language);
  return opening.isEmpty ? context : '$context $opening';
}
