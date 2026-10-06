import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_report.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/screens/gd_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `BuddyChatbotOverlay` (now part of every screen's `Scaffold`, per the
/// web's unconditional `{% include 'includes/aria_assistant.html' %}`)
/// reads `authControllerProvider` for its greeting, which otherwise falls
/// through to `authRepositoryProvider` -> `authRemoteDataSourceProvider` ->
/// `apiClientProvider` (unimplemented outside `main()`). Overriding
/// `authRepositoryProvider` directly — same pattern as
/// `GrammarDetailScreen`'s own test doubles — avoids that without this
/// screen's own tests needing to care about auth at all.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => null;

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

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
    child: MaterialApp(home: child),
  );
}

const _report = GdReport(
  overallScore: 72,
  fluency: GdReportDimension(score: 20, feedback: 'Good pace, minor pauses.'),
  grammar: GdReportDimension(score: 15, feedback: 'A few tense errors.'),
  relevance: GdReportDimension(score: 22, feedback: 'Stayed on topic throughout.'),
  confidence: GdReportDimension(score: 15, feedback: 'Hesitant at times.'),
  strengths: ['Clear articulation', 'Good listening'],
  improvements: ['Work on grammar', 'Speak with more conviction'],
  summary: 'A solid, constructive contribution overall.',
);

void main() {
  group('GdReportScreen', () {
    testWidgets('renders the overall score, every dimension, strengths/improvements, and the summary', (tester) async {
      await tester.pumpWidget(_wrap(const GdReportScreen(report: _report)));

      expect(find.text('72', skipOffstage: false), findsOneWidget);
      expect(find.text('Fluency', skipOffstage: false), findsOneWidget);
      expect(find.text('20/25', skipOffstage: false), findsOneWidget);
      expect(find.text('Good pace, minor pauses.', skipOffstage: false), findsOneWidget);
      expect(find.text('Grammar', skipOffstage: false), findsOneWidget);
      expect(find.text('15/25', skipOffstage: false), findsWidgets);
      expect(find.text('Relevance', skipOffstage: false), findsOneWidget);
      expect(find.text('22/25', skipOffstage: false), findsOneWidget);
      expect(find.text('Confidence', skipOffstage: false), findsOneWidget);
      expect(find.text('Clear articulation', skipOffstage: false), findsOneWidget);
      expect(find.text('Good listening', skipOffstage: false), findsOneWidget);
      expect(find.text('Work on grammar', skipOffstage: false), findsOneWidget);
      expect(find.text('Speak with more conviction', skipOffstage: false), findsOneWidget);
      expect(find.text('"A solid, constructive contribution overall."', skipOffstage: false), findsOneWidget);
    });

    testWidgets('renders the degenerate "no speech detected" report shape without crashing', (tester) async {
      const noSpeechReport = GdReport(
        overallScore: 0,
        fluency: GdReportDimension(score: 0, feedback: 'No speech detected.'),
        grammar: GdReportDimension(score: 0, feedback: 'No speech detected.'),
        relevance: GdReportDimension(score: 0, feedback: 'No speech detected.'),
        confidence: GdReportDimension(score: 0, feedback: 'No speech detected.'),
        strengths: [],
        improvements: ["Try to participate by clicking 'Speak Now'"],
        summary: "We couldn't detect any spoken contributions from you.",
      );

      await tester.pumpWidget(_wrap(const GdReportScreen(report: noSpeechReport)));

      expect(find.text('0', skipOffstage: false), findsOneWidget);
      expect(find.text('No speech detected.', skipOffstage: false), findsWidgets);
      expect(find.text("Try to participate by clicking 'Speak Now'", skipOffstage: false), findsOneWidget);
    });
  });
}
