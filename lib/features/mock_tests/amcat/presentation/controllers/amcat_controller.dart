import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/failures.dart';
import '../../../../../core/utils/result.dart';
import '../../domain/entities/amcat_section.dart';
import '../../domain/entities/amcat_submission_result.dart';
import '../../domain/repositories/amcat_repository.dart';
import '../providers/amcat_providers.dart';

/// Which "sectioned exam" this controller instance is running — see
/// [AmcatController.variant]'s doc comment.
enum AmcatVariant { amcat, cocubes }

/// AMCAT's actual web flow (`amcat_mock_test.html`, verified directly) is
/// meaningfully different from OOP/Subject Quiz's single free-navigation
/// exam, which is why this is a separate controller rather than a
/// `MockTestController` variant:
/// - **One fetch, five sections**: `amcat_questions` returns all 5 sections
///   up front; there is no per-section network call.
/// - **Per-section timer**, not one exam-wide countdown — each section
///   gets its own `timeSec` and its own countdown, restarting on entry.
/// - **Gated section completion**: unlike OOP/Subject Quiz (submit anytime,
///   even with unanswered questions), AMCAT requires every question in a
///   section to be answered before it can be manually finished — a manual
///   "Next"/"Skip" on the last question jumps to the first unanswered
///   question and blocks, instead. Only a section *timing out* skips this
///   check (`finishSection()` is called directly on expiry).
/// - **No mark-for-review** — confirmed absent from the web's palette
///   (only "answered"/"current" states exist, no "marked" class at all).
/// - **An explicit, non-automatic transition between sections** — finishing
///   a (non-final) section shows a "Section Completed" status screen the
///   user must tap "Next Task" on; the next section never starts itself.
/// - **No local attempt history** — confirmed no `localStorage` use
///   anywhere in the AMCAT page, unlike OOP/Subject Quiz's `{subject}Scores`.
///
/// **W023 (CoCubes) reuse**: direct comparison of `cocubes_mock_test.html`
/// against `amcat_mock_test.html` (byte-diffed) shows the entire exam
/// engine above — timer, free in-section navigation, gated completion,
/// section-transition screen, exit/confirm, no history — is identical
/// between the two; only the section plan/copy differ, plus one dead code
/// path (see [AmcatSection]'s "code" type note — CoCubes's JS has real
/// support for a free-text "code" section type, but `_COCUBES_PLAN`
/// (`activities/views.py:2347-2352`) and every record in
/// `cocubes_full.json` are confirmed `"mcq"`, so that path can never
/// actually be served and is deliberately not reproduced). This one
/// controller class is reused for both via [variant], rather than forking
/// a parallel `CocubesController` that would duplicate this entire state
/// machine for zero behavioral difference.
sealed class AmcatState {
  const AmcatState();
}

/// The landing/instructions screens involve no network call and no timer,
/// so they're plain, stateless UI navigated locally by the screen itself
/// (mirroring how OOP's submit-confirmation dialog is UI-layer, not
/// controller state) — this is the controller's single "nothing started
/// yet" state, entered both initially and after "Exit"/"Retake Test".
final class AmcatLanding extends AmcatState {
  const AmcatLanding();
}

final class AmcatLoading extends AmcatState {
  const AmcatLoading();
}

final class AmcatLoadFailed extends AmcatState {
  const AmcatLoadFailed(this.failure);
  final Failure failure;
}

/// A section is live. [answers] mirrors the web's own model exactly:
/// section key -> a per-question array of the chosen option index (or
/// `null`), matching `answers[sec.key] = Array(len).fill(null)`.
final class AmcatInSection extends AmcatState {
  const AmcatInSection({
    required this.sections,
    required this.sectionIndex,
    required this.questionIndex,
    required this.answers,
    required this.remainingSeconds,
    this.showValidation = false,
    this.completedSectionKeys = const {},
  });

  final List<AmcatSection> sections;
  final int sectionIndex;
  final int questionIndex;
  final Map<String, List<int?>> answers;
  final int remainingSeconds;

  /// "Please answer all questions before submitting this section" —
  /// shown only after a manual attempt to finish with something
  /// unanswered (`showValidationMsg()`), cleared on the next interaction.
  final bool showValidation;

  final Set<String> completedSectionKeys;

  AmcatSection get currentSection => sections[sectionIndex];
  List<int?> get currentSectionAnswers => answers[currentSection.key]!;
  bool get isLastSection => sectionIndex == sections.length - 1;
  bool get isLastQuestionInSection => questionIndex == currentSection.questions.length - 1;
  int get answeredInSectionCount => currentSectionAnswers.where((a) => a != null).length;

