import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/activity_hero_colors.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/exercise_hero.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/mcq_exercise.dart';
import '../controllers/mcq_exercise_controller.dart';
import '../widgets/mcq_in_progress_body.dart';
import '../widgets/mcq_result_view.dart';

/// MCQ-only exercise-taking screen. See `McqSubmissionResult`'s doc
/// comment — the client self-grades, the same trust model every other
/// HTML-scraped exercise type already uses.
class McqExerciseScreen extends ConsumerStatefulWidget {
  const McqExerciseScreen({required this.exerciseId, super.key});

  final int exerciseId;

  @override
  ConsumerState<McqExerciseScreen> createState() => _McqExerciseScreenState();
}

class _McqExerciseScreenState extends ConsumerState<McqExerciseScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = mcqExerciseControllerProvider(widget.exerciseId);
    final state = ref.watch(provider);

    ref.listen<McqExerciseState>(provider, (previous, next) {
      final loadFailure = next is McqExerciseLoadFailed ? next.failure : null;
      if (loadFailure is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    final exercise = _exerciseFor(state);
    final (heroStart, _) =
        resolveActivityHeroGradient(exercise?.heroMeta?.colorSlug) ?? kDefaultActivityHeroGradient;

    return Scaffold(
      // `.exercise-hero` (`templates/activities/exercise.html:14-103`)
      // replaces the bare AppBar title once the exercise has loaded —
      // same reasoning as `MatchingExerciseScreen`.
      appBar: AppBar(
        title: exercise == null ? const Text('Exercise') : null,
        backgroundColor: exercise == null ? null : heroStart,
        foregroundColor: exercise == null ? null : Colors.white,
        elevation: exercise == null ? null : 0,
      ),
      body: Stack(
        children: [
          switch (state) {
            McqExerciseLoading() => const AppLoader(message: 'Loading exercise...'),
            McqExerciseLoadFailed(:final failure) when failure is! UnauthorizedFailure => AppErrorView(
              message: failure.message,
              onRetry: () => ref.read(provider.notifier).retryLoad(),
            ),
            McqExerciseLoadFailed() => const AppLoader(),
            McqExerciseInProgress() => Column(
              children: [
                _Hero(exercise: state.exercise),
                Expanded(
                  child: McqInProgressBody(
                    state: state,
                    currentIndex: _currentIndex.clamp(0, state.exercise.questions.length - 1),
                    onIndexChanged: (i) => setState(() => _currentIndex = i),
                    controller: ref.read(provider.notifier),
                  ),
                ),
              ],
            ),
            McqExerciseSubmitted(:final exercise, :final result) => Column(
              children: [
                _Hero(exercise: exercise),
                Expanded(child: McqResultView(exercise: exercise, result: result)),
              ],
            ),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }

  McqExercise? _exerciseFor(McqExerciseState state) {
    return switch (state) {
      McqExerciseInProgress(:final exercise) => exercise,
      McqExerciseSubmitted(:final exercise) => exercise,
      _ => null,
    };
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.exercise});

  final McqExercise exercise;

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = exerciseHeroIconFor('mcq');
    return ExerciseHero(
      activityTitle: exercise.heroMeta?.activityTitle ?? '',
      subActivityTitle: exercise.heroMeta?.subActivityTitle ?? '',
      exerciseTitle: exercise.title,
      exerciseTypeDisplay: 'Multiple Choice',
      icon: icon,
      iconTint: tint,
      heroColorSlug: exercise.heroMeta?.colorSlug,
    );
  }
}
