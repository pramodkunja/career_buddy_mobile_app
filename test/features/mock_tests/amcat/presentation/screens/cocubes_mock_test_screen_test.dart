import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/entities/amcat_question.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/entities/amcat_section.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/entities/amcat_submission_result.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/repositories/amcat_repository.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/presentation/providers/amcat_providers.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/presentation/screens/cocubes_mock_test_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<AmcatSection> _sections({int sectionCount = 2, int questionsPerSection = 1}) => List.generate(
  sectionCount,
  (s) => AmcatSection(
    key: 'sec$s',
    name: 'Section ${s + 1} Name',
    timeSeconds: 600,
    questions: List.generate(
      questionsPerSection,
      (q) => AmcatQuestion(
        id: s * 100 + q,
        questionText: 'This is question ${q + 1} for section ${s + 1}.',
        options: const ['First option here', 'Second option here', 'Option C', 'Option D'],
      ),
    ),
  ),
);

/// `BuddyChatbotOverlay` (now part of every screen's `Scaffold`, per the
/// web's unconditional `{% include 'includes/aria_assistant.html' %}`)
/// reads `authControllerProvider` for its greeting, which otherwise falls
/// through to `authRepositoryProvider` -> `authRemoteDataSourceProvider` ->
/// `apiClientProvider` (unimplemented outside `main()`). Overriding
/// `authRepositoryProvider` directly avoids that without this file's own
/// tests needing to care about auth at all.
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

class _FakeAmcatRepository implements AmcatRepository {
  _FakeAmcatRepository({this.getResult, this.submitResult});

  Result<List<AmcatSection>>? getResult;
  Result<AmcatSubmissionResult>? submitResult;

  @override
  Future<Result<List<AmcatSection>>> getSections() async => getResult!;

  @override
  Future<Result<AmcatSubmissionResult>> submit(Map<int, int> answers) async => submitResult!;
}

Future<void> _pump(WidgetTester tester, AmcatRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cocubesRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: const MaterialApp(home: CocubesMockTestScreen()),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable));
  // Never pumpAndSettle() once `BuddyChatbotOverlay` is in the tree — its
  // launcher's float animation repeats forever and would hang this.
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _agreeAndStart(WidgetTester tester) async {
  await _scrollTo(tester, find.text('Start Mock Test'));
  await tester.tap(find.text('Start Mock Test'));
  await tester.pump();
  await _scrollTo(tester, find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
  await _scrollTo(tester, find.widgetWithText(ElevatedButton, 'Start Test'));
  await tester.tap(find.widgetWithText(ElevatedButton, 'Start Test'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('landing shows CoCubes-specific title, subtitle, and 4-section structure (not AMCAT\'s)', (tester) async {
    await _pump(tester, _FakeAmcatRepository());

    expect(find.text('🧪 CoCubes Mock Test'), findsOneWidget);
    expect(find.textContaining('Aptitude, Technical/Domain, Computer'), findsOneWidget);
    expect(find.text('Aptitude'), findsOneWidget);
    expect(find.text('50 Q · 50 min'), findsWidgets); // Aptitude and Programming both show this
    expect(find.text('Quantitative Ability'), findsNothing); // AMCAT's own section must not leak in
  });

  testWidgets('instructions show the CoCubes-specific section count and Programming-scoring bullet', (tester) async {
    await _pump(tester, _FakeAmcatRepository());

    await _scrollTo(tester, find.text('Start Mock Test'));
    await tester.tap(find.text('Start Mock Test'));
    await tester.pump();

    expect(
      find.textContaining('The test consists of 4 sections: Aptitude, Technical / Domain (CSE-IT)'),
      findsOneWidget,
    );
    expect(find.textContaining('The Programming section is multiple-choice'), findsOneWidget);
    expect(find.textContaining('Personality Inventory'), findsNothing); // AMCAT's bullet must not leak in
  });

  testWidgets('starting the exam shows the section name as the AppBar title', (tester) async {
    await _pump(tester, _FakeAmcatRepository(getResult: Success(_sections())));

    await _agreeAndStart(tester);

    expect(find.text('Section 1 Name'), findsWidgets);
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _unmount(tester);
  });

  testWidgets('finishing the last section submits and shows the CoCubes-specific "Overall Score (MCQ · …)" label', (tester) async {
    final result = const AmcatSubmissionResult(
      score: 2,
      total: 2,
      sectionScores: {
        'sec0': AmcatSectionScore(name: 'Section 1 Name', correct: 1, total: 1),
        'sec1': AmcatSectionScore(name: 'Section 2 Name', correct: 1, total: 1),
      },
      questionResults: {
        0: AmcatQuestionResult(isCorrect: true, correctAnswerIndex: 0),
        100: AmcatQuestionResult(isCorrect: true, correctAnswerIndex: 0),
      },
    );
    await _pump(tester, _FakeAmcatRepository(getResult: Success(_sections()), submitResult: Success(result)));
    await _agreeAndStart(tester);

    await _scrollTo(tester, find.text('First option here'));
    await tester.tap(find.text('First option here'));
    await tester.pump();
    await _scrollTo(tester, find.text('Submit Section'));
    await tester.tap(find.text('Submit Section'));
    await tester.pump();
    await _scrollTo(tester, find.text('Next Task'));
    await tester.tap(find.text('Next Task'));
    await tester.pump();
    await _scrollTo(tester, find.text('First option here'));
    await tester.tap(find.text('First option here'));
    await tester.pump();
    await _scrollTo(tester, find.text('Submit Section'));
    await tester.tap(find.text('Submit Section'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('📊 Your Results'), findsOneWidget);
    expect(find.text('Overall Score (MCQ · 2/2)'), findsOneWidget);
    expect(find.text('Overall Score (all 5 modules)'), findsNothing); // AMCAT's label must not leak in
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow at narrow phone and tablet widths', (tester) async {
    for (final size in [const Size(320, 640), const Size(1024, 1366)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, _FakeAmcatRepository(getResult: Success(_sections())));
      expect(tester.takeException(), isNull);

      await _agreeAndStart(tester);
      expect(tester.takeException(), isNull);

      await _unmount(tester);
    }
  });
}
