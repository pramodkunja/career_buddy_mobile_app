import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../ai_listening/domain/services/listening_tts_service.dart';
import '../../../ai_listening/presentation/providers/ai_listening_providers.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/entities/bingo_exercise.dart';
import '../../domain/entities/bingo_submission_result.dart';
import '../providers/bingo_providers.dart';

/// Per-board-cell visual state — mirrors `.bingo-cell`'s classes exactly
/// (`static/css/exercises.css:194-243`): unmarked (`neutral`), the current
/// round's tentative pick (`marked`, `.bingo-cell.marked`), and the two
/// post-evaluation states (`correct`/`wrong`, `.bingo-win`/`.wrong`).
enum BingoCellState { neutral, marked, correct, wrong }

sealed class BingoExerciseState {
  const BingoExerciseState();
}

final class BingoExerciseLoading extends BingoExerciseState {
  const BingoExerciseLoading();
}

final class BingoExerciseLoadFailed extends BingoExerciseState {
  const BingoExerciseLoadFailed(this.failure);
  final Failure failure;
}

/// Loaded, not yet started — "Press Start to begin" (`bingo-current-word`'s
/// initial text, `templates/activities/exercise.html:256`). The board is
/// visible but every cell click is a no-op here, matching
/// `cells.forEach(...)`'s own `if (!gameActive ...) return;` guard. Only
/// ever entered once, right after load — [start] always transitions
/// straight to [BingoExercisePlaying] and never returns here, so the
/// button is always labelled "Start Game", never "Restart", in this state
/// (matching the web: the label only ever flips once `bingo-start` has
/// been clicked at least once).
final class BingoExerciseReady extends BingoExerciseState {
  const BingoExerciseReady(this.exercise);
  final BingoExercise exercise;
}

/// The user is playing: one definition shown at a time, tap a board word,
/// tap Next to advance. Mirrors `initBingo()`'s round loop
/// (`static/js/exercises.js:499-587`).
final class BingoExercisePlaying extends BingoExerciseState {
  const BingoExercisePlaying({required this.exercise, required this.sequence, required this.roundIndex, this.selections = const {}});

  final BingoExercise exercise;

  /// The shuffled full card list (`sequence = shuffle([...words])`) — one
  /// round per card, in this order. Deliberately the **full**, unsliced
  /// card list, not just the 25-card board — see `BingoExercise.cards`'s
  /// doc comment for why a >25-card exercise can have unwinnable rounds.
  final List<BingoCard> sequence;

  /// 0-based index into [sequence] for the round currently being shown.
  final int roundIndex;

  /// round index -> the board word tapped for that round. Only the
  /// current round's entry is ever shown as "marked" on the board — a
  /// prior round's mark disappears once you advance, exactly like the web
  /// (`showNextRound()` clears `roundCell` on every advance), even though
  /// the underlying answer is retained here for final grading.
  final Map<int, String> selections;

  BingoCard get currentCard => sequence[roundIndex];
  String? get markedWord => selections[roundIndex];
  bool get isLastRound => roundIndex == sequence.length - 1;

  BingoExercisePlaying copyWith({int? roundIndex, Map<int, String>? selections}) {
    return BingoExercisePlaying(
      exercise: exercise,
      sequence: sequence,
      roundIndex: roundIndex ?? this.roundIndex,
      selections: selections ?? this.selections,
    );
  }
}

/// Every round has been answered — graded locally and submitted (or being
/// submitted). Mirrors the web's `evaluate()`: grading/the board's final
/// colors/the BINGO-line message are all computed and shown **instantly**,
/// independent of the network call that follows
/// (`static/js/exercises.js:591-648`) — [isSubmitting]/[submitError]/
/// [submissionResult] track only the *persistence* of an already-final,
/// already-displayed result, never its content.
final class BingoExerciseResult extends BingoExerciseState {
  const BingoExerciseResult({
    required this.exercise,
    required this.sequence,
    required this.selections,
    required this.cardStates,
    required this.bingoLineWords,
    required this.bingoLines,
    required this.correctCount,
    this.isSubmitting = false,
    this.submitError,
    this.submissionResult,
  });

  final BingoExercise exercise;
  final List<BingoCard> sequence;
  final Map<int, String> selections;
  final Map<String, BingoCellState> cardStates;

