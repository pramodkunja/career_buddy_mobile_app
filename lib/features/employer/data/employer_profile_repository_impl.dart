import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/employer_profile_form.dart';
import '../domain/repositories/employer_profile_repository.dart';
import 'employer_profile_remote_datasource.dart';

class EmployerProfileRepositoryImpl implements EmployerProfileRepository {
  EmployerProfileRepositoryImpl(this._remote);

  final EmployerProfileRemoteDataSource _remote;

  @override
  Future<Result<EmployerProfileFormData>> getProfileForm({required bool isCreate}) async {
    try {
      return Success(await _remote.getProfileForm(isCreate: isCreate));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> updateProfile(EmployerProfileSubmission data, {required bool isCreate}) async {
    try {
      await _remote.updateProfile(data, isCreate: isCreate);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
