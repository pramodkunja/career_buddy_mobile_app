import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_matching_exercise_repository.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/matching_exercise_remote_datasource.dart';
import '../../data/repositories/matching_exercise_repository_impl.dart';
import '../../domain/repositories/matching_exercise_repository.dart';

final matchingExerciseRemoteDataSourceProvider = Provider<MatchingExerciseRemoteDataSource>((ref) {
  return MatchingExerciseRemoteDataSource(ref.watch(apiClientProvider));
});

final matchingExerciseRepositoryProvider = Provider<MatchingExerciseRepository>((ref) {
  if (ref.watch(demoModeActiveProvider)) return DemoMatchingExerciseRepository();
  return MatchingExerciseRepositoryImpl(ref.watch(matchingExerciseRemoteDataSourceProvider));
});
