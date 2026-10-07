import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/aria_chat/domain/aria_welcome_catalog.g.dart';
import '../../features/aria_chat/domain/entities/aria_chat_message.dart';
import '../../features/aria_chat/domain/entities/aria_language.dart';
import '../../features/aria_chat/domain/entities/aria_welcome_card.dart';
import '../../features/aria_chat/presentation/aria_action_routes.dart';
import '../../features/aria_chat/presentation/aria_welcome_reply.dart';
import '../../features/aria_chat/presentation/aria_welcome_section.dart';
import '../../features/aria_chat/presentation/controllers/aria_chat_controller.dart';
import '../../features/aria_chat/presentation/widgets/aria_welcome_cards_panel.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';

/// `#riya-assistant-root`/`.riya-launcher`/`.riya-thought-bubble`
/// (`templates/includes/aria_assistant.html`, `static/css/riya_assistant.css`)
/// — the floating "Buddy" launcher plus its real chat panel, now wired to
/// the live `/api/riya/chat/` endpoint (`ApiEndpoints.riyaChat` — see its
/// doc comment for the full, source-verified request/response contract).
///
/// Preserved verbatim from the earlier decorative-only version: the
/// launcher's 110×110 size/position (`right: 10, bottom: 15`), its 3s float
/// animation, its glow shadow, and the small greeting-tooltip's visual
/// styling (color/border/radius/font) shown while the panel is closed.
///
/// **Greeting parameter removed, not kept as an override.** Every call site
/// previously passed either a hardcoded `'Hello, click me to chat!'` or (in
/// `HomeScreen` only) a hand-rolled `'Hello ${user.username}!'` — neither
/// matched the real web's actual rule (`riya_bot/views.py:
/// _speakable_user_name`: first name if authenticated, a fixed prompt
/// otherwise). Since this widget is now auth-aware internally (it needs
/// [authControllerProvider] anyway, to compute `is_employer` for every
/// sent message), computing the greeting the same way here too removes a
/// second, drifting source of truth rather than keeping a parameter no
/// call site could set correctly by hand. See
/// [AriaChatController.greetingFor].
///
/// **Opening the panel never calls the network by itself** — only
/// [AriaChatController.sendMessage] does, and that only runs when the user
/// actually sends something. This is required for the several existing
/// widget tests that mount screens containing this overlay with bounded
/// `tester.pump()` (never `pumpAndSettle()`, since the float animation
/// repeats forever) and don't expect background network activity.
class BuddyChatbotOverlay extends ConsumerStatefulWidget {
  const BuddyChatbotOverlay({super.key});

  @override
  ConsumerState<BuddyChatbotOverlay> createState() => _BuddyChatbotOverlayState();
}

