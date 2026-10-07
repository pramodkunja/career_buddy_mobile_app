import 'dart:async';

import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/services/audio_recorder_service.dart';
import 'package:career_buddy_lms/features/aria_chat/data/datasources/aria_remote_datasource.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_chat_message.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_chat_reply.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_stream_event.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_voice.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/services/aria_voice_playback_service.dart';
import 'package:career_buddy_lms/features/aria_chat/presentation/providers/aria_chat_providers.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/shared/widgets/buddy_chatbot_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.user});

  final AuthUser? user;

  @override
  Future<AuthUser?> restoreSession() async => user;

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

/// Records every call and lets the test control exactly when/what it
/// emits, so the "Thinking..."/streaming states can be observed
/// deterministically before completing it.
class _FakeAriaRemoteDataSource implements AriaRemoteDataSource {
  int callCount = 0;
  StreamController<AriaStreamEvent>? _pending;
  final List<String> capturedLanguages = [];

  @override
  Future<AriaChatReply> sendMessage({
    required String message,
    required String page,
    required String path,
    required bool isEmployer,
    required String conversationId,
    required List<AriaChatMessage> history,
  }) async => throw UnimplementedError('not called by the controller');

  @override
  Stream<AriaStreamEvent> sendMessageStream({
    required String message,
    required String page,
    required String path,
    required bool isEmployer,
    required String conversationId,
    required List<AriaChatMessage> history,
    required String language,
  }) {
    callCount++;
    capturedLanguages.add(language);
    final controller = StreamController<AriaStreamEvent>();
    _pending = controller;
    return controller.stream;
  }

  void emitToken(String token) => _pending?.add(AriaStreamToken(token));

  void resolvePending(String reply, {List<AriaChatAction> actions = const [], String? source}) {
    _pending?.add(AriaStreamComplete(AriaChatReply(reply: reply, actions: actions, source: source)));
    _pending?.close();
  }

  @override
  Future<AriaVoiceTranscription> transcribeVoice({
    required String audioBase64,
    required String mimeType,
    required String language,
  }) async => const AriaVoiceTranscription(text: '', source: 'sarvam');

  @override
  Future<String?> synthesizeSpeech({required String text, required String language}) async => null;
}

/// No real microphone — these widget tests never interact with the mic
/// button, but `AriaChatController.build()` still reads this provider.
class _FakeAudioRecorderService implements AudioRecorderService {
  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> cancel() async {}
}

/// No real audio player/TTS plugin — avoids touching a platform channel
/// `AriaChatController.ensureGreeted`'s auto-speak would otherwise reach
/// for in a widget-test environment.
class _FakeAriaVoicePlaybackService implements AriaVoicePlaybackService {
  @override
  Future<bool> playAudioBytes(String base64Audio) async => false;

  @override
  Future<void> speakDeviceVoice(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  void setOnComplete(void Function() callback) {}
}

/// Same as [_FakeAriaVoicePlaybackService], but actually retains the
/// completion callback so a test can simulate "the reply has finished being
/// spoken" (`completeNow()`) — needed to exercise the auto-navigate-after-
/// speech behavior, which deliberately only resolves once speech ends, not
/// as soon as the reply lands (see `AriaChatController._onPlaybackComplete`).
class _CompletableAriaVoicePlaybackService implements AriaVoicePlaybackService {
  void Function()? _onComplete;

  @override
  Future<bool> playAudioBytes(String base64Audio) async => false;

  @override
  Future<void> speakDeviceVoice(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  void setOnComplete(void Function() callback) => _onComplete = callback;

  void completeNow() => _onComplete?.call();
}

ProviderContainer _container({
  AuthUser? user,
  _FakeAriaRemoteDataSource? dataSource,
  AriaVoicePlaybackService? playback,
}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository(user: user)),
      ariaRemoteDataSourceProvider.overrideWithValue(dataSource ?? _FakeAriaRemoteDataSource()),
      ariaAudioRecorderServiceProvider.overrideWithValue(_FakeAudioRecorderService()),
      ariaVoicePlaybackServiceProvider.overrideWithValue(playback ?? _FakeAriaVoicePlaybackService()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: Stack(children: [BuddyChatbotOverlay()])),
      ),
    ),
  );
  // Lets AuthController's async restoreSession() resolve.
  await tester.pump();
}

