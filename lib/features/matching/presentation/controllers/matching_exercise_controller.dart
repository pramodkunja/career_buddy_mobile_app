import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/matching_exercise.dart';
import '../../domain/entities/matching_submission_result.dart';
import '../providers/matching_providers.dart';

/// Mirrors `McqExerciseController`'s sealed-state shape (see its doc
/// comment for why a plain `AsyncNotifier` isn't enough), adapted for
/// Matching's own, quite different interaction model: selection/pairing
/// state instead of per-question selected answers, and a locally
/// (client-side) computed score instead of one only the server ever knows.
sealed class MatchingExerciseState {
  const MatchingExerciseState();
}

final class MatchingExerciseLoading extends MatchingExerciseState {
  const MatchingExerciseLoading();
}

final class MatchingExerciseLoadFailed extends MatchingExerciseState {
  const MatchingExerciseLoadFailed(this.failure);
  final Failure failure;
}

/// The user is pairing terms and definitions.
///
/// [rightOrder] is the shuffled display order of the right column's
/// positions, generated **once** per load — mirrors `initMatching()`'s own
/// one-time Fisher-Yates shuffle on page load
/// (`static/js/exercises.js:274-281`); the web does not reshuffle again
/// until a full page reload (Try Again), which this app matches by only
/// regenerating [rightOrder] from [MatchingExerciseController.build]/
/// [MatchingExerciseController.tryAgain], never from [reset].
final class MatchingExerciseInProgress extends MatchingExerciseState {
  const MatchingExerciseInProgress({
    required this.exercise,
    required this.rightOrder,
    this.selectedLeft,
    this.selectedRight,
    this.matches = const {},
    this.isSubmitting = false,
    this.submitError,
  });

  final MatchingExercise exercise;
  final List<int> rightOrder;
  final int? selectedLeft;
  final int? selectedRight;

  /// left position -> right position it's currently paired with.
  final Map<int, int> matches;
  final bool isSubmitting;
  final Failure? submitError;

  bool get allMatched => matches.length == exercise.pairs.length;

