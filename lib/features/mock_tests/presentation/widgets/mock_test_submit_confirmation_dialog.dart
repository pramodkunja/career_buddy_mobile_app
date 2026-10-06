import 'package:flutter/material.dart';

/// Mirrors `submitExam`'s manual-submit confirmation
/// (`005 oop-mastery.html:2723-2728`, `examConfirm('Submit test?', ...)`) —
/// only shown for a manual "Submit Test" tap, never for an auto-submit
/// (timer expiry), exactly matching the web's `if(!auto){...}` gate. Returns
/// `true` if the user confirmed.
Future<bool> showMockTestSubmitConfirmationDialog(BuildContext context, {required int unansweredCount}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Submit test?'),
      content: Text(
        unansweredCount > 0
            ? "You have $unansweredCount unanswered question(s). Once submitted, you can't change your answers."
            : "Once submitted, you can't change your answers.",
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Submit test')),
      ],
    ),
  );
  return confirmed ?? false;
}
