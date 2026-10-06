import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_bingo_exercise_repository.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/bingo_exercise_remote_datasource.dart';
import '../../data/repositories/bingo_exercise_repository_impl.dart';
import '../../domain/repositories/bingo_exercise_repository.dart';

final bingoExerciseRemoteDataSourceProvider = Provider<BingoExerciseRemoteDataSource>((ref) {
  return BingoExerciseRemoteDataSource(ref.watch(apiClientProvider));
});

final bingoExerciseRepositoryProvider = Provider<BingoExerciseRepository>((ref) {
  if (ref.watch(demoModeActiveProvider)) return DemoBingoExerciseRepository();
  return BingoExerciseRepositoryImpl(ref.watch(bingoExerciseRemoteDataSourceProvider));
});