class _BuddyChatbotOverlayState extends ConsumerState<BuddyChatbotOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  bool _panelOpen = false;

  @override
  void initState() {
    super.initState();
    // `@keyframes aria-float` (`riya_assistant.css`) — 3s ease-in-out,
    // 0 → -8px → 0.
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  void _togglePanel() {
    final opening = !_panelOpen;
    setState(() => _panelOpen = opening);
    if (opening) {
      final authState = ref.read(authControllerProvider);
      ref.read(ariaChatControllerProvider.notifier).ensureGreeted(AriaChatController.greetingFor(authState));
    }
  }

  void _closePanel() {
    // A spoken reply or an in-progress recording must never keep running
    // once the panel is no longer visible — both calls are no-ops when
    // nothing is actually active.
    final notifier = ref.read(ariaChatControllerProvider.notifier);
    unawaited(notifier.cancelRecording());
    notifier.stopSpeaking();
    setState(() => _panelOpen = false);
  }

  /// Best-effort mobile equivalent of the web's Django `url_name`/`path`
  /// pair — not a literal 1:1 match (this app's routes don't correspond
  /// 1:1 with the web's), just a reasonable "what screen is the user on"
  /// signal for the assistant. Falls back gracefully when there's no
  /// [GoRouterState] in scope at all (e.g. a bare `MaterialApp` test host),
  /// which [GoRouterState.of] otherwise throws on.
  ({String page, String path}) _currentRoute() {
    try {
      final routerState = GoRouterState.of(context);
      final path = routerState.uri.toString();
      final page = routerState.name ?? routerState.matchedLocation;
      return (page: page, path: path);
    } catch (_) {
      return (page: 'mobile-app', path: '/');
    }
  }

  void _send(String text) {
    final authState = ref.read(authControllerProvider);
    final isEmployer = authState is AuthAuthenticated && authState.user.isEmployer;
    final route = _currentRoute();
    ref
        .read(ariaChatControllerProvider.notifier)
        .sendMessage(text, page: route.page, path: route.path, isEmployer: isEmployer);
  }

  /// The header mic button's tap handler — idle starts recording, recording
  /// stops it and (per [AriaChatController.stopRecordingAndSend]'s own doc
  /// comment) sends the transcription immediately, same as [_send] does for
  /// typed text. A no-op while transcribing (the button is disabled for
  /// that state — see `_MicButton`).
  void _toggleMic() {
    final notifier = ref.read(ariaChatControllerProvider.notifier);
    final status = ref.read(ariaChatControllerProvider).voiceStatus;
    switch (status) {
      case AriaVoiceStatus.idle:
        notifier.startRecording();
      case AriaVoiceStatus.recording:
        final authState = ref.read(authControllerProvider);
        final isEmployer = authState is AuthAuthenticated && authState.user.isEmployer;
        final route = _currentRoute();
        notifier.stopRecordingAndSend(page: route.page, path: route.path, isEmployer: isEmployer);
      case AriaVoiceStatus.transcribing:
        break; // Busy uploading — the mic button is disabled for this state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final greeting = AriaChatController.greetingFor(authState);

    // Laid out as a bottom-right-anchored Column (panel/tooltip stacked
    // directly above the launcher) rather than a `Stack` of `Positioned`
    // children overflowing a fixed-size box — the earlier decorative-only
    // version used the latter (fine when the only overlay content was a
    // small tooltip), but the real chat panel is far taller than the
    // launcher itself, and large negative-offset overflow inside a `Stack`
    // interacts badly with ancestor hit-testing (observed directly: taps on
    // the panel's send button silently missed in widget tests). A `Column`
    // sized to its own content sidesteps that entirely.
    return Positioned(
      // `.riya-assistant{right:10px;bottom:15px}` (`riya_assistant.css`).
      right: 10,
      bottom: 15,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_panelOpen)
            _PanelEntrance(
              child: _ChatPanel(onSend: _send, onClose: _closePanel, onMicToggle: _toggleMic),
            )
          else
            // `.riya-greeting-bubble` — shown near the launcher while the
            // panel is closed, same visual styling as the original
            // decorative-only version.
            Container(
              constraints: const BoxConstraints(maxWidth: 170),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [BoxShadow(color: Color(0x260EA5E9), blurRadius: 14)],
              ),
              child: Text(
                greeting,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              final dy = -8 * (1 - (2 * (_floatController.value - 0.5)).abs());
              return Transform.translate(offset: Offset(0, dy), child: child);
            },
            child: GestureDetector(
              key: const Key('buddyChatbotLauncher'),
              onTap: _togglePanel,
              child: Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x9900C8FF), blurRadius: 10),
                    BoxShadow(color: Color(0x4000B4FF), blurRadius: 20),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset('assets/images/Ai_Robot.png', fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A self-contained scale+fade-in entrance, matching the real
/// `#riya-thought-bubble`'s open animation. Implemented as a
/// [TweenAnimationBuilder] rather than an explicit [AnimationController] —
/// it's freshly inserted into the tree each time the panel opens (the
/// panel is conditionally built, not just hidden), so its own `initState`
/// naturally replays the animation on every open with no controller
/// lifecycle to manage.
class _PanelEntrance extends StatelessWidget {
  const _PanelEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.scale(alignment: Alignment.bottomRight, scale: 0.85 + (0.15 * t), child: child),
        );
      },
      child: child,
    );
  }
}

