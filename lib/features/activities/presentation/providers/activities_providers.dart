import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_activities_repository.dart';
import '../../../../core/demo/demo_mcq_exercise_repository.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/activities_remote_datasource.dart';
import '../../data/datasources/mcq_exercise_remote_datasource.dart';
import '../../data/repositories/activities_repository_impl.dart';
import '../../data/repositories/mcq_exercise_repository_impl.dart';
import '../../domain/repositories/activities_repository.dart';
import '../../domain/repositories/mcq_exercise_repository.dart';

final activitiesRemoteDataSourceProvider = Provider<ActivitiesRemoteDataSource>((ref) {
  return ActivitiesRemoteDataSource(ref.watch(apiClientProvider));
});

final activitiesRepositoryProvider = Provider<ActivitiesRepository>((ref) {
  if (ref.watch(demoModeActiveProvider)) return DemoActivitiesRepository();
  return ActivitiesRepositoryImpl(ref.watch(activitiesRemoteDataSourceProvider));
});

final mcqExerciseRemoteDataSourceProvider = Provider<McqExerciseRemoteDataSource>((ref) {
  return McqExerciseRemoteDataSource(ref.watch(apiClientProvider));
});

final mcqExerciseRepositoryProvider = Provider<McqExerciseRepository>((ref) {
  if (ref.watch(demoModeActiveProvider)) return DemoMcqExerciseRepository();
  return McqExerciseRepositoryImpl(ref.watch(mcqExerciseRemoteDataSourceProvider));
});
