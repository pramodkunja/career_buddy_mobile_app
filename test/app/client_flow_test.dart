import 'dart:async';

import 'package:career_buddy_lms/app/app.dart';
import 'package:career_buddy_lms/core/demo/demo_activities_repository.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/providers/core_providers.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/services/audio_recorder_service.dart';
import 'package:career_buddy_lms/features/aria_chat/data/datasources/aria_remote_datasource.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_chat_message.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_chat_reply.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_stream_event.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_voice.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/services/aria_voice_playback_service.dart';
import 'package:career_buddy_lms/features/aria_chat/presentation/providers/aria_chat_providers.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/profile_data.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/profile_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:career_buddy_lms/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:career_buddy_lms/features/grammar/presentation/screens/grammar_index_screen.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/providers/gd_providers.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/screens/gd_topic_screen.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_assessment.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_result.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_start.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_topic.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_assessment_repository.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_repository.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_topics_screen.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/screens/mock_tests_hub_screen.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_analysis.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_history_item.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/resume_repository.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:career_buddy_lms/features/resume/presentation/screens/resume_builder_screen.dart';
import 'package:career_buddy_lms/features/roleplay/presentation/screens/roleplay_home_screen.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/skill_up_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/group_discussion/gd_test_doubles.dart';

/// One shared fake across the whole chain — `restoreSession()` starts
/// unauthenticated (so the app genuinely boots to the real `LoginScreen`,
/// not a bypassed "already logged in" state) and `login()` succeeds for
/// any credentials, matching `login_screen_test.dart`'s own convention.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async =>
      const Success(AuthUser(username: 'jane'));

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

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<Result<DashboardData>> getDashboard() async => const Success(
    DashboardData(
      stats: DashboardStats(completedCount: 2, inProgressCount: 1, totalActivities: 10, totalScore: 45),
      activities: [],
      recentResults: [],
      recommendedJobs: [],
      paymentHistory: [],
    ),
  );
}

class _FakeResumeRepository implements ResumeRepository {
  @override
  Future<Result<ResumeAnalysisResult>> uploadAndAnalyze({required String filePath, required String fileName}) async =>
      throw UnimplementedError();

  @override
  Future<Result<ResumeAnalysisResult>> reanalyze(int resumeId) async => throw UnimplementedError();

  @override
  Future<Result<List<ResumeHistoryItem>>> getHistory() async => const Success([]);
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<Result<ProfileOverview>> getProfile() async => const Success(
    ProfileOverview(
      fullName: 'Jane Doe',
      username: 'jane',
      email: 'jane@example.com',
      activitiesStarted: 2,
      completedSubs: 1,
      totalScore: 45,
      recentResults: [],
      fields: {},
      englishLevel: 'intermediate',
      bio: '',
      additionalEducationsJson: '[]',
    ),
  );

  @override
  Future<Result<void>> updateProfile(ProfileEditData data) async => const Success(null);
}

/// Never resolves `startSession` — only used to verify navigation
/// happened, same reasoning as `jam_topics_screen_test.dart`'s own
/// `_NeverJamRepository`.
class _StubJamRepository implements JamRepository {
  @override
  Future<Result<JamSessionStart>> startSession({int? topicId}) => Completer<Result<JamSessionStart>>().future;

  @override
  Future<Result<List<JamTopic>>> getTopics() async => const Success([]);

  @override
  Future<Result<void>> saveAudio({
    required int sessionId,
    String? audioFilePath,
    required int durationSeconds,
    required String language,
    String transcript = '',
  }) => throw UnimplementedError();

  @override
  Future<Result<JamSessionResult>> completeSession(int sessionId) => throw UnimplementedError();
}

class _StubJamAssessmentRepository implements JamAssessmentRepository {
  @override
  Future<Result<List<JamPracticeSessionSummary>>> getHistory() async => const Success([]);

  @override
  Future<Result<JamSessionStart>> startAssessment() => throw UnimplementedError();

  @override
  Future<Result<JamAssessmentStageOutcome>> completeAssessmentStage(int sessionId) => throw UnimplementedError();
}

/// Records every call — copied from `buddy_chatbot_overlay_test.dart`'s own
/// `_FakeAriaRemoteDataSource` (private there, so duplicated here rather
/// than exported purely for reuse).
class _FakeAriaRemoteDataSource implements AriaRemoteDataSource {
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
  }) => const Stream<AriaStreamEvent>.empty();

  @override
  Future<AriaVoiceTranscription> transcribeVoice({
    required String audioBase64,
    required String mimeType,
    required String language,
  }) async => const AriaVoiceTranscription(text: '', source: 'sarvam');

  @override
  Future<String?> synthesizeSpeech({required String text, required String language}) async => null;
}

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