/// The real chat panel (`#riya-thought-bubble`) — a rounded white panel
/// with a scrollable message list, a text input, and a send button. See
/// `ApiEndpoints.riyaChat`'s doc comment for the request/response contract
/// this ultimately drives via [AriaChatController].
class _ChatPanel extends ConsumerStatefulWidget {
  const _ChatPanel({required this.onSend, required this.onClose, required this.onMicToggle});

  final void Function(String text) onSend;
  final VoidCallback onClose;
  final VoidCallback onMicToggle;

  @override
  ConsumerState<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<_ChatPanel> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _submit([String? presetText]) {
    final text = presetText ?? _textController.text;
    if (text.trim().isEmpty) return;
    if (presetText == null) _textController.clear();
    widget.onSend(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  bool get _isEmployer {
    final authState = ref.read(authControllerProvider);
    return authState is AuthAuthenticated && authState.user.isEmployer;
  }

  /// `getAssistantRole()` (`static/js/BOTscript.js`) — see
  /// `ariaWelcomeSection()`'s doc comment for why this app has no
  /// "memory-only guest role" equivalent to reproduce: every screen this
  /// overlay is mounted on already knows the real auth state, so a guest is
  /// always exactly `"guest"`, never a mid-conversation "guest who said
  /// they're a job seeker" (that distinction only exists because the real
  /// web lets a signed-out visitor browse while mid-chat; this app's
  /// sign-up/sign-in screens aren't reachable with the overlay open there).
  String get _assistantRole {
    final authState = ref.read(authControllerProvider);
    if (authState is! AuthAuthenticated) return 'guest';
    return authState.user.isEmployer ? 'employer' : 'student';
  }

  /// Same best-effort "what screen is the user on" signal as
  /// `BuddyChatbotOverlay._currentRoute()` — duplicated rather than shared
  /// because that one lives on a different, private State class with no
  /// public surface to call into (this class already independently reads
  /// [authControllerProvider] for [_isEmployer] the same way, for the same
  /// reason).
  String _currentPath() {
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      return '/';
    }
  }

  /// `renderPersistentWelcome()`'s own role/section resolution
  /// (`static/js/BOTscript.js`): a guest always sees their role-level cards
  /// ([kAriaWelcomeRoleContext]) — "a signed-out visitor gets the role
  /// cards wherever they are: the section cards all lead somewhere that
  /// needs an account" (the real comment, reproduced verbatim) — while a
  /// signed-in student/employer sees their current section's cards
  /// ([kAriaWelcomeSectionContext]) when [ariaWelcomeSection] recognizes the
  /// route, falling back to their role-level cards otherwise (an
  /// unrecognized screen, same as the real `SECTION_CONTEXT[section] ||
  /// roleContext`).
  AriaWelcomeCardGroup get _currentWelcomeGroup {
    final role = _assistantRole;
    if (role == 'guest') return kAriaWelcomeRoleContext['guest']!;
    final section = ariaWelcomeSection(path: _currentPath(), isEmployer: _isEmployer);
    return kAriaWelcomeSectionContext[section] ?? kAriaWelcomeRoleContext[role]!;
  }

  /// A tapped welcome-card — mirrors `runWelcomeAction()`
  /// (`static/js/BOTscript.js`): compose the card's full (localized) reply
  /// once here (where both the card and the current language are in
  /// scope), then hand the user-visible question text, the composed reply,
  /// and the resolved [AriaChatAction] to the controller, which owns
  /// appending both chat turns and driving speech/navigation — see
  /// [AriaChatController.tapWelcomeCard]'s doc comment.
  void _onWelcomeCardTap(AriaWelcomeCard card, String language) {
    final catalogEntry = kAriaActionCatalog[card.actionKey];
    if (catalogEntry == null) return;
    ref
        .read(ariaChatControllerProvider.notifier)
        .tapWelcomeCard(
          questionText: card.localizedTitle(language),
          replyText: buildAriaWelcomeReply(card: card, language: language),
          action: AriaChatAction(key: card.actionKey, label: catalogEntry.label, route: catalogEntry.route),
        );
  }

  /// Same "gracefully do nothing without a [GoRouterState] in scope" leniency
  /// as [_currentRoute] — a bare `MaterialApp` test host (several existing
  /// widget tests mount this overlay that way) has no [GoRouter] for
  /// `context.push` to find, and would otherwise throw.
  void _tryNavigate(String route) {
    try {
      context.push(route);
    } catch (_) {
      // No GoRouter in scope — nothing sensible to do in production either
      // (this overlay is always mounted under the real router there).
    }
  }

  /// A tapped action chip — mirrors the real embedded widget's
  /// `renderChips`/`go(a.route)` (`riya-embed.js`): navigate to the action's
  /// real destination when this app has a screen for it. Falls back to the
  /// previous placeholder behavior (re-send the label as a new message)
  /// only when [ariaActionFlutterRoute] has nothing to map it to (today:
  /// just `about_app`'s empty route) — never silently does nothing.
  void _onActionTap(AriaChatAction action) {
    final route = ariaActionFlutterRoute(action.route, isEmployer: _isEmployer);
    if (route != null) {
      _tryNavigate(route);
    } else {
      _submit(action.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-scroll to the latest message whenever the conversation grows
    // (a new user turn, a new reply, or the loading row appearing).
    ref.listen(ariaChatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.sending != next.sending ||
          previous?.streamingText != next.streamingText) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
      // One-shot voice error (mic permission, empty recording,
      // transcription/TTS failure) — shown once as a snackbar rather than
      // held in the panel, since nothing was actually sent to the
      // assistant for it to belong to as a chat message.
      if (next.voiceError != null && next.voiceError != previous?.voiceError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.voiceError!), duration: const Duration(seconds: 3)));
      }
      // Auto-navigate once the reply that carried a single navigable action
      // finishes speaking — see `AriaChatState.pendingNavigation`'s doc
      // comment. Edge-triggered on the generation counter, not on the
      // action value itself, so the same action resolved twice in a row
      // (e.g. "Post New Job" asked about twice) still navigates both times.
      if (next.navigationGeneration != previous?.navigationGeneration && next.pendingNavigation != null) {
        final route = ariaActionFlutterRoute(next.pendingNavigation!.route, isEmployer: _isEmployer);
        if (route != null) _tryNavigate(route);
      }
    });
    final chatState = ref.watch(ariaChatControllerProvider);

    return Container(
      width: 300,
      // Taller than this widget's original 420 — the persistent welcome
      // cards panel (`AriaWelcomeCardsPanel`) added below is a genuinely new
      // chunk of always-visible content the original 300×420 sizing was
      // chosen without, and squeezing it into the old height left almost
      // nothing for the message transcript above it.
      height: 520,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            // Title group (`.riya-bubble-title-group`: name + language
            // select) on the left, actions group (`.riya-bubble-actions`:
            // "Mic -> Speaker -> Close (3px apart)") on the right —
            // reproduced in the same left-to-right order here.
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Buddy', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      const SizedBox(width: 6),
                      _LanguageSelector(
                        value: chatState.language,
                        onChanged: (code) => ref.read(ariaChatControllerProvider.notifier).setLanguage(code),
                      ),
                    ],
                  ),
                ),
                _MicButton(status: chatState.voiceStatus, onTap: widget.onMicToggle),
                _SpeakerButton(
                  state: switch (chatState.speakerState) {
                    AriaSpeakerState.idle => _SpeakState.idle,
                    AriaSpeakerState.loading => _SpeakState.loading,
                    AriaSpeakerState.speaking => _SpeakState.playing,
                  },
                  onTap: () => ref.read(ariaChatControllerProvider.notifier).toggleSpeaker(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  splashRadius: 18,
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: chatState.messages.length + (chatState.sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= chatState.messages.length) {
                  // While a reply streams in, `streamingText` grows token by
                  // token (`{"t": ...}` events) — shown as a live-updating
                  // bubble in place of a static "Thinking…" row the moment
                  // the first token arrives; before that (fast-path replies,
                  // or the brief gap before the AI path's first token), the
                  // real web's own "Thinking." status is shown instead.
                  final streamingText = chatState.streamingText;
                  if (streamingText != null && streamingText.isNotEmpty) {
                    return _StreamingBubble(text: streamingText);
                  }
                  return const _ThinkingIndicator();
                }
                final message = chatState.messages[index];
                return _MessageBubble(message: message, onActionTap: _onActionTap);
              },
            ),
          ),
          AriaWelcomeCardsPanel(
            group: _currentWelcomeGroup,
            language: chatState.language,
            onCardTap: (card) => _onWelcomeCardTap(card, chatState.language),
          ),
          if (chatState.voiceStatus != AriaVoiceStatus.idle) _VoiceStatusBanner(status: chatState.voiceStatus),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _submit(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2563EB)),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Thinking...', style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

