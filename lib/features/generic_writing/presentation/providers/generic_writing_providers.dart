import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_generic_writing_repository.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/generic_writing_remote_datasource.dart';
import '../../data/repositories/generic_writing_repository_impl.dart';
import '../../domain/repositories/generic_writing_repository.dart';

final genericWritingRemoteDataSourceProvider = Provider<GenericWritingRemoteDataSource>((ref) {
  return GenericWritingRemoteDataSource(ref.watch(apiClientProvider));
});

final genericWritingRepositoryProvider = Provider<GenericWritingRepository>((ref) {
  if (ref.watch(demoModeActiveProvider)) return DemoGenericWritingRepository();
  return GenericWritingRepositoryImpl(ref.watch(genericWritingRemoteDataSourceProvider));
});