  /// Words that are part of at least one completed 5-in-a-row line — an
  /// extra ring/pulse over an already-`correct` cell
  /// (`.bingo-cell.bingo-line`), not a distinct color.
  final Set<String> bingoLineWords;
  final int bingoLines;
  final int correctCount;
  int get maxCount => sequence.length;

  final bool isSubmitting;
  final Failure? submitError;
  final BingoSubmissionResult? submissionResult;

  BingoExerciseResult copyWith({bool? isSubmitting, Failure? submitError, BingoSubmissionResult? submissionResult, bool clearSubmitError = false}) {
    return BingoExerciseResult(
      exercise: exercise,
      sequence: sequence,
      selections: selections,
      cardStates: cardStates,
      bingoLineWords: bingoLineWords,
      bingoLines: bingoLines,
      correctCount: correctCount,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      submissionResult: submissionResult ?? this.submissionResult,
    );
  }
}

class BingoExerciseController extends Notifier<BingoExerciseState> {
  BingoExerciseController(this.arg);

  /// (exerciseId, title, order) — a record, passed straight to this
  /// constructor by [NotifierProvider.family] — same pattern as
  /// `MatchingExerciseController`.
  final (int, String, int) arg;

  int get exerciseId => arg.$1;
  String get title => arg.$2;
  int get order => arg.$3;

  late final ListeningTtsService _tts;

  @override
  BingoExerciseState build() {
    _tts = ref.read(listeningTtsServiceProvider);
    ref.onDispose(() => unawaited(_tts.stop()));
    _load();
    return const BingoExerciseLoading();
  }

  Future<void> _load() async {
    final result = await ref.read(bingoExerciseRepositoryProvider).getBingoExercise(exerciseId, title: title, order: order);
    state = switch (result) {
      Success(value: final exercise) => BingoExerciseReady(exercise),
      Failed(failure: final failure) => BingoExerciseLoadFailed(failure),
    };
  }

  Future<void> retryLoad() async {
    state = const BingoExerciseLoading();
    await _load();
  }

  /// Starts (or restarts) the game — the same single action as the web's
  /// Start/Restart button (`static/js/exercises.js:531-545`), callable
  /// whether the exercise hasn't been played yet, is mid-play, or just
  /// finished. Always reshuffles [BingoExercisePlaying.sequence] fresh.
  void start() {
    final exercise = switch (state) {
      BingoExerciseReady(:final exercise) => exercise,
      BingoExercisePlaying(:final exercise) => exercise,
      BingoExerciseResult(:final exercise) => exercise,
      _ => null,
    };
    if (exercise == null) return;

    final sequence = [...exercise.cards]..shuffle(Random());
    state = BingoExercisePlaying(exercise: exercise, sequence: sequence, roundIndex: 0);
    _speakCurrentDefinition();
  }

  void _speakCurrentDefinition() {
    final current = state;
    if (current is! BingoExercisePlaying) return;
    // Speech is a nice-to-have, never allowed to break the game — mirrors
    // `speakNaturally`'s own defensive `catch (e) {}`
    // (`static/js/exercises.js:492`).
    unawaited(_tts.speak(current.currentCard.definition, rate: 1.0).catchError((_) {}));
  }

  /// Tap a board word to record it as this round's tentative answer —
  /// mirrors the `.bingo-cell` click handler
  /// (`static/js/exercises.js:578-587`). Re-tapping a different word for
  /// the same round replaces the previous pick, same as the web.
  void selectCell(String word) {
    final current = state;
    if (current is! BingoExercisePlaying) return;
    state = current.copyWith(selections: {...current.selections, current.roundIndex: word});
  }

  /// Advances to the next round, or evaluates/submits once the last round
  /// is answered — mirrors `bingo-next`'s click handler
  /// (`static/js/exercises.js:563-573`), including its own guard: a no-op,
  /// not an error, until the current round has a pick.
  void nextRound() {
    final current = state;
    if (current is! BingoExercisePlaying) return;
    if (current.markedWord == null) return;

    if (current.isLastRound) {
      _evaluateAndSubmit(current);
      return;
    }
    state = current.copyWith(roundIndex: current.roundIndex + 1);
    _speakCurrentDefinition();
  }