/// `#chatbotLanguageSelect` — a compact dropdown reproducing the real
/// web's plain-text `<select>` exactly (same 5 languages, codes, labels,
/// order — see [kAriaLanguages]'s doc comment). A native `<select>` has no
/// custom open/close/tap-outside behavior to reproduce; [DropdownButton]
/// already behaves the same way (tap to open a native-feeling menu, tap
/// an item or outside to close), so none of that needed building by hand.
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Render-safety guard only, not a behavior change: `state.language`
    // always stays whatever the controller holds (including a value
    // outside this fixed list, in the unlikely event the assistant's own
    // `<LANG:code>` emits something unrecognized) — this only keeps
    // [DropdownButton] from asserting when asked to display a [value] that
    // doesn't match any of its items.
    final displayValue = kAriaLanguages.any((lang) => lang.code == value) ? value : kAriaLanguages.first.code;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: const Key('ariaLanguageSelector'),
        value: displayValue,
        isDense: true,
        iconSize: 16,
        style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
        items: [
          for (final lang in kAriaLanguages) DropdownMenuItem(value: lang.code, child: Text(lang.label)),
        ],
        // The real `<select>` always has room to show its full selected
        // label (`Vietnamese`, the longest). This 300px-wide panel does
        // not — by default `DropdownButton` sizes its closed state to fit
        // the *widest* item across all of them (not just the selected
        // one), which overflowed the header by a wide margin. Showing a
        // short code here only (full names stay in the opened menu, which
        // floats as an overlay unconstrained by the panel's width) is a
        // deliberate space adaptation of the display only — [onChanged]
        // still receives the real language code either way, and nothing
        // about which languages are offered or what gets sent changes.
        selectedItemBuilder: (context) => [
          for (final lang in kAriaLanguages) Text(lang.code.substring(0, 2).toUpperCase()),
        ],
        onChanged: (code) {
          if (code != null) onChanged(code);
        },
      ),
    );
  }
}

