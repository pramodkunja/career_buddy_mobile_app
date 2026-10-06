import 'package:career_buddy_lms/core/errors/failures.dart';
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
import 'package:career_buddy_lms/features/mock_tests/amcat/presentation/screens/amcat_mock_test_screen.dart';
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
        questionText: 'This is a reasonably long question for section ${s + 1}, question ${q + 1}.',
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
        amcatRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: const MaterialApp(home: AmcatMockTestScreen()),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// Scrolls the nearest `Scrollable` until [finder] is mounted — below-the-
/// fold content in this app's `ListView`-based screens isn't built until
/// scrolled into the viewport + cache extent (same reasoning documented
/// throughout the W020/W021 test suites).
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
  testWidgets('landing shows the exam structure; Start Mock Test gates on the instructions checkbox', (tester) async {
    await _pump(tester, _FakeAmcatRepository());

    expect(find.text('🧪 AMCAT Mock Test'), findsOneWidget);
    expect(find.text('Quantitative Ability'), findsOneWidget);
    expect(find.text('Start Test'), findsNothing); // not on the instructions screen yet

    await tester.tap(find.text('Start Mock Test'));
    await tester.pump();

    expect(find.text('📋 Exam Instructions'), findsOneWidget);
    await _scrollTo(tester, find.widgetWithText(ElevatedButton, 'Start Test'));
    final startButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Start Test'));
    expect(startButton.onPressed, isNull); // disabled until the checkbox is checked

    await _scrollTo(tester, find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await _scrollTo(tester, find.widgetWithText(ElevatedButton, 'Start Test'));
    final enabledStartButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Start Test'));
    expect(enabledStartButton.onPressed, isNotNull);
  });

  testWidgets('starting the exam loads section 1 and shows the section name as the AppBar title', (tester) async {
    await _pump(tester, _FakeAmcatRepository(getResult: Success(_sections())));

    await _agreeAndStart(tester);

    expect(find.text('Section 1 Name'), findsWidgets); // AppBar title + question eyebrow context
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _unmount(tester);
  });

  testWidgets(
    'finishing a non-final section without answering shows validation; answering then finishing shows the transition screen',
    (tester) async {
      await _pump(tester, _FakeAmcatRepository(getResult: Success(_sections())));
      await _agreeAndStart(tester);

      // Last (only) question of section 1 — Next button reads "Submit Section".
      await _scrollTo(tester, find.text('Submit Section'));
      await tester.tap(find.text('Submit Section'));
      await tester.pump();
      expect(find.text('Please answer all questions before submitting this section.'), findsOneWidget);

      await _scrollTo(tester, find.text('First option here'));
      await tester.tap(find.text('First option here'));
      await tester.pump();
      await _scrollTo(tester, find.text('Submit Section'));
      await tester.tap(find.text('Submit Section'));
      await tester.pump();

      expect(find.text('✅ Section Completed'), findsOneWidget);
      expect(find.textContaining('Section 2 Name'), findsWidgets);

      await _scrollTo(tester, find.text('Next Task'));
      await tester.tap(find.text('Next Task'));
      await tester.pump();
      expect(find.text('Question 1 of 1'), findsOneWidget);

      await _unmount(tester);
    },
  );

  testWidgets('finishing the last section submits and shows the result screen with a Retake Test action', (tester) async {
    final result = const AmcatSubmissionResult(
      score: 2,
      total: 2,
      sectionScores: {
        'sec0': AmcatSectionScore(name: 'Section 1 Name', correct: 1, total: 1),
        'sec1': AmcatSectionScore(name: 'Section 2 Name', correct: 1, total: 1),
      },
      questionResults: {0: AmcatQuestionResult(isCorrect: true, correctAnswerIndex: 0), 100: AmcatQuestionResult(isCorrect: true, correctAnswerIndex: 0)},
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
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _scrollTo(tester, find.text('Retake Test'));
    await tester.tap(find.text('Retake Test'));
    await tester.pump();

    expect(find.text('🧪 AMCAT Mock Test'), findsOneWidget); // back to landing
  });

  testWidgets('the in-exam Exit action shows a confirm dialog and returns to landing', (tester) async {
    await _pump(tester, _FakeAmcatRepository(getResult: Success(_sections())));
    await _agreeAndStart(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Exit the assessment?'), findsOneWidget);

    await tester.tap(find.text('Exit Test'));
    await tester.pump();

    expect(find.text('Start Mock Test'), findsOneWidget);
  });

  testWidgets('a load failure shows a retryable error view', (tester) async {
    await _pump(tester, _FakeAmcatRepository(getResult: const Failed(ServerFailure())));
    await _agreeAndStart(tester);

    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow at narrow phone and tablet widths on landing/instructions/exam', (tester) async {
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
