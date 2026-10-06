import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/timer_exercise_remote_datasource.dart';
import '../../data/repositories/timer_exercise_repository_impl.dart';
import '../../data/services/timer_speech_service_impl.dart';
import '../../domain/repositories/timer_exercise_repository.dart';
import '../../domain/services/timer_speech_service.dart';

final timerExerciseRemoteDataSourceProvider = Provider<TimerExerciseRemoteDataSource>((ref) {
  return TimerExerciseRemoteDataSource(ref.watch(apiClientProvider));
});

/// No Demo Mode branch — unlike `GenericWritingRepository`/
/// `MatchingExerciseRepository`, `kDemoActivities` (`lib/core/demo/`)
/// seeds no `exercise_type == 'timer'` fixture at all (confirmed: no
/// `'timer'` string appears anywhere under `lib/core/demo/`), so no
/// `ExerciseTile` in Demo Mode is ever of this type and this provider is
/// never reached from it. A real (network) repository is always
/// constructed; if Demo Mode somehow did navigate here, the honest result
/// is a real network failure, not a silently fabricated exercise.
final timerExerciseRepositoryProvider = Provider<TimerExerciseRepository>((ref) {
  return TimerExerciseRepositoryImpl(ref.watch(timerExerciseRemoteDataSourceProvider));
});

final timerSpeechServiceProvider = Provider<TimerSpeechService>((ref) => TimerSpeechServiceImpl());