/// The mic button's visual states: idle (outline mic, tap to start),
/// recording (filled red, tap to stop — the "obvious recording state" this
/// task requires), transcribing (disabled spinner — a second recording
/// can't start mid-upload).
class _MicButton extends StatelessWidget {
  const _MicButton({required this.status, required this.onTap});

  final AriaVoiceStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final busy = status == AriaVoiceStatus.transcribing;
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        key: const Key('ariaMicButton'),
        padding: EdgeInsets.zero,
        splashRadius: 18,
        tooltip: switch (status) {
          AriaVoiceStatus.idle => 'Record a voice message',
          AriaVoiceStatus.recording => 'Stop recording',
          AriaVoiceStatus.transcribing => 'Transcribing...',
        },
        onPressed: busy ? null : onTap,
        icon: busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(
                status == AriaVoiceStatus.recording ? Icons.stop_circle : Icons.mic_none_rounded,
                color: status == AriaVoiceStatus.recording ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
              ),
      ),
    );
  }
}

/// Shown above the composer whenever the mic isn't idle — the recording
/// banner also offers a cancel affordance, separate from the mic button's
/// own "stop and transcribe" action, matching this task's requirement that
/// a recording can be discarded, not just submitted.
class _VoiceStatusBanner extends ConsumerWidget {
  const _VoiceStatusBanner({required this.status});

