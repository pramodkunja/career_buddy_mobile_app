import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/create_resume_draft_summary.dart';
import '../domain/entities/create_resume_outcomes.dart';
import '../domain/entities/create_resume_state.dart';
import '../domain/repositories/create_resume_repository.dart';
import 'create_resume_remote_datasource.dart';

class CreateResumeRepositoryImpl implements CreateResumeRepository {
  CreateResumeRepositoryImpl(this._remote);

  final CreateResumeRemoteDataSource _remote;

  @override
  Future<Result<CreateResumePreviewOutcome>> preview(
    CreateResumeFormState state,
  ) async {
    try {
      return Success(await _remote.preview(state));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<CreateResumePagePreviewOutcome>> pagePreview(
    CreateResumeFormState state,
  ) async {
    try {
      return Success(await _remote.pagePreview(state));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<CreateResumePdfOutcome>> generatePdf(
    CreateResumeFormState state,
  ) async {
    try {
      return Success(await _remote.generatePdf(state));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<List<CreateResumeDraftSummary>>> listDrafts() async {
    try {
      return Success(await _remote.listDrafts());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<CreateResumeFormState>> loadDraft(int id) async {
    try {
      return Success(await _remote.loadDraft(id));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<int>> saveDraft(CreateResumeFormState state) async {
    try {
      return Success(await _remote.saveDraft(state));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> deleteDraft(int id) async {
    try {
      await _remote.deleteDraft(id);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
