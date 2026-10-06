/// Ports `estimateDuration()` verbatim (`static/activities/js/listening.js:268-272`)
/// — an estimate of how long the browser's speech synthesis will take to
/// read a story aloud at a given speed, used to drive the progress bar.
/// Not derived from any real audio file (there is none — see
/// `docs/W016_AI_LISTENING.md` §Audio).
int estimateListeningDuration(String text, double speed) {
  final words = RegExp(r"[A-Za-z']+").allMatches(text).length;
  final wordsPerSecond = (2.6 * speed) < 1.8 ? 1.8 : 2.6 * speed;
  final estimate = (words / wordsPerSecond).round();
  return estimate < 8 ? 8 : estimate;
}