  final AriaVoiceStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = status == AriaVoiceStatus.recording;
    return Container(
      key: const Key('ariaVoiceStatusBanner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: const Color(0xFFFEF2F2),
      child: Row(
        children: [
          Icon(isRecording ? Icons.fiber_manual_record : Icons.hourglass_top, size: 12, color: const Color(0xFFDC2626)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isRecording ? 'Recording... tap the mic to stop' : 'Transcribing...',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
            ),
          ),
          if (isRecording)
            GestureDetector(
              key: const Key('ariaCancelRecordingButton'),
              onTap: () => ref.read(ariaChatControllerProvider.notifier).cancelRecording(),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: Color(0xFFB91C1C)),
              ),
            ),
        ],
      ),
    );
  }
}

enum _SpeakState { idle, loading, playing }

/// `#riya-speaker-button` — pause/resume AI speech, header-level and
/// global (not per-message), matching the real web's own single speaker
/// control: idle (tap replays the last reply), loading (this app's own
/// addition — see [AriaSpeakerState]'s doc comment), playing (tap stops).
class _SpeakerButton extends StatelessWidget {
  const _SpeakerButton({required this.state, required this.onTap});

  final _SpeakState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (state == _SpeakState.loading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return IconButton(
      key: const Key('ariaSpeakerButton'),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      splashRadius: 18,
      tooltip: state == _SpeakState.playing ? 'Stop AI speech' : 'AI narration',
      onPressed: onTap,
      icon: Icon(
        state == _SpeakState.playing ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        size: 20,
        color: state == _SpeakState.playing ? const Color(0xFF2563EB) : const Color(0xFF64748B),
      ),
    );
  }
}

/// The in-progress assistant reply while `{"t": ...}` events are still
/// arriving — same visual treatment as a finished assistant
/// [_MessageBubble] (plain text, no bubble background), since the real
/// page's own `#riya-stream-text` live card uses the identical styling as
/// its finished response card.
class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(text, style: const TextStyle(color: Color(0xFF0F172A))),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onActionTap});

  final AriaChatMessage message;
  final void Function(AriaChatAction action) onActionTap;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AriaMessageRole.user;

    Widget bubble;
    if (isUser) {
      bubble = Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: const BoxConstraints(maxWidth: 230),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomRight: Radius.circular(4),
              bottomLeft: Radius.circular(14),
            ),
          ),
          child: Text(message.content, style: const TextStyle(color: Color(0xFF0C4A6E))),
        ),
      );
    } else if (message.isError) {
      // Error visual treatment — a friendly inline message, not a dialog
      // or crash, but visually flagged distinctly from a normal reply.
      bubble = Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: const BoxConstraints(maxWidth: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            border: Border.all(color: const Color(0xFFFECACA)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
              const SizedBox(width: 6),
              Flexible(child: Text(message.content, style: const TextStyle(color: Color(0xFFB91C1C)))),
            ],
          ),
        ),
      );
    } else {
      // Assistant reply: plain text, no bubble background — visually
      // distinct from the user bubble by the *absence* of bubble styling,
      // matching the real page exactly. TTS playback for this reply is
      // driven by the header's global `_SpeakerButton`, not a per-message
      // control — see that widget's doc comment for why (the real web has
      // exactly one speaker button too, not one per message).
      bubble = Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(message.content, style: const TextStyle(color: Color(0xFF0F172A))),
          ),
        ),
      );
    }

    if (message.actions.isEmpty) return bubble;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bubble,
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final action in message.actions)
                ActionChip(
                  label: Text(action.label, style: const TextStyle(fontSize: 12)),
                  onPressed: () => onActionTap(action),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
