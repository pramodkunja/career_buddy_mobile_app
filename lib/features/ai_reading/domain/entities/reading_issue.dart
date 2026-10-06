/// Same 4-string shape as `SpeakingIssue`/`WritingIssue`/`ListeningIssue`.
class ReadingIssue {
  const ReadingIssue({required this.phrase, required this.type, required this.message, required this.suggestion});

  final String phrase;
  final String type;
  final String message;
  final String suggestion;
}
