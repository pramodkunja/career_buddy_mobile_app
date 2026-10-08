import 'dart:typed_data';

import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/certifications/domain/entities/certificate_info.dart';
import 'package:career_buddy_lms/features/certifications/domain/entities/certification_category.dart';
import 'package:career_buddy_lms/features/certifications/domain/entities/certification_result.dart';
import 'package:career_buddy_lms/features/certifications/domain/entities/certification_state.dart';
import 'package:career_buddy_lms/features/certifications/domain/entities/certification_subject.dart';
import 'package:career_buddy_lms/features/certifications/domain/entities/certifications_status.dart';
import 'package:career_buddy_lms/features/certifications/domain/repositories/certifications_repository.dart';
import 'package:career_buddy_lms/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:career_buddy_lms/features/certifications/presentation/widgets/certifications_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeCertificationsRepository implements CertificationsRepository {
  _FakeCertificationsRepository({
    this.statusResult,
    this.generateResult,
    this.regenerateResult,
    this.downloadResult,
  });

  Result<CertificationsStatus>? statusResult;
  Result<CertificationSubject>? generateResult;
  Result<CertificationSubject>? regenerateResult;
  Result<Uint8List>? downloadResult;

  int generateCallCount = 0;
  int regenerateCallCount = 0;

  @override
  Future<Result<CertificationsStatus>> getStatus() async => statusResult!;

  @override
  Future<Result<CertificationSubject>> generateCertificate({required String subject, required String name}) async {
    generateCallCount++;
    return generateResult!;
  }

  @override
  Future<Result<CertificationSubject>> regenerateCertificate({
    required String subject,
    required String name,
  }) async {
    regenerateCallCount++;
    return regenerateResult!;
  }

  @override
  Future<Result<Uint8List>> downloadCertificateBytes(String subject) async => downloadResult!;
}

const _notAttempted = CertificationSubject(
  subject: 'dsa',
  label: 'DSA Mastery',
  category: 'tech',
  state: CertificationState.notAttempted,
  passThreshold: 70,
  result: CertificationResult(score: null, total: null, completed: false),
  certificate: null,
  prefillName: 'Jane Doe',
  nameUrl: '/skill-up/assessment/dsa/certificate/name/',
);

const _locked = CertificationSubject(
  subject: 'python',
  label: 'Python Mastery',
  category: 'tech',
  state: CertificationState.locked,
  passThreshold: 70,
  result: CertificationResult(score: 40, total: 100, completed: true),
  certificate: null,
  prefillName: 'Jane Doe',
  nameUrl: '/skill-up/assessment/python/certificate/name/',
);

const _eligible = CertificationSubject(
  subject: 'devops',
  label: 'DevOps',
  category: 'tech',
  state: CertificationState.eligible,
  passThreshold: 70,
  result: CertificationResult(score: 80, total: 100, completed: true),
  certificate: null,
  prefillName: 'Jane Doe',
  nameUrl: '/skill-up/assessment/devops/certificate/name/',
);

final _certified = CertificationSubject(
  subject: 'english',
  label: 'English & Vocabulary',
  category: 'english',
  state: CertificationState.certified,
  passThreshold: 70,
  result: const CertificationResult(score: 90, total: 100, completed: true),
  certificate: CertificateInfo(
    certificateName: 'Jane Doe',
    score: 90,
    total: 100,
    certificateNumber: 'CB-ENGLISH-0001',
    generatedAt: DateTime(2026, 9, 20),
    downloadUrl: '/skill-up/assessment/english/certificate/download/',
    editUrl: '/skill-up/assessment/english/certificate/edit/',
  ),
  prefillName: 'Jane Doe',
  nameUrl: '/skill-up/assessment/english/certificate/name/',
);

final _fourStatesStatus = CertificationsStatus(
  categories: [
    const CertificationCategory(
      key: 'tech',
      label: 'Tech Center',
      total: 3,
      attempted: 2,
      earned: 0,
      subjects: [_notAttempted, _locked, _eligible],
    ),
    CertificationCategory(
      key: 'english',
      label: 'English & Vocabulary',
      total: 1,
      attempted: 1,
      earned: 1,
      subjects: [_certified],
    ),
  ],
  totalCount: 4,
  attemptedCount: 3,
  earnedCount: 1,
);