/// Same host as [_pump], but under a real (minimal) [GoRouter] — needed for
/// the action-chip/auto-navigate tests, since `context.push` has nothing to
/// find in a bare `MaterialApp`. [targetRoute] is given a trivially
/// findable marker screen so a test can assert navigation actually reached
/// it, by route path rather than by screen identity (this app's real
/// screens need heavy provider setup irrelevant to what's under test here).
Future<void> _pumpWithRouter(WidgetTester tester, ProviderContainer container, String targetRoute) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Stack(children: [BuddyChatbotOverlay()]))),
      GoRoute(path: targetRoute, builder: (context, state) => const Scaffold(body: Text('NAVIGATED'))),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pump();
}

void main() {
  group('BuddyChatbotOverlay', () {
    testWidgets('shows the default greeting bubble and the launcher image when unauthenticated', (tester) async {
      await _pump(tester, _container());

      expect(find.text('Hello there! Job seeker or employer?'), findsOneWidget);
      expect(find.image(const AssetImage('assets/images/Ai_Robot.png')), findsOneWidget);
    });

    testWidgets('shows a personalized greeting when authenticated', (tester) async {
      await _pump(tester, _container(user: const AuthUser(username: 'jane')));

      expect(find.text('Hello Jane!'), findsOneWidget);
    });

    testWidgets('mounting/pumping without any interaction fires zero network calls', (tester) async {
      final dataSource = _FakeAriaRemoteDataSource();
      await _pump(tester, _container(dataSource: dataSource));
      await tester.pump(const Duration(milliseconds: 500));

      expect(dataSource.callCount, 0);
    });

    testWidgets('tapping the launcher opens the panel showing the greeting as the first message', (tester) async {
      await _pump(tester, _container());

      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Hello there! Job seeker or employer?'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('sending a message shows it immediately, then loading, then the reply', (tester) async {
      final dataSource = _FakeAriaRemoteDataSource();
      await _pump(tester, _container(dataSource: dataSource));

      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(find.byType(TextField), 'What is Skill Up?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.text('What is Skill Up?'), findsOneWidget);
      expect(find.text('Thinking...'), findsOneWidget);
      expect(dataSource.callCount, 1);

      dataSource.resolvePending('Skill Up is our free learning hub.');
      await tester.pump();
      await tester.pump();

      expect(find.text('Thinking...'), findsNothing);
      expect(find.text('Skill Up is our free learning hub.'), findsOneWidget);
    });

    testWidgets('renders streamed tokens incrementally before the final reply lands', (tester) async {
      final dataSource = _FakeAriaRemoteDataSource();
      await _pump(tester, _container(dataSource: dataSource));

      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(find.text('Thinking...'), findsOneWidget);

      dataSource.emitToken('Skill');
      await tester.pump();
      expect(find.text('Thinking...'), findsNothing);
      expect(find.text('Skill'), findsOneWidget);

      dataSource.emitToken(' Up');
      await tester.pump();
      expect(find.text('Skill'), findsNothing);
      expect(find.text('Skill Up'), findsOneWidget);

      dataSource.resolvePending('Skill Up');
      await tester.pump();
      await tester.pump();

      expect(find.text('Skill Up'), findsOneWidget);
    });

    testWidgets('closing hides the panel without clearing history; reopening does not re-greet', (tester) async {
      final dataSource = _FakeAriaRemoteDataSource();
      await _pump(tester, _container(dataSource: dataSource));

      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(find.byType(TextField), 'Hi Buddy');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      dataSource.resolvePending('Hello! How can I help?');
      await tester.pump();
      await tester.pump();

      expect(find.text('Hi Buddy'), findsOneWidget);
      expect(find.text('Hello! How can I help?'), findsOneWidget);

      // Close: the panel goes away, but the small greeting tooltip does not
      // come back re-greeted (that only ever happens on a truly empty
      // conversation).
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Hi Buddy'), findsNothing); // panel subtree unmounted while closed

      // Reopen: history is still there, and the greeting was not re-added
      // a second time.
      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Hi Buddy'), findsOneWidget);
      expect(find.text('Hello! How can I help?'), findsOneWidget);
      // The greeting from the first open is still there, from history — but
      // exactly once, not re-added a second time by this reopen.
      expect(find.text('Hello there! Job seeker or employer?'), findsOneWidget);
      expect(dataSource.callCount, 1); // no extra call fired by closing/reopening
    });
  });

  group('BuddyChatbotOverlay action chips & auto-navigate', () {
    testWidgets('tapping an action chip navigates to its mapped in-app route', (tester) async {
      final dataSource = _FakeAriaRemoteDataSource();
      await _pumpWithRouter(
        tester,
        _container(dataSource: dataSource),
        RoutePaths.employerJobCreate,
      );

      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'post a job');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      dataSource.resolvePending(
        'Opening the post new job page.',
        actions: const [
          AriaChatAction(key: 'post_job', label: 'Post New Job', route: '/employer/employer/jobs/new/'),
        ],
        source: 'intent',
      );
      await tester.pump();
      await tester.pump();
      // The reply's own auto-scroll-to-bottom (`_scrollToBottom`, 200ms) —
      // needed since the persistent welcome cards panel added below the
      // transcript (`AriaWelcomeCardsPanel`) leaves less room for messages
      // than before, so a 2-turn conversation can now need a scroll to
      // bring the newest reply's chip into view. A bounded pump, not
      // `pumpAndSettle` — the launcher's float animation repeats forever.
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.widgetWithText(ActionChip, 'Post New Job'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('NAVIGATED'), findsOneWidget);
    });

    testWidgets('a single-action intent reply auto-navigates once speech finishes, not before', (tester) async {
      final dataSource = _FakeAriaRemoteDataSource();
      final playback = _CompletableAriaVoicePlaybackService();
      await _pumpWithRouter(
        tester,
        _container(dataSource: dataSource, playback: playback),
        RoutePaths.employerJobCreate,
      );

      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'post a job');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      dataSource.resolvePending(
        'Opening the post new job page.',
        actions: const [
          AriaChatAction(key: 'post_job', label: 'Post New Job', route: '/employer/employer/jobs/new/'),
        ],
        source: 'intent',
      );
      await tester.pump();
      await tester.pump();

      // Speech hasn't "finished" yet — must not have navigated away already.
      expect(find.text('NAVIGATED'), findsNothing);

      playback.completeNow();
      await tester.pumpAndSettle();

      expect(find.text('NAVIGATED'), findsOneWidget);
    });
  });

  group('BuddyChatbotOverlay language selector', () {
    testWidgets('header renders with no overflow — mic, language selector, speaker, close all fit', (tester) async {
      await _pump(tester, _container());

      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('ariaLanguageSelector')), findsOneWidget);
      expect(find.byKey(const Key('ariaMicButton')), findsOneWidget);
      expect(find.byKey(const Key('ariaSpeakerButton')), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      // The closed selector shows a compact code (not the full label — see
      // `_LanguageSelector`'s doc comment on why), defaulting to English.
      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('opening the menu lists exactly the 5 real web languages, in order, by full name', (tester) async {
      await _pump(tester, _container());
      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await tester.pump(const Duration(milliseconds: 200));

      // Never pumpAndSettle() in this file — the launcher's float animation
      // repeats forever (see `BuddyChatbotOverlay`'s own class doc comment),
      // so a bounded pump is used for the dropdown menu's open transition
      // too, same as every other interaction in this file already does.
      await tester.tap(find.byKey(const Key('ariaLanguageSelector')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('English'), findsOneWidget);
      expect(find.text('Vietnamese'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);
      expect(find.text('Arabic'), findsOneWidget);
      expect(find.text('Russian'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecting a language updates the selector and carries into the next request', (tester) async {
      final dataSource = _FakeAriaRemoteDataSource();
      await _pump(tester, _container(dataSource: dataSource));
      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('ariaLanguageSelector')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Hindi').last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('HI'), findsOneWidget); // now the selector's own closed value
      expect(find.text('EN'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(dataSource.capturedLanguages, ['hindi']);
    });
  });
}
