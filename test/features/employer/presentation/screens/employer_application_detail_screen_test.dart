import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/media/media_url_resolver.dart';
import 'package:career_buddy_lms/core/media/protected_media_download_controller.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_application_detail.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_application_detail_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_application_detail_providers.dart';
import 'package:career_buddy_lms/features/employer/presentation/screens/employer_application_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(username: 'acmehr', isEmployer: true);

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async => throw UnimplementedError();
}

class _FakeRepository implements EmployerApplicationDetailRepository {
  _FakeRepository(this.result);

  Result<EmployerApplicationDetail> result;

  @override
  Future<Result<EmployerApplicationDetail>> getApplicationDetail(int applicationId) async => result;

  @override
  Future<Result<void>> updateStatus({
    required int applicationId,
    required String status,
    required String employerNotes,
  }) async => const Success(null);
}

/// Avoids exercising the real `path_provider`/`url_launcher` plugins (no
/// platform channel is registered in a widget test).
class _FakeProtectedMediaDownloadController extends ProtectedMediaDownloadController {
  _FakeProtectedMediaDownloadController(super.resolvedUrl);

  int callCount = 0;
  String? lastFilename;

  @override
  Future<void> downloadAndOpen(String filename) async {
    callCount++;
    lastFilename = filename;
  }
}

const _detail = EmployerApplicationDetail(
  applicantName: 'Priya Sharma',
  jobTitle: 'Senior Flutter Developer',
  applicantEmail: 'priya@example.com',
  applicantPhone: '+919876543210',
  yearsExperience: 5,
  currentCompany: 'Acme Corp',
  currentSalary: '₹45000.00 LPA',
  expectedSalary: '₹60000.00 LPA',
  resumeUrl: '/media/resumes/priya.pdf',
  coverLetter: null,
  interviewScore: 82,
  interviewVideoUrl: '/media/interview_videos/priya_session.webm',
  interviewRecordedAt: '29 Sep 2026',
  status: 'applied',
  employerNotes: '',
  appliedAt: '01 Sep 2026',
);

void main() {
  group('EmployerApplicationDetailScreen', () {
    testWidgets('tapping "View Resume Document" downloads it through the authenticated controller', (tester) async {
      final resolvedResumeUrl = resolveMediaUrl(_detail.resumeUrl)!;
      final fakeResumeDownload = _FakeProtectedMediaDownloadController(resolvedResumeUrl);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            employerApplicationDetailRepositoryProvider.overrideWithValue(_FakeRepository(const Success(_detail))),
            protectedMediaDownloadControllerProvider(resolvedResumeUrl).overrideWith(() => fakeResumeDownload),
          ],
          child: const MaterialApp(home: EmployerApplicationDetailScreen(applicationId: 1)),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('View Resume Document'));
      await tester.pump();

      expect(fakeResumeDownload.callCount, 1);
      expect(fakeResumeDownload.lastFilename, 'priya.pdf');
    });

    testWidgets('tapping "Open Recording" downloads the interview video through the authenticated controller', (
      tester,
    ) async {
      final resolvedResumeUrl = resolveMediaUrl(_detail.resumeUrl)!;
      final resolvedVideoUrl = resolveMediaUrl(_detail.interviewVideoUrl)!;
      final fakeVideoDownload = _FakeProtectedMediaDownloadController(resolvedVideoUrl);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            employerApplicationDetailRepositoryProvider.overrideWithValue(_FakeRepository(const Success(_detail))),
            protectedMediaDownloadControllerProvider(
              resolvedResumeUrl,
            ).overrideWith(() => _FakeProtectedMediaDownloadController(resolvedResumeUrl)),
            protectedMediaDownloadControllerProvider(resolvedVideoUrl).overrideWith(() => fakeVideoDownload),
          ],
          child: const MaterialApp(home: EmployerApplicationDetailScreen(applicationId: 1)),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Open Recording'));
      await tester.pump();

      expect(fakeVideoDownload.callCount, 1);
      expect(fakeVideoDownload.lastFilename, 'priya_session.webm');
    });

    testWidgets('shows a retryable error view for a fetch failure', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            employerApplicationDetailRepositoryProvider.overrideWithValue(
              _FakeRepository(const Failed(ServerFailure())),
            ),
          ],
          child: const MaterialApp(home: EmployerApplicationDetailScreen(applicationId: 1)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Could not load this application.'), findsOneWidget);
    });
  });
}