/// Simulates the Android hardware/gesture back button (not a tap on any
/// particular on-screen widget) — needed for screens that, like
/// `ActivityListScreen`, carry their own `drawer: const AppNavDrawer()`:
/// Flutter's own `AppBar` leading-icon resolution shows the drawer's
/// hamburger instead of a back arrow whenever a screen has both a drawer
/// and a pop-able route (`AppBar._getEffectiveLeading`), so there is no
/// visible in-AppBar back affordance to tap on those screens at all — a
/// real device's system back gesture still works regardless (this is
/// genuinely reachable, just not via an on-screen icon); this helper is
/// the system back gesture's test equivalent. See this pass's final report
/// for why this is flagged as a real, if non-blocking, UX finding rather
/// than something this pass rewrites.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}

/// Pumps for a bounded duration — never `pumpAndSettle`, which hangs
/// forever against `BuddyChatbotOverlay`'s own perpetual float animation
/// (present on every screen in this chain) — same established convention
/// used throughout this test suite.
Future<void> _settle(WidgetTester tester, {int times = 6}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Pumps the real `CareerBuddyApp` with every fake this chain's screens
/// need, drives the real `LoginScreen`'s form (not a bypassed
/// already-authenticated state), and leaves the tester sitting on the real
/// Dashboard — the common starting point every segment below shares.
/// Each segment gets its **own** fresh pump (a new `testWidgets`) rather
/// than being chained onto a single giant test: an earlier version of this
/// suite chained every segment into one continuous test and, after ~15
/// sequential navigations, started tripping internal Flutter rendering
/// framework assertions (not app-code bugs — directed at
/// github.com/flutter/flutter's own issue tracker) purely from accumulated
/// widget/route-history state no real user session would ever reach in
/// one sitting. Splitting restores a clean slate per segment and is more
/// diagnostic besides: a failure now points at exactly one destination,
/// not a 15-step chain.
Future<void> _pumpLoggedInApp(WidgetTester tester, {Size size = const Size(800, 2200)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepository()),
        activitiesRepositoryProvider.overrideWithValue(DemoActivitiesRepository()),
        resumeRepositoryProvider.overrideWithValue(_FakeResumeRepository()),
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        gdRepositoryProvider.overrideWithValue(FakeGdRepository()),
        gdRealtimeServiceProvider.overrideWithValue(FakeGdRealtimeService()),
        gdSpeechServiceProvider.overrideWithValue(FakeGdSpeechService()),
        gdTtsServiceProvider.overrideWithValue(FakeGdTtsService()),
        jamRepositoryProvider.overrideWithValue(_StubJamRepository()),
        jamAssessmentRepositoryProvider.overrideWithValue(_StubJamAssessmentRepository()),
        apiClientProvider.overrideWithValue(ApiClient.forTesting(Dio())),
        ariaRemoteDataSourceProvider.overrideWithValue(_FakeAriaRemoteDataSource()),
        ariaAudioRecorderServiceProvider.overrideWithValue(_FakeAudioRecorderService()),
        ariaVoicePlaybackServiceProvider.overrideWithValue(_FakeAriaVoicePlaybackService()),
      ],
      child: const CareerBuddyApp(),
    ),
  );
  await _settle(tester);

  // ── Launch -> Login ────────────────────────────────────────────────
  // Unauthenticated boot genuinely lands on the real LoginScreen (the
  // route guard's redirect, not a bypassed state).
  expect(find.text('Sign In to Dashboard'), findsOneWidget);
  await tester.enterText(find.byType(TextFormField).first, 'jane');
  await tester.enterText(find.byType(TextFormField).last, 'password123');
  await tester.tap(find.text('Sign In to Dashboard'));
  await _settle(tester);

  // ── Dashboard ──────────────────────────────────────────────────────
  expect(find.byType(DashboardScreen), findsOneWidget, reason: 'login must land on the real Dashboard');
  expect(find.text('Quick Start'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Login -> Dashboard -> Activities -> Activity Detail -> Back -> Back', (tester) async {
    await _pumpLoggedInApp(tester);

      // ── Dashboard -> drawer -> Activities -> Activity Detail -> Back -> Back ──
      await tester.tap(find.byIcon(Icons.menu));
      await _settle(tester, times: 2);
      await tester.tap(find.text('Activities'));
      await _settle(tester);
      expect(find.text('Vocabulary Quiz'), findsOneWidget, reason: 'the real Activities list must render demo data');

      await tester.tap(find.text('Vocabulary Quiz'));
      await _settle(tester);
      expect(find.text('Vocabulary Practice'), findsOneWidget, reason: 'Activity Detail must render its sub-activities');
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);
      expect(find.text('Vocabulary Quiz'), findsWidgets, reason: 'Back from Activity Detail must return to the list');

      await _systemBack(tester);
      await _settle(tester);
      expect(find.byType(DashboardScreen), findsOneWidget, reason: 'Back from the list must return to Dashboard');
  });

  testWidgets('Dashboard -> Grammar -> Back, Skill-Up(+Certifications) -> Back, Mock Tests -> Back', (tester) async {
    await _pumpLoggedInApp(tester);

      // ── Dashboard -> drawer -> Grammar -> Back ──────────────────────────
      await tester.tap(find.byIcon(Icons.menu));
      await _settle(tester, times: 2);
      await tester.tap(find.text('Grammar'));
      await tester.runAsync(() async {});
      await _settle(tester, times: 10);
      expect(find.byType(GrammarIndexScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _systemBack(tester);
      await _settle(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);

      // ── Dashboard -> drawer -> Skill Up (expand) -> Browse All -> Certifications tab -> Back ──
      await tester.tap(find.byIcon(Icons.menu));
      await _settle(tester, times: 2);
      await tester.tap(find.text('Skill Up'));
      await _settle(tester, times: 2);
      await tester.tap(find.text('Browse All'));
      await _settle(tester);
      expect(find.byType(SkillUpScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Certifications'));
      await _settle(tester);
      expect(tester.takeException(), isNull);

      await _systemBack(tester);
      await _settle(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);

      // ── Dashboard -> Mock Tests entry card -> Back ───────────────────────
      await tester.tap(find.text('Mock Tests'));
      await _settle(tester);
      expect(find.byType(MockTestsHubScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _systemBack(tester);
      await _settle(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('Dashboard -> Workshop Dashboard -> Enter Workshop (Group Discussion / JAM / Role Play) -> Back', (tester) async {
    await _pumpLoggedInApp(tester);

      // ── Dashboard -> Workshop entry card -> Enter Workshop (JAM) -> Back ──
      // Below the fold at this viewport height — the Dashboard is a plain
      // `ListView` with stats/jobs/activities/payments above it. "Interactive
      // Workshop" (not bare "Workshop", which also matches the unrelated
      // Quick Start chip) is `WorkshopEntryCard`'s own title text.
      await tester.dragUntilVisible(find.text('Interactive Workshop'), find.byType(ListView).first, const Offset(0, -300));
      await tester.tap(find.text('Interactive Workshop'));
      await _settle(tester);
      expect(find.text('JAM'), findsOneWidget, reason: 'Workshop Dashboard must list the real workshop activities');

      // Demo workshop order (`demo_activities_data.dart`): Group Discussion,
      // JAM, Role Play.
      await tester.tap(find.text('Enter Workshop').first);
      await _settle(tester);
      expect(find.byType(GdTopicScreen), findsOneWidget, reason: 'Group Discussion must open the real screen, not ComingSoon');
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);
      expect(find.text('JAM'), findsOneWidget, reason: 'Back from Group Discussion must return to the Workshop Dashboard');

      // ── Workshop Dashboard -> Enter Workshop (JAM) -> Back ──
      await tester.tap(find.text('Enter Workshop').at(1));
      await _settle(tester);
      expect(find.byType(JamTopicsScreen), findsOneWidget, reason: 'JAM must open the real screen, not ComingSoon');
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);

      // ── Workshop Dashboard -> Enter Workshop (Role Play) -> Back -> Back ──
      await tester.tap(find.text('Enter Workshop').at(2));
      await _settle(tester);
      expect(find.byType(RoleplayHomeScreen), findsOneWidget, reason: 'Role Play must open the real screen, not ComingSoon');
      expect(tester.takeException(), isNull);

      await _systemBack(tester);
      await _settle(tester, times: 12);
      await _systemBack(tester);
      await _settle(tester, times: 12);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard -> Resume Parsing -> Back, ARIA, Profile -> Back, Logout', (tester) async {
    await _pumpLoggedInApp(tester);

      // ── Dashboard -> drawer -> Resume Parsing -> Back ───────────────────
      await tester.tap(find.byIcon(Icons.menu));
      await _settle(tester, times: 2);
      await tester.tap(find.text('Resume Parsing'));
      await _settle(tester);
      expect(find.byType(ResumeBuilderScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _systemBack(tester);
      await _settle(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);

      // ── ARIA — tap the launcher, confirm the panel opens ────────────────
      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await _settle(tester);
      expect(find.byTooltip('Close'), findsOneWidget, reason: 'the ARIA chat panel must open');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('buddyChatbotLauncher')));
      await _settle(tester);

      // ── Dashboard -> drawer -> Profile -> Back ──────────────────────────
      await tester.tap(find.byIcon(Icons.menu));
      await _settle(tester, times: 2);
      await tester.tap(find.text('jane'));
      await _settle(tester);
      expect(find.text('Jane Doe'), findsOneWidget, reason: 'Profile must render the real profile data');
      expect(tester.takeException(), isNull);

      await _systemBack(tester);
      await _settle(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);

      // ── Dashboard -> drawer -> Logout -> back at LoginScreen ────────────
      await tester.tap(find.byIcon(Icons.menu));
      await _settle(tester, times: 2);
      await tester.tap(find.text('Logout'));
      await _settle(tester);
      expect(find.text('Sign In to Dashboard'), findsOneWidget, reason: 'Logout must return to the real LoginScreen');
      expect(tester.takeException(), isNull);
  });
}
