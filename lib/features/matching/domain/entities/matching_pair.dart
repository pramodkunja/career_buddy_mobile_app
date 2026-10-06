/// One left/right pair of a Matching exercise.
///
/// [position] is the pair's 1-based index within the exercise's question
/// order — **not** a database `Question.id`. Verified directly against
/// `templates/activities/exercise.html`'s matching branch: both
/// `.left-item` and `.right-item` are rendered with
/// `data-id="{{ forloop.counter }}"`, and `exercises.js`'s `tryMatch()`
/// grades a pair correct when `paired === correct` where `correct = id`
/// (the left item's own `data-id`) — i.e. a match is correct exactly when
/// the left and right items share the same *position*, regardless of the
/// underlying `Question.id`.
class MatchingPair {
  const MatchingPair({required this.position, required this.leftText, required this.rightText});

  final int position;
  final String leftText;
  final String rightText;
}
