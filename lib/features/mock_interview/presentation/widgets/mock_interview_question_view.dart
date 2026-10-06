import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/malpractice.dart';
import '../controllers/mock_interview_controller.dart';
import '../providers/mock_interview_providers.dart';

/// Mirrors `templates/resume_interview.html`'s main chat/answer UI: the
/// current question, the real server-seeded 30s countdown
/// (`#answer-timer-badge`), progress ("Question N/20"), and an answer input.
/// Answering is typed text at minimum (always available); on-device
/// `speech_to_text` is layered on top as a bonus voice-to-text input when
/// the plugin is actually available on the device — this app does **not**
/// call `resume_transcribe_answer` (server-side Sarvam STT), see
/// `ApiEndpoints`'s doc comment for why.
///
/// The blocking violation-warning dialog mirrors the web's own
/// `#malpractice-warning-overlay` (`templates/resume_interview.html:1609-
/// 1638`) — every recorded violation shows it, and the candidate must tap
/// through before answering again.
class MockInterviewQuestionView extends ConsumerStatefulWidget {
  const MockInterviewQuestionView({required this.state, super.key});

  final MockInterviewQuestionActive state;

  @override
  ConsumerState<MockInterviewQuestionView> createState() => _MockInterviewQuestionViewState();
}

class _MockInterviewQuestionViewState extends ConsumerState<MockInterviewQuestionView> {
  late final TextEditingController _textController;
  stt.SpeechToText? _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  Object? _shownWarning;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.state.answerText);
    unawaited(_initSpeech());
  }

  Future<void> _initSpeech() async {
    try {
      final speech = stt.SpeechToText();
      final available = await speech.initialize();
      if (!mounted) return;
      setState(() {
        _speech = speech;
        _speechAvailable = available;
      });
    } catch (_) {
      // The plugin is unavailable (no platform implementation, permission
      // permanently denied, etc.) — voice input is simply hidden; typed
      // answers are always available regardless.
      if (!mounted) return;
      setState(() => _speechAvailable = false);
    }
  }

  @override
  void didUpdateWidget(covariant MockInterviewQuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.question.id != widget.state.question.id) {
      _textController.text = '';
    }
  }

  Future<void> _toggleListening() async {
    final speech = _speech;
    if (speech == null || !_speechAvailable) return;
    if (_isListening) {
      await speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await speech.listen(
      onResult: (result) {
        _textController.text = result.recognizedWords;
        _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
        ref.read(mockInterviewControllerProvider.notifier).updateAnswerText(_textController.text);
        if (result.finalResult && mounted) setState(() => _isListening = false);
      },
    );
  }

  @override
  void dispose() {
    _speech?.stop();
    _textController.dispose();
    super.dispose();
  }

  void _maybeShowViolationDialog(BuildContext context, MockInterviewController controller) {
    final warning = widget.state.activeWarning;
    if (warning == null || identical(warning, _shownWarning)) return;
    _shownWarning = warning;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            warning.action == ViolationAction.flagged
                ? 'Suspicious Activity Detected — Flagged for Review'
                : 'Suspicious Activity Detected',
          ),
          content: Text(
            'Leaving the interview screen or losing focus is not permitted during the interview.\n\n'
            'Warning ${warning.count}/3',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                controller.acknowledgeWarning();
              },
              child: const Text('I Understand, Continue'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = ref.read(mockInterviewControllerProvider.notifier);
    _maybeShowViolationDialog(context, controller);

    final urgent = state.secondsRemaining <= 10;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(label: Text('Question ${state.question.currentNumber}/${state.question.totalCount}')),
              Chip(
                key: const Key('answer-timer-badge'),
                label: Text('${state.secondsRemaining}s'),
                backgroundColor: urgent ? Colors.red.shade100 : Colors.blue.shade50,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(state.question.topic, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Text(
            state.question.text,
            key: const Key('question-text'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              key: const Key('answer-text-field'),
              controller: _textController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              enabled: !state.isSubmitting,
              decoration: InputDecoration(
                hintText: state.question.isCoding ? 'Write your SQL query / code here…' : 'Type your answer here…',
                border: const OutlineInputBorder(),
              ),
              onChanged: controller.updateAnswerText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_speechAvailable)
                IconButton(
                  key: const Key('mic-button'),
                  icon: Icon(_isListening ? Icons.stop_circle : Icons.mic),
                  color: _isListening ? Colors.red : null,
                  onPressed: state.isSubmitting ? null : _toggleListening,
                ),
              Expanded(
                child: AppButton(
                  label: state.isSubmitting ? 'Submitting…' : 'Submit Answer',
                  icon: Icons.send,
                  isLoading: state.isSubmitting,
                  onPressed: state.isSubmitting ? null : controller.submitAnswer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
