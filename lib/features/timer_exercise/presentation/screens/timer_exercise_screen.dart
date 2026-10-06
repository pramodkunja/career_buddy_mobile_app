import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/activity_hero_colors.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loader.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/exercise_hero.dart';
import '../../../activities/presentation/controllers/sub_activity_detail_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/timer_exercise.dart';
import '../controllers/timer_exercise_controller.dart';
import '../timer_exercise_route_args.dart';
import '../widgets/timer_exercise_in_progress_body.dart';
import '../widgets/timer_exercise_result_view.dart';

/// Timer ("Timed Activity") exercise-taking screen. Same reasoning as
/// `GenericWritingScreen`/`MatchingExerciseScreen`: reads via HTML
/// extraction (no JSON API exists for this `exercise_type`) and submits
/// through the existing, generic `submit_exercise` POST unchanged. The
/// capture mechanism is on-device speech-to-text (`TimerSpeechService`)
/// rather than a typed textarea — the genuine native equivalent of the
/// web's own browser `SpeechRecognition` API.
class TimerExerciseScreen extends ConsumerWidget {
  const TimerExerciseScreen({
    required this.exerciseId,
    required this.args,
    super.key,
  });

  final int exerciseId;
  final TimerExerciseRouteArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = timerExerciseControllerProvider((
      exerciseId,
      args.title,
      args.order,
    ));
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<TimerExerciseState>(provider, (previous, next) {
      final loadFailure = next is TimerExerciseLoadFailed ? next.failure : null;
      if (loadFailure is UnauthorizedFailure) {
        ref.read(authControllerProvider.notifier).logout();
      }
    });

    final exercise = switch (state) {
      TimerExerciseInProgress(:final exercise) => exercise,
      TimerExerciseSubmitted(:final exercise) => exercise,
      _ => null,
    };
    final (heroStart, _) =
        resolveActivityHeroGradient(exercise?.heroMeta?.colorSlug) ??
        kDefaultActivityHeroGradient;

    return Scaffold(
      // `.exercise-hero` replaces the bare AppBar title once loaded — same
      // reasoning as `GenericWritingScreen`.
      appBar: AppBar(
        title: exercise == null ? Text(args.title) : null,
        backgroundColor: exercise == null ? null : heroStart,
        foregroundColor: exercise == null ? null : Colors.white,
        elevation: exercise == null ? null : 0,
      ),
      body: Stack(
        children: [
          switch (state) {
            TimerExerciseLoading() => const AppLoader(
              message: 'Loading exercise...',
            ),
            TimerExerciseLoadFailed(:final failure)
                when failure is! UnauthorizedFailure =>
              AppErrorView(
                message: failure.message,
                onRetry: controller.retryLoad,
              ),
            TimerExerciseLoadFailed() => const AppLoader(),
            TimerExerciseInProgress() => Column(
              children: [
                _Hero(exercise: state.exercise),
                Expanded(
                  child: TimerExerciseInProgressBody(
                    state: state,
                    controller: controller,
                    previousAttempt: args.previousAttempt,
                  ),
                ),
              ],
            ),
            TimerExerciseSubmitted(:final exercise, :final result) => Column(
              children: [
                _Hero(exercise: exercise),
                Expanded(
                  child: TimerExerciseResultView(
                    exercise: exercise,
                    result: result,
                    onTryAgain: controller.tryAgain,
                    // See MatchingExerciseScreen's onBackToSubActivity for
                    // why this pops onto the already-loaded screen instead
                    // of pushReplacement-ing a fresh one.
                    onBackToSubActivity: () {
                      ref.invalidate(subActivityDetailControllerProvider((activityId: args.activityId, subActivityId: args.subActivityId)));
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          },
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.exercise});

  final TimerExercise exercise;

  @override
  Widget build(BuildContext context) {
    return ExerciseHero(
      activityTitle: exercise.heroMeta?.activityTitle ?? '',
      subActivityTitle: exercise.heroMeta?.subActivityTitle ?? '',
      exerciseTitle: exercise.title,
      // `EXERCISE_TYPE_CHOICES`'s exact display label
      // (`activities/models.py:27`) — `get_exercise_type_display()`.
      exerciseTypeDisplay: 'Timed Activity',
      icon: Icons.timer_outlined,
      iconTint: const Color(
        0x4DEF4444,
      ), // rgba(239,68,68,.3) — matches ExerciseTypeStyle's timer gradient
      heroColorSlug: exercise.heroMeta?.colorSlug,
    );
  }
}