  AmcatInSection copyWith({
    int? sectionIndex,
    int? questionIndex,
    Map<String, List<int?>>? answers,
    int? remainingSeconds,
    bool? showValidation,
    Set<String>? completedSectionKeys,
  }) {
    return AmcatInSection(
      sections: sections,
      sectionIndex: sectionIndex ?? this.sectionIndex,
      questionIndex: questionIndex ?? this.questionIndex,
      answers: answers ?? this.answers,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      showValidation: showValidation ?? this.showValidation,
      completedSectionKeys: completedSectionKeys ?? this.completedSectionKeys,
    );
  }
}

/// The "Section Completed" screen — shown after finishing any section
/// except the last, which goes straight to submission instead
/// (`finishSection()`: `if(secIndex < sections.length-1) {...} else {
/// showResults(); }`).
final class AmcatSectionTransition extends AmcatState {
  const AmcatSectionTransition({
    required this.sections,
    required this.finishedSectionIndex,
    required this.answers,
    required this.completedSectionKeys,
  });

  final List<AmcatSection> sections;
  final int finishedSectionIndex;
  final Map<String, List<int?>> answers;
  final Set<String> completedSectionKeys;

  AmcatSection get finishedSection => sections[finishedSectionIndex];
  AmcatSection get nextSection => sections[finishedSectionIndex + 1];
}

final class AmcatSubmitting extends AmcatState {
  const AmcatSubmitting({required this.sections, required this.answers});
  final List<AmcatSection> sections;
  final Map<String, List<int?>> answers;
}

/// Preserves every answer collected across all 5 sections — a submission
/// failure must never throw the user back to the beginning.
final class AmcatSubmitFailed extends AmcatState {
  const AmcatSubmitFailed({required this.sections, required this.answers, required this.failure});
  final List<AmcatSection> sections;
  final Map<String, List<int?>> answers;
  final Failure failure;
}

final class AmcatSubmitted extends AmcatState {
  const AmcatSubmitted({required this.sections, required this.answers, required this.result});
  final List<AmcatSection> sections;
  final Map<String, List<int?>> answers;
  final AmcatSubmissionResult result;
}

class AmcatController extends Notifier<AmcatState> {
  AmcatController({this.variant = AmcatVariant.amcat});

  /// Which backend endpoint pair this instance talks to — see
  /// [AmcatState]'s "W023 (CoCubes) reuse" doc comment. Resolved once in
  /// [build] since both repository providers are cheap, side-effect-free
  /// singletons, so eager resolution needs no lazy-provider plumbing.
  final AmcatVariant variant;

  late final AmcatRepository _repository;
  Timer? _timer;

  @override
  AmcatState build() {
    _repository = switch (variant) {
      AmcatVariant.amcat => ref.read(amcatRepositoryProvider),
      AmcatVariant.cocubes => ref.read(cocubesRepositoryProvider),
    };
    ref.onDispose(() => _timer?.cancel());
    return const AmcatLanding();
  }

