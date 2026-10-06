/// `#chatbotLanguageSelect` (`templates/includes/aria_assistant.html`) —
/// the real web's own 5-language `<select>`, reproduced here exactly:
/// same codes (the literal `value="..."` attributes, which is what every
/// chat/voice/TTS request's `language` field actually carries — confirmed
/// directly in `static/js/BOTscript.js`'s `getSelectedAssistantLanguage`),
/// same display labels, same order, same default (`english`, the first
/// option — the real `<select>` has no `selected` attribute anywhere, so
/// the browser defaults to the first option exactly like
/// [AriaChatState.language] already does). No flags/icons — the real
/// `<option>` elements are plain text, nothing else to reproduce.
class AriaLanguageOption {
  const AriaLanguageOption({required this.code, required this.label});

  final String code;
  final String label;
}

const kAriaLanguages = [
  AriaLanguageOption(code: 'english', label: 'English'),
  AriaLanguageOption(code: 'vietnam', label: 'Vietnamese'),
  AriaLanguageOption(code: 'hindi', label: 'Hindi'),
  AriaLanguageOption(code: 'arabic', label: 'Arabic'),
  AriaLanguageOption(code: 'russian', label: 'Russian'),
];
