import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../skill_up_lesson_route_args.dart';

/// Batch 7 — one of Skill Up's 48 real static lesson pages (`static/001
/// Career Buddy/**/*.html`). These are hand-authored, standalone HTML
/// documents with their own embedded CSS/JS/images — the real web itself
/// shows them via an in-page `<iframe>` (`index.html`'s lesson viewer),
/// so the most faithful Flutter reproduction is the same idea: load the
/// real, live, unmodified page in a `WebView`, not a hand re-authored
/// Dart re-implementation (which risks drifting from the real content and
/// would need to be redone for all 48 pages). These files are served by
/// Django's plain `static()` file server with no `@login_required` —
/// confirmed live (200, unauthenticated) — so no session-cookie sharing
/// concerns apply here (unlike Grammar's protected media, see
/// `GrammarMediaDataSource`).
class SkillUpLessonScreen extends StatefulWidget {
  const SkillUpLessonScreen({required this.args, super.key});

  final SkillUpLessonRouteArgs args;

  @override
  State<SkillUpLessonScreen> createState() => _SkillUpLessonScreenState();
}

class _SkillUpLessonScreenState extends State<SkillUpLessonScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  /// Batch 10 — a real network/HTTP failure loading this lesson page
  /// (no connectivity, a timeout, the static file 404ing) previously left
  /// [_loading] stuck `true` forever, an unrecoverable infinite spinner
  /// with no way back except the OS back gesture. Only a main-frame error
  /// is treated as fatal here — a failed subresource (an image/script
  /// inside the real page) must not block the page the user can otherwise
  /// still read, matching how a real browser tab behaves.
  String? _error;

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
          }),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            setState(() {
              _loading = false;
              _error =
                  'This lesson page could not be loaded. Please check your connection and try again.';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.args.url));
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _controller.loadRequest(Uri.parse(widget.args.url));
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
          _error != null
              ? AppErrorView(message: _error!, onRetry: _retry)
              : Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}
