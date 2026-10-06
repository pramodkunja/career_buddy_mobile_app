import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/employer_profile_form.dart';
import '../providers/employer_profile_providers.dart';

/// One instance per [isCreate] (`.family`) — `employer_profile_create` and
/// `employer_profile_edit` are genuinely separate Django views/URLs (see
/// `ApiEndpoints.employerProfileCreate`/`employerProfileEdit`'s doc
/// comments), reached from different places in Flutter (the dashboard's
/// "complete your profile" prompt vs. the nav-drawer "Company Profile"
/// item), so each gets its own fetch/submit cycle rather than sharing one.
class EmployerProfileController extends AsyncNotifier<EmployerProfileFormData> {
  EmployerProfileController(this.isCreate);

  final bool isCreate;

  @override
  Future<EmployerProfileFormData> build() async {
    final result = await ref.read(employerProfileRepositoryProvider).getProfileForm(isCreate: isCreate);
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }

  Future<Result<void>> submit(EmployerProfileSubmission data) async {
    final result = await ref.read(employerProfileRepositoryProvider).updateProfile(data, isCreate: isCreate);
    return result;
  }
}

final employerProfileControllerProvider =
    AsyncNotifierProvider.family<EmployerProfileController, EmployerProfileFormData, bool>(
      EmployerProfileController.new,
      retry: (retryCount, error) => null,
    );
