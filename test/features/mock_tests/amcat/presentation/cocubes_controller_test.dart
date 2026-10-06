import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/entities/amcat_question.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/entities/amcat_section.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/entities/amcat_submission_result.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/repositories/amcat_repository.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/presentation/controllers/amcat_controller.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/presentation/providers/amcat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `AmcatController` state machine itself (timer, section gating,
/// transitions, submit/retry) is already exhaustively covered by
/// `amcat_controller_test.dart` — reused unchanged for CoCubes (see
/// `AmcatState`'s doc comment). This file's only job is the one thing
/// that's actually new: proving `cocubesControllerProvider` reads from
/// `cocubesRepositoryProvider`, not the AMCAT-specific one.
class _FakeAmcatRepository implements AmcatRepository {
  _FakeAmcatRepository(this.label, {this.getResult});
  final String label;
  Result<List<AmcatSection>>? getResult;

  @override
  Future<Result<List<AmcatSection>>> getSections() async => getResult!;

  @override
  Future<Result<AmcatSubmissionResult>> submit(Map<int, int> answers) async => throw UnimplementedError();
}

void main() {
  test('cocubesControllerProvider reads from cocubesRepositoryProvider, never the AMCAT-specific one', () async {
    final cocubesSections = [
      AmcatSection(key: 'aptitude', name: 'Aptitude', timeSeconds: 3000, questions: [
        const AmcatQuestion(id: 1, questionText: 'Q', options: ['A', 'B', 'C', 'D']),
      ]),
    ];
    final amcatSections = [
      AmcatSection(key: 'quant', name: 'Quantitative Ability', timeSeconds: 1080, questions: [
        const AmcatQuestion(id: 2, questionText: 'Q', options: ['A', 'B', 'C', 'D']),
      ]),
    ];
    final cocubesRepo = _FakeAmcatRepository('cocubes', getResult: Success(cocubesSections));
    final amcatRepo = _FakeAmcatRepository('amcat', getResult: Success(amcatSections));
    final container = ProviderContainer(
      overrides: [
        cocubesRepositoryProvider.overrideWithValue(cocubesRepo),
        amcatRepositoryProvider.overrideWithValue(amcatRepo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(cocubesControllerProvider.notifier).start();

    final state = container.read(cocubesControllerProvider) as AmcatInSection;
    expect(state.sections.single.key, 'aptitude'); // proves it used cocubesRepo, not amcatRepo
  });

  test('cocubesControllerProvider and amcatControllerProvider are independent — starting one leaves the other untouched', () async {
    final container = ProviderContainer(
      overrides: [
        cocubesRepositoryProvider.overrideWithValue(
          _FakeAmcatRepository('cocubes', getResult: Success([AmcatSection(key: 'aptitude', name: 'Aptitude', timeSeconds: 3000, questions: const [])])),
        ),
        // amcatControllerProvider's build() eagerly resolves its own
        // repository even without start() being called, so this needs a
        // fake too (any repository — it's never invoked in this test).
        amcatRepositoryProvider.overrideWithValue(_FakeAmcatRepository('amcat')),
      ],
    );
    addTearDown(container.dispose);

    await container.read(cocubesControllerProvider.notifier).start();

    expect(container.read(cocubesControllerProvider), isA<AmcatInSection>());
    expect(container.read(amcatControllerProvider), isA<AmcatLanding>());
  });
}
