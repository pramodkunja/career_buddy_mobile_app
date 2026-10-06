import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/my_application_detail_remote_datasource.dart';
import '../../data/my_application_detail_repository_impl.dart';
import '../../domain/repositories/my_application_detail_repository.dart';

final myApplicationDetailRemoteDataSourceProvider = Provider<MyApplicationDetailRemoteDataSource>((ref) {
  return MyApplicationDetailRemoteDataSource(ref.watch(apiClientProvider));
});

final myApplicationDetailRepositoryProvider = Provider<MyApplicationDetailRepository>((ref) {
  return MyApplicationDetailRepositoryImpl(ref.watch(myApplicationDetailRemoteDataSourceProvider));
});