GoRouter _router() => GoRouter(
  initialLocation: '/certifications-test',
  routes: [
    GoRoute(
      path: '/certifications-test',
      builder: (context, state) =>
          const Scaffold(body: SingleChildScrollView(child: CertificationsSection())),
    ),
    GoRoute(
      path: RoutePaths.subjectQuizPattern,
      builder: (context, state) => Scaffold(body: Text('Quiz: ${state.pathParameters['subject']}')),
    ),
    GoRoute(
      path: RoutePaths.oopMasteryMockTest,
      builder: (context, state) => const Scaffold(body: Text('OOP Mastery Mock Test')),
    ),
    GoRoute(
      path: RoutePaths.amcatMockTest,
      builder: (context, state) => const Scaffold(body: Text('AMCAT Mock Test')),
    ),
    GoRoute(
      path: RoutePaths.cocubesMockTest,
      builder: (context, state) => const Scaffold(body: Text('CoCubes Mock Test')),
    ),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Result<CertificationsStatus> statusResult,
}) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      certificationsRepositoryProvider.overrideWithValue(
        _FakeCertificationsRepository(statusResult: statusResult),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  group('CertificationsSection — loading/error', () {
    testWidgets('shows a loader while the status fetch is in flight', (tester) async {
      final container = ProviderContainer(
        overrides: [
          certificationsRepositoryProvider.overrideWithValue(
            _FakeCertificationsRepository(statusResult: null), // never resolves before first pump
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows AppErrorView with a retry action when the fetch fails', (tester) async {
      await _pump(tester, statusResult: const Failed(NetworkFailure()));

      expect(find.text(const NetworkFailure().message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('CertificationsSection — the 4 real states', () {
    testWidgets('renders the overall summary counts from the server response', (tester) async {
      await _pump(tester, statusResult: Success(_fourStatesStatus));

      expect(find.text('4'), findsOneWidget); // total
      expect(find.text('3'), findsOneWidget); // attempted
      expect(find.text('1'), findsOneWidget); // certified/earned
    });

    testWidgets('not_attempted (tech category): shows the Not Attempted pill and a Take Assessment button', (
      tester,
    ) async {
      // `_notAttempted` is `category: 'tech'` (dsa) — the real web says
      // "Take Assessment" for Tech specifically, "Take Mock Test" for
      // every other category (confirmed live against `static/001 Career
      // Buddy/index.html`'s own `actionNoun` logic).
      await _pump(tester, statusResult: Success(_fourStatesStatus));

      expect(find.text('Not Attempted'), findsOneWidget);
      expect(find.text('Take Assessment'), findsOneWidget);
      expect(find.text('Take Mock Test'), findsNothing);
    });

    testWidgets('locked: shows the Locked pill and informational copy, with no action button', (tester) async {
      await _pump(tester, statusResult: Success(_fourStatesStatus));

      expect(find.text('Locked'), findsOneWidget);
      expect(find.textContaining('below the pass mark'), findsOneWidget);
    });

    testWidgets('eligible: shows the Eligible pill and a Generate Certificate button', (tester) async {
      await _pump(tester, statusResult: Success(_fourStatesStatus));

      expect(find.text('Eligible'), findsOneWidget);
      expect(find.text('Generate Certificate'), findsOneWidget);
    });

    testWidgets('certified: shows the Certified pill, View/Download and Edit Name & Regenerate actions', (
      tester,
    ) async {
      await _pump(tester, statusResult: Success(_fourStatesStatus));

      // "Certified" appears twice: the summary header's "Certified" stat
      // label and the subject card's state pill.
      expect(find.text('Certified'), findsNWidgets(2));
      expect(find.text('View / Download'), findsOneWidget);
      expect(find.text('Edit Name & Regenerate'), findsOneWidget);
    });

    testWidgets('tapping Take Assessment on a generic Tech subject routes to its subject quiz screen', (tester) async {
      await _pump(tester, statusResult: Success(_fourStatesStatus));

      await tester.ensureVisible(find.text('Take Assessment'));
      await tester.tap(find.text('Take Assessment'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Quiz: dsa'), findsOneWidget);
    });

    testWidgets('not_attempted (non-tech category): still shows "Take Mock Test", matching the web\'s own wording', (
      tester,
    ) async {
      const englishNotAttempted = CertificationSubject(
        subject: 'english',
        label: 'English & Vocabulary',
        category: 'english',
        state: CertificationState.notAttempted,
        passThreshold: 70,
        result: CertificationResult(score: null, total: null, completed: false),
        certificate: null,
        prefillName: 'Jane Doe',
        nameUrl: '/skill-up/assessment/english/certificate/name/',
      );
      final status = CertificationsStatus(
        categories: [
          const CertificationCategory(
            key: 'english',
            label: 'English & Vocabulary',
            total: 1,
            attempted: 0,
            earned: 0,
            subjects: [englishNotAttempted],
          ),
        ],
        totalCount: 1,
        attemptedCount: 0,
        earnedCount: 0,
      );
      await _pump(tester, statusResult: Success(status));

      expect(find.text('Take Mock Test'), findsOneWidget);
      expect(find.text('Take Assessment'), findsNothing);
    });
  });

  group('CertificationsSection — Generate Certificate dialog', () {
    testWidgets('opens pre-filled with prefillName and submits via the repository', (tester) async {
      final repo = _FakeCertificationsRepository(
        statusResult: Success(_fourStatesStatus),
        generateResult: Success(_certified),
      );
      final container = ProviderContainer(
        overrides: [certificationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Generate Certificate'));
      await tester.tap(find.text('Generate Certificate'));
      await tester.pump();

      expect(find.text('Jane Doe'), findsWidgets); // pre-filled field

      await tester.tap(find.text('Generate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.generateCallCount, 1);
    });
  });

  group('CertificationsSection — Edit Name & Regenerate dialog', () {
    testWidgets('opens pre-filled with the existing certificate name and submits via the repository', (
      tester,
    ) async {
      final repo = _FakeCertificationsRepository(
        statusResult: Success(_fourStatesStatus),
        regenerateResult: Success(_certified),
        downloadResult: Success(Uint8List(0)),
      );
      final container = ProviderContainer(
        overrides: [certificationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Edit Name & Regenerate'));
      await tester.tap(find.text('Edit Name & Regenerate'));
      await tester.pump();

      expect(find.text('Jane Doe'), findsWidgets); // pre-filled from the existing certificate name

      await tester.tap(find.text('Save & Regenerate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.regenerateCallCount, 1);
    });
  });
}
