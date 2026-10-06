import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/activity_detail.dart';
import '../../domain/entities/activity_list_data.dart';
import '../../domain/entities/sub_activity_detail.dart';
import '../../domain/repositories/activities_repository.dart';
import '../datasources/activities_remote_datasource.dart';

class ActivitiesRepositoryImpl implements ActivitiesRepository {
  ActivitiesRepositoryImpl(this._remote);

  final ActivitiesRemoteDataSource _remote;

  @override
  Future<Result<ActivityListData>> getActivityList({String? category}) async {
    try {
      final data = await _remote.getActivityList(category: category);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<ActivityListData>> getWorkshopModules() async {
    try {
      final data = await _remote.getWorkshopModules();
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<ActivityDetail>> getActivityDetail(int id) async {
    try {
      final data = await _remote.getActivityDetail(id);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId) async {
    try {
      final data = await _remote.getSubActivityDetail(activityId, subActivityId);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> markSubComplete(int subActivityId) async {
    try {
      await _remote.markSubComplete(subActivityId);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