  MatchingExerciseInProgress copyWith({
    int? selectedLeft,
    int? selectedRight,
    Map<int, int>? matches,
    bool? isSubmitting,
    Failure? submitError,
    bool clearSelectedLeft = false,
    bool clearSelectedRight = false,
    bool clearSubmitError = false,
  }) {
    return MatchingExerciseInProgress(
      exercise: exercise,
      rightOrder: rightOrder,
      selectedLeft: clearSelectedLeft ? null : (selectedLeft ?? this.selectedLeft),
      selectedRight: clearSelectedRight ? null : (selectedRight ?? this.selectedRight),
      matches: matches ?? this.matches,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

final class MatchingExerciseSubmitted extends MatchingExerciseState {
  const MatchingExerciseSubmitted({required this.exercise, required this.matches, required this.result});
  final MatchingExercise exercise;

  /// The final left->right pairing at the moment of submission — the
  /// result view derives per-pair correctness from this against
  /// `exercise.pairs` (`matches[pair.position] == pair.position`), the same
  /// rule `tryMatch()`/the submit handler use
  /// (`static/js/exercises.js:394`).
  final Map<int, int> matches;
  final MatchingSubmissionResult result;
}

class MatchingExerciseController extends Notifier<MatchingExerciseState> {
  MatchingExerciseController(this.arg);

  /// (exerciseId, title, order) — a record, since [NotifierProvider.family]
  /// passes its single `Arg` straight to this constructor (see
  /// `matchingExerciseControllerProvider`).
  final (int, String, int) arg;

  int get exerciseId => arg.$1;
  String get title => arg.$2;
  int get order => arg.$3;

  @override
  MatchingExerciseState build() {
    _load();
    return const MatchingExerciseLoading();
  }

  Future<void> _load() async {
    final result = await ref
        .read(matchingExerciseRepositoryProvider)
        .getMatchingExercise(exerciseId, title: title, order: order);
    state = switch (result) {
      Success(value: final exercise) => MatchingExerciseInProgress(exercise: exercise, rightOrder: _shuffledOrder(exercise)),
      Failed(failure: final failure) => MatchingExerciseLoadFailed(failure),
    };
  }

  List<int> _shuffledOrder(MatchingExercise exercise) {
    final positions = [for (final pair in exercise.pairs) pair.position];
    positions.shuffle(Random());
    return positions;
  }

  Future<void> retryLoad() async {
    state = const MatchingExerciseLoading();
    await _load();
  }

  /// Full re-run of the flow, including a fresh shuffle — mirrors the
  /// web's "Try Again" (`onclick="location.reload()"`,
  /// `templates/activities/exercise.html:408-409`), a full page reload
  /// that resets every bit of state.
  Future<void> tryAgain() async {
    state = const MatchingExerciseLoading();
    await _load();
  }

  /// Tapping an already-matched left item **unmatches** it — a mobile
  /// adaptation of the web's desktop-only double-click-to-unpair gesture
  /// (`static/js/exercises.js:304-339`); the underlying capability (the
  /// web "allows a user to modify/remove a match") is preserved, only the
  /// gesture changes, since double-tap has no discoverable, reliable mobile
  /// equivalent.
  void tapLeft(int position) {
    final current = state;
    if (current is! MatchingExerciseInProgress || current.isSubmitting) return;
    if (current.matches.containsKey(position)) {
      _unmatch(current, leftPosition: position);
      return;
    }
    final selectedRight = current.selectedRight;
    if (selectedRight != null) {
      _createMatch(current, leftPosition: position, rightPosition: selectedRight);
      return;
    }
    state = current.copyWith(selectedLeft: position, clearSubmitError: true);
  }

  void tapRight(int position) {
    final current = state;
    if (current is! MatchingExerciseInProgress || current.isSubmitting) return;
    if (current.matches.containsValue(position)) {
      final leftPosition = current.matches.entries.firstWhere((e) => e.value == position).key;
      _unmatch(current, leftPosition: leftPosition);
      return;
    }
    final selectedLeft = current.selectedLeft;
    if (selectedLeft != null) {
      _createMatch(current, leftPosition: selectedLeft, rightPosition: position);
      return;
    }
    state = current.copyWith(selectedRight: position, clearSubmitError: true);
  }

  void _createMatch(MatchingExerciseInProgress current, {required int leftPosition, required int rightPosition}) {
    state = current.copyWith(
      matches: {...current.matches, leftPosition: rightPosition},
      clearSelectedLeft: true,
      clearSelectedRight: true,
      clearSubmitError: true,
    );
  }

  void _unmatch(MatchingExerciseInProgress current, {required int leftPosition}) {
    final matches = {...current.matches}..remove(leftPosition);
    state = current.copyWith(matches: matches, clearSubmitError: true);
  }

  /// Clears every match without reshuffling — mirrors `#reset-matching`
  /// (`static/js/exercises.js:366-385`), which clears `matches`/`answers`
  /// and hides the result but does not touch the right column's order.
  void reset() {
    final current = state;
    if (current is! MatchingExerciseInProgress || current.isSubmitting) return;
    state = current.copyWith(
      matches: const {},
      clearSelectedLeft: true,
      clearSelectedRight: true,
      clearSubmitError: true,
    );
  }

  Future<void> submit() async {
    final current = state;
    // Mirrors the web's own "Check Matches" disabled-until-complete rule
    // (`#submit-matching`, `static/js/exercises.js:333,360`) — enforced
    // here too, not only by the UI disabling the button.
    if (current is! MatchingExerciseInProgress || current.isSubmitting || !current.allMatched) return;

    // Client-computed score — this exercise type is client-authoritative
    // on the web itself (see `MatchingSubmissionResult`'s doc comment), not
    // a shortcut this app is taking. A pair is correct exactly when its
    // right position equals its left position (`tryMatch()`'s own rule,
    // `static/js/exercises.js:394`).
    var score = 0;
    for (final pair in current.exercise.pairs) {
      if (current.matches[pair.position] == pair.position) score++;
    }
    final maxScore = current.exercise.pairs.length;

    state = current.copyWith(isSubmitting: true, clearSubmitError: true);
    final result = await ref
        .read(matchingExerciseRepositoryProvider)
        .submitMatchingExercise(current.exercise.id, score: score, maxScore: maxScore, matches: current.matches);

    state = switch (result) {
      Success(value: final submissionResult) => MatchingExerciseSubmitted(
        exercise: current.exercise,
        matches: current.matches,
        result: submissionResult,
      ),
      Failed(failure: final failure) => current.copyWith(isSubmitting: false, submitError: failure),
    };
  }
}

final matchingExerciseControllerProvider =
    NotifierProvider.family<MatchingExerciseController, MatchingExerciseState, (int, String, int)>(
      MatchingExerciseController.new,
    );
