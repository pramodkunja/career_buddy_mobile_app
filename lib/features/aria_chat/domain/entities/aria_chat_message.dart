/// A single turn in a conversation with the "ARIA"/"Buddy" assistant
/// (`/api/riya/chat/`, `riya_bot/views.py:riya_chat`).
enum AriaMessageRole { user, assistant }

/// One of the optional quick-action chips a reply can carry
/// (`data["actions"]`, each `{key, label, route}` — see
/// `riya_bot/riya_assistant.py:_build_action`, verified directly against
/// source). [route] is a *web* route string (e.g. `/resume-builder/`), not
/// an in-app Flutter route — `ariaActionFlutterRoute`
/// (`aria_action_routes.dart`) maps it to one of this app's own routes for
/// real navigation (`BuddyChatbotOverlay`'s `_onActionTap`/auto-navigate
/// listener); tapping a chip only falls back to re-sending [label] as the
/// next message when no mapping exists (today: just `about_app`'s
/// deliberately empty route).
class AriaChatAction {
  const AriaChatAction({required this.key, required this.label, required this.route});

  factory AriaChatAction.fromJson(Map<String, dynamic> json) => AriaChatAction(
    key: json['key'] as String? ?? '',
    label: json['label'] as String? ?? '',
    route: json['route'] as String? ?? '',
  );

  final String key;
  final String label;
  final String route;
}

/// A rendered chat bubble. [isError] marks a friendly local fallback
/// message synthesized when the API call fails (network error, non-200, or
/// a malformed body) — it is never sent to the server, only shown in the
/// UI with a distinct error visual treatment.
class AriaChatMessage {
  const AriaChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
    this.actions = const [],
  });

  final AriaMessageRole role;
  final String content;
  final bool isError;
  final List<AriaChatAction> actions;
}
