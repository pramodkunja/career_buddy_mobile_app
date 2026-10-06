import '../entities/writing_task_feedback.dart';

/// Parses `submit_exercise`'s server-generated `customSummaryHtml` for a
/// `writing` exercise back into structured per-task feedback, instead of
/// rendering the raw HTML string (no HTML-rendering dependency exists in
/// this project, and adding one is unnecessary for this single, entirely
/// deterministic template — see `activities/views.py:1465-1495` for the
/// exact three block shapes this parses).
///
/// Per task `i+1`, the server emits exactly one of:
/// 1. A header + a bulleted issues list (`<li>` per issue: flagged
///    phrase/message/suggestion), optionally followed by an "Improved
///    Version" block.
/// 2. A header + "No major issues found." (no `<li>` items — an empty
///    [WritingTaskFeedback.issues] list represents this), optionally
///    followed by an "Improved Version" block.
/// 3. A single "Answer too short to evaluate." block
///    ([WritingTaskFeedback.tooShortToEvaluate]) — the server's AI branch
///    never ran for this task.
///
/// A task can also be entirely absent from the HTML (the AI call threw an
/// exception server-side, `activities/views.py:1482-1484`) — there is
/// nothing to parse for it, so it is simply missing from the returned list,
/// matching what a browser would actually render (nothing).
List<WritingTaskFeedback> parseWritingSummaryHtml(String html) {
  final tooShortPattern = RegExp(
    r"<div class='mt-3 mb-2 text-danger text-start'><strong>Task (\d+):</strong> Answer too short to evaluate\.</div>",
  );
  final headerPattern = RegExp(r"<div class='mt-3 mb-2 text-start'><strong>Task (\d+):</strong></div>");
  final issuePattern = RegExp(
    r"<li class='mb-2'><strong><span class='text-danger'>(.*?)</span></strong>: (.*?) <br><span class='text-success'>Suggestion: (.*?)</span></li>",
    dotAll: true,
  );
  final improvedPattern = RegExp(r"<strong>Improved Version:</strong><br>(.*?)</div>", dotAll: true);

  final markers = <(int start, int end, int taskNumber, bool tooShort)>[
    for (final m in tooShortPattern.allMatches(html)) (m.start, m.end, int.parse(m.group(1)!), true),
    for (final m in headerPattern.allMatches(html)) (m.start, m.end, int.parse(m.group(1)!), false),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  final result = <WritingTaskFeedback>[];
  for (var i = 0; i < markers.length; i++) {
    final (_, end, taskNumber, tooShort) = markers[i];
    if (tooShort) {
      result.add(WritingTaskFeedback(taskNumber: taskNumber, tooShortToEvaluate: true));
      continue;
    }

    final bodyEnd = i + 1 < markers.length ? markers[i + 1].$1 : html.length;
    final body = html.substring(end, bodyEnd);

    final issues = [
      for (final m in issuePattern.allMatches(body))
        WritingIssue(phrase: m.group(1)!, message: m.group(2)!, suggestion: m.group(3)!),
    ];
    final improved = improvedPattern.firstMatch(body)?.group(1);

    result.add(WritingTaskFeedback(taskNumber: taskNumber, issues: issues, improvedPassage: improved));
  }

  result.sort((a, b) => a.taskNumber.compareTo(b.taskNumber));
  return result;
}