  void _evaluateAndSubmit(BingoExercisePlaying playing) {
    final board = playing.exercise.board;
    final cardStates = {for (final card in board) card.word: BingoCellState.neutral};

    // Pass 1: correct picks turn green — mirrors
    // `static/js/exercises.js:600-605`.
    var correctCount = 0;
    for (var i = 0; i < playing.sequence.length; i++) {
      final chosen = playing.selections[i];
      if (chosen == null || chosen != playing.sequence[i].word) continue;
      correctCount++;
      if (cardStates.containsKey(chosen)) cardStates[chosen] = BingoCellState.correct;
    }
    // Pass 2: wrong picks turn red — always overrides pass 1, exactly like
    // `static/js/exercises.js:606-612`'s own comment ("red always wins").
    for (var i = 0; i < playing.sequence.length; i++) {
      final chosen = playing.selections[i];
      if (chosen == null || chosen == playing.sequence[i].word) continue;
      if (cardStates.containsKey(chosen)) cardStates[chosen] = BingoCellState.wrong;
    }

    // BINGO line detection — only runs on a full 25-cell board, exactly
    // like `if (cells.length >= size * size)`
    // (`static/js/exercises.js:619`).
    var bingoLines = 0;
    final bingoLineWords = <String>{};
    if (board.length >= BingoExercise.boardSize) {
      const size = 5;
      final lines = <List<int>>[
        for (var r = 0; r < size; r++) [for (var c = 0; c < size; c++) r * size + c],
        for (var c = 0; c < size; c++) [for (var r = 0; r < size; r++) r * size + c],
        [0, 6, 12, 18, 24],
        [4, 8, 12, 16, 20],
      ];
      for (final line in lines) {
        final words = line.map((i) => board[i].word).toList();
        if (words.every((w) => cardStates[w] == BingoCellState.correct)) {
          bingoLines++;
          bingoLineWords.addAll(words);
        }
      }
    }

    final selectionsSnapshot = Map<int, String>.from(playing.selections);
    state = BingoExerciseResult(
      exercise: playing.exercise,
      sequence: playing.sequence,
      selections: selectionsSnapshot,
      cardStates: cardStates,
      bingoLineWords: bingoLineWords,
      bingoLines: bingoLines,
      correctCount: correctCount,
      isSubmitting: true,
    );
    unawaited(_submit(playing.exercise.id, playing.sequence, selectionsSnapshot, correctCount));
  }

  Future<void> _submit(int exerciseId, List<BingoCard> sequence, Map<int, String> selections, int correctCount) async {
    final answers = {
      for (var i = 0; i < sequence.length; i++)
        if (selections[i] != null) (i + 1): (target: sequence[i].word, chosen: selections[i]!),
    };
    final result = await ref
        .read(bingoExerciseRepositoryProvider)
        .submitBingoExercise(exerciseId, score: correctCount, maxScore: sequence.length, answers: answers);

    final current = state;
    if (current is! BingoExerciseResult) return;
    state = switch (result) {
      Success(value: final submissionResult) => current.copyWith(isSubmitting: false, submissionResult: submissionResult),
      Failed(failure: final failure) => current.copyWith(isSubmitting: false, submitError: failure),
    };
  }

  /// Retries only the network persistence step — the already-computed,
  /// already-displayed grading never changes. The web itself offers no
  /// equivalent (a failed `submitScore()` just shows a native `alert()`
  /// with no retry action, since `#submit-bingo` is permanently hidden and
  /// never becomes the `activeBtn` `submitScore` looks for — see
  /// `BingoSubmissionResult`'s doc comment); a "Retry" affordance here is a
  /// minimal, honest mobile adaptation for a failed POST, not a change to
  /// the grading/game rules.
  Future<void> retrySubmit() async {
    final current = state;
    if (current is! BingoExerciseResult || current.submitError == null || current.isSubmitting) return;
    state = current.copyWith(isSubmitting: true, clearSubmitError: true);
    unawaited(_submit(current.exercise.id, current.sequence, current.selections, current.correctCount));
  }
}

final bingoExerciseControllerProvider = NotifierProvider.family<BingoExerciseController, BingoExerciseState, (int, String, int)>(
  BingoExerciseController.new,
);
