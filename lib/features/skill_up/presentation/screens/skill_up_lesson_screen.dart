import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../skill_up_lesson_route_args.dart';
import '../widgets/skill_up_locked_view.dart';

/// Batch 7 — one of Skill Up's 48 real static lesson pages (`static/001
/// Career Buddy/**/*.html`). These are hand-authored, standalone HTML
/// documents with their own embedded CSS/JS/images — the real web itself
/// shows them via an in-page `<iframe>` (`index.html`'s lesson viewer),
/// so the most faithful Flutter reproduction is the same idea: load the
/// real, live, unmodified page in a `WebView`, not a hand re-authored
/// Dart re-implementation (which risks drifting from the real content and
/// would need to be redone for all 48 pages).
///
/// Phase 38 correction of this file's own earlier doc comment: these pages
/// are **not** uniformly unauthenticated. `core/skillup_access.py`'s
/// `SkillUpAccessMiddleware` (confirmed by direct source read) sits in
/// front of the plain static-file server and returns HTTP 403 with its own
/// locked-content HTML for any lesson outside the Free set
/// (`001 CEFR/`, `Vocabulary/`, `GrammerActivities/`, and one named file)
/// when the request's session cookie doesn't belong to a `normal`/`pro`
/// plan user. That check reads the request's session cookie directly — and
/// a plain `WebViewController` has its own cookie store, entirely separate
/// from this app's own authenticated Dio client (`ApiClient`'s
/// `PersistCookieJar`) — so, before this phase's fix, a real paid user
/// opening a non-Free lesson was indistinguishable from an anonymous one to
/// this middleware and got the same locked response as a Free-plan user,
/// regardless of their actual plan. [_loadLesson] now explicitly reads the
/// same session cookie this app's own API calls already use
/// ([ApiClient.buildCookieHeader], the same bridge Group Discussion's
/// WebSocket already relies on for the identical reason) and sends it on
/// the lesson request, so the middleware authenticates this request exactly
/// as it would a browser's.
class SkillUpLessonScreen extends ConsumerStatefulWidget {
  const SkillUpLessonScreen({required this.args, super.key});

  final SkillUpLessonRouteArgs args;

  @override
  ConsumerState<SkillUpLessonScreen> createState() =>
      _SkillUpLessonScreenState();
}

class _SkillUpLessonScreenState extends ConsumerState<SkillUpLessonScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  /// A real network/HTTP failure loading this lesson page (no connectivity,
  /// a timeout, the static file 404ing) previously left [_loading] stuck
  /// `true` forever, an unrecoverable infinite spinner with no way back
  /// except the OS back gesture. Only a main-frame error is treated as
  /// fatal here — a failed subresource (an image/script inside the real
  /// page) must not block the page the user can otherwise still read,
  /// matching how a real browser tab behaves.
  String? _error;

  /// Phase 38 — set only when the lesson request itself completes with
  /// HTTP 403, `SkillUpAccessMiddleware`'s own, and only, status code for
  /// this exact URL prefix (confirmed by reading it in full — every other
  /// case it handles is either a redirect or a pass-through to the normal
  /// static handler, so a 403 on this specific request is unambiguous,
  /// not a generic assumption about 403s elsewhere in the app). Shown as a
  /// native locked-content view instead of letting the WebView render the
  /// server's own HTML error page, so the upgrade action can go to this
  /// app's own verified `RoutePaths.pro` screen instead of navigating the
  /// WebView to the live website.
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // These lesson pages are real web content rendered in a WebView so
      // this screen "behaves like a mobile app screen", not a browser tab —
      // `enableZoom(false)` is the cross-platform `webview_flutter` API
      // (dispatches to `AndroidWebViewController.enableZoom`/
      // `WebKitWebViewController.enableZoom` automatically), confirmed live
      // on-device that the HTML's own `<meta name="viewport">` alone does
      // NOT stop a real pinch/double-tap zoom gesture — the platform
      // WebView itself must also be told pinch/double-tap zoom isn't
      // supported. Does not affect normal vertical scrolling, JS, links, or
      // navigation — confirmed by reading both platform implementations
      // (Android: `WebSettings.setSupportZoom(false)`; iOS: an injected
      // `user-scalable=no` viewport override), neither of which touches the
      // scroll/gesture-recognizer paths used for scrolling.
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _loading = true;
            _error = null;
            _locked = false;
          }),
          onPageFinished: (_) => setState(() => _loading = false),
          onHttpError: (error) {
            if (error.response?.statusCode != 403) return;
            setState(() {
              _loading = false;
              _locked = true;
            });
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            setState(() {
              _loading = false;
              _error =
                  'This lesson page could not be loaded. Please check your connection and try again.';
            });
          },
        ),
      );
    _loadLesson();
  }

  /// Sends the same session cookie this app's own authenticated API calls
  /// already carry, so `SkillUpAccessMiddleware` sees this request exactly
  /// as it would a logged-in browser's — see this class's own doc comment.
  /// If building the header fails for any reason, the request is still
  /// sent (without it) rather than left stuck — the resulting behavior is
  /// the same locked response every request got before this phase's fix,
  /// not a new, worse failure mode.
  Future<void> _loadLesson() async {
    var cookieHeader = '';
    try {
      cookieHeader = await ref.read(apiClientProvider).buildCookieHeader();
    } catch (_) {
      // Fall through with no cookie header — see doc comment above.
    }
    await _controller.loadRequest(
      Uri.parse(widget.args.url),
      headers: cookieHeader.isEmpty ? const {} : {'Cookie': cookieHeader},
    );
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
      _locked = false;
    });
    _loadLesson();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.title, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (_locked)
            SkillUpLockedView(onViewPlans: () => context.push(RoutePaths.pro))
          else if (_error != null)
            AppErrorView(message: _error!, onRetry: _retry)
          else
            Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading) const Center(child: CircularProgressIndicator()),
              ],
            ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}
