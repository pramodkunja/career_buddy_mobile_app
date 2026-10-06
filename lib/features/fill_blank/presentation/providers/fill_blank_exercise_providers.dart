import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_fill_blank_exercise_repository.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/fill_blank_exercise_remote_data_source.dart';
import '../../data/repositories/fill_blank_exercise_repository_impl.dart';
import '../../domain/repositories/fill_blank_exercise_repository.dart';

final fillBlankExerciseRemoteDataSourceProvider = Provider<FillBlankExerciseRemoteDataSource>((ref) {
  return FillBlankExerciseRemoteDataSource(ref.watch(apiClientProvider));
});

final fillBlankExerciseRepositoryProvider = Provider<FillBlankExerciseRepository>((ref) {
  if (ref.watch(demoModeActiveProvider)) return DemoFillBlankExerciseRepository();
  return FillBlankExerciseRepositoryImpl(ref.watch(fillBlankExerciseRemoteDataSourceProvider));
});
