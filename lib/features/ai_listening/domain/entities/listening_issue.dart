/// Same 4-string shape as `SpeakingIssue`/`WritingIssue` — every issue-
/// producing helper in `activities/agents/utils.py` shares it.
class ListeningIssue {
  const ListeningIssue({required this.phrase, required this.type, required this.message, required this.suggestion});

  final String phrase;
  final String type;
  final String message;
  final String suggestion;
}
