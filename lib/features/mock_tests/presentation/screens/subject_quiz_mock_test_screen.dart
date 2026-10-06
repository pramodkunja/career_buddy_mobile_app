import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/mock_test_controller.dart';
import '../widgets/mock_quiz_scaffold.dart';

/// W021 — Subject Quiz (DSA, Python, DevOps, …). [subject] is the backend
/// slug (`/activities/quiz/<subject>/...`) and [title] is that subject's
/// display name, both from `kQuizSubjects`.
///
/// A thin wrapper around the shared [MockQuizScaffold] — see its doc
/// comment for the full verification that Subject Quiz shares W020's exact
/// UI/behavior contract. Uses [subjectQuizControllerProvider], a
/// per-subject family instance of the same [MockTestController] class
/// [OopMasteryMockTestScreen] uses, so switching subjects never shares
/// timer/answer state.
class SubjectQuizMockTestScreen extends ConsumerWidget {
  const SubjectQuizMockTestScreen({required this.subject, required this.title, super.key});

  final String subject;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = subjectQuizControllerProvider(subject);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return MockQuizScaffold(title: title, state: state, controller: controller);
  }
}