  /// Fetches every section and enters the first one — called once the user
  /// has agreed to the instructions and tapped "Start Test" (`startExam()`).
  Future<void> start() async {
    state = const AmcatLoading();
    final result = await _repository.getSections();
    switch (result) {
      case Success(value: final sections):
        if (sections.isEmpty) {
          state = const AmcatLoadFailed(UnexpectedFailure());
          return;
        }
        final answers = {for (final sec in sections) sec.key: List<int?>.filled(sec.questions.length, null)};
        state = AmcatInSection(
          sections: sections,
          sectionIndex: 0,
          questionIndex: 0,
          answers: answers,
          remainingSeconds: sections.first.timeSeconds,
        );
        _startTimer();
      case Failed(failure: final failure):
        state = AmcatLoadFailed(failure);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final current = state;
    if (current is! AmcatInSection) {
      _timer?.cancel();
      return;
    }
    if (current.remainingSeconds <= 1) {
      _timer?.cancel();
      // Timer expiry bypasses the "every question answered" validation
      // entirely (`if(timeLeft<=0){ clearInterval(...); finishSection(); }`
      // — no completeness check on that path), unlike a manual finish.
      _finishSection(current.copyWith(remainingSeconds: 0));
      return;
    }
    state = current.copyWith(remainingSeconds: current.remainingSeconds - 1);
  }

  void selectAnswer(int optionIndex) {
    final current = state;
    if (current is! AmcatInSection) return;
    final sectionAnswers = List<int?>.of(current.currentSectionAnswers);
    sectionAnswers[current.questionIndex] = optionIndex;
    state = current.copyWith(
      answers: {...current.answers, current.currentSection.key: sectionAnswers},
      showValidation: false,
    );
  }

  /// Free navigation within the current section, same as OOP/Subject Quiz
  /// (`renderReviewJump`'s palette `onclick`).
  void goToQuestion(int index) {
    final current = state;
    if (current is! AmcatInSection) return;
    if (index < 0 || index >= current.currentSection.questions.length) return;
    state = current.copyWith(questionIndex: index, showValidation: false);
  }

  void previousQuestion() {
    final current = state;
    if (current is! AmcatInSection || current.questionIndex == 0) return;
    goToQuestion(current.questionIndex - 1);
  }

  /// Shared by both the "Next" and "Skip" buttons — the web's own
  /// `nextQuestion()`/`skipQuestion()` both call the identical
  /// `goForward()`, with no behavioral difference between them (verified
  /// directly; reproduced faithfully rather than inventing a distinction
  /// the web doesn't have).
  void goForward() {
    final current = state;
    if (current is! AmcatInSection) return;
    if (!current.isLastQuestionInSection) {
      goToQuestion(current.questionIndex + 1);
      return;
    }
    final firstUnanswered = current.currentSectionAnswers.indexWhere((a) => a == null);
    if (firstUnanswered != -1) {
      state = current.copyWith(questionIndex: firstUnanswered, showValidation: true);
      return;
    }
    _finishSection(current.copyWith(showValidation: false));
  }

  void _finishSection(AmcatInSection current) {
    _timer?.cancel();
    final completed = {...current.completedSectionKeys, current.currentSection.key};
    if (current.isLastSection) {
      unawaited(_submit(current.sections, current.answers));
      return;
    }
    state = AmcatSectionTransition(
      sections: current.sections,
      finishedSectionIndex: current.sectionIndex,
      answers: current.answers,
      completedSectionKeys: completed,
    );
  }

  /// "Next Task →" on the Section Completed screen — the next section is
  /// never entered automatically (`beginNextSection()` only ever fires on
  /// this explicit tap).
  void beginNextSection() {
    final current = state;
    if (current is! AmcatSectionTransition) return;
    final nextIndex = current.finishedSectionIndex + 1;
    state = AmcatInSection(
      sections: current.sections,
      sectionIndex: nextIndex,
      questionIndex: 0,
      answers: current.answers,
      remainingSeconds: current.sections[nextIndex].timeSeconds,
      completedSectionKeys: current.completedSectionKeys,
    );
    _startTimer();
  }

  Future<void> _submit(List<AmcatSection> sections, Map<String, List<int?>> answers) async {
    state = AmcatSubmitting(sections: sections, answers: answers);
    final padded = {
      for (final sec in sections)
        for (var i = 0; i < sec.questions.length; i++) sec.questions[i].id: answers[sec.key]![i] ?? -1,
    };
    final result = await _repository.submit(padded);
    switch (result) {
      case Success(value: final submissionResult):
        state = AmcatSubmitted(sections: sections, answers: answers, result: submissionResult);
      case Failed(failure: final failure):
        state = AmcatSubmitFailed(sections: sections, answers: answers, failure: failure);
    }
  }

  Future<void> retrySubmit() async {
    final current = state;
    if (current is! AmcatSubmitFailed) return;
    await _submit(current.sections, current.answers);
  }

  /// "Exit Test" from inside the exam (`confirmExit()`) — the web fully
  /// discards progress and returns to the landing page, not a partial
  /// state; this mirrors that exactly.
  void exitTest() {
    _timer?.cancel();
    state = const AmcatLanding();
  }

  /// "Retake Test" from the result screen — the web does a full
  /// `location.reload()`, landing back on the Exam Structure screen (not
  /// straight back into a fresh exam like OOP's "Take another test").
  void backToLanding() {
    _timer?.cancel();
    state = const AmcatLanding();
  }
}

final amcatControllerProvider = NotifierProvider<AmcatController, AmcatState>(AmcatController.new);

/// W023 — a second, independent controller instance for CoCubes (never
/// shares state with the AMCAT one), reusing this exact same class.
final cocubesControllerProvider = NotifierProvider<AmcatController, AmcatState>(
  () => AmcatController(variant: AmcatVariant.cocubes),
);
