import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/mock_test_controller.dart';
import '../widgets/mock_quiz_scaffold.dart';

/// W020 — OOP Mastery Mock Test. No id parameter — the backend itself has a
/// single fixed endpoint pair for this quiz (`/activities/oop-quiz/
/// questions/` and `.../submit/`), not a per-instance resource, so there is
/// nothing to parameterize the route with.
///
/// A thin wrapper around the shared [MockQuizScaffold] (also used by W021's
/// [SubjectQuizMockTestScreen]) — see that widget's doc comment for why OOP
/// Mastery and Subject Quiz share the exact same UI/behavior contract. This
/// screen still owns its own dedicated, non-family `mockTestControllerProvider`
/// (unchanged since W020) rather than going through the subject-keyed
/// family provider, since OOP Mastery isn't one of the 24 generic subjects
/// — it has its own dedicated backend endpoint pair.
class OopMasteryMockTestScreen extends ConsumerWidget {
  const OopMasteryMockTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockTestControllerProvider);
    final controller = ref.read(mockTestControllerProvider.notifier);
    return MockQuizScaffold(title: 'OOP Mastery', state: state, controller: controller);
  }
}
