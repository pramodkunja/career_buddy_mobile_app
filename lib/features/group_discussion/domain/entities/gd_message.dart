import 'gd_speaker.dart';

/// One line of the transcript — either an AI agent's turn or the user's own
/// (spoken, on-device-transcribed) turn. Mirrors the `type: 'message'`
/// WebSocket payload (`GDConsumer._send`, `GD_app/consumers.py:78-86`/
/// `153-161`) field-for-field: `speaker`, `speaker_name`, `avatar`, `color`,
/// `content`, `is_user`. There is deliberately no server-sent timestamp on
/// this payload — [receivedAt] is captured client-side, purely to order/key
/// the transcript locally.
class GdMessage {
  const GdMessage({
    required this.speaker,
    required this.speakerName,
    required this.avatar,
    required this.colorHex,
    required this.content,
    required this.isUser,
    required this.receivedAt,
  });

  final GdSpeaker speaker;
  final String speakerName;

  /// The emoji avatar the server sends (e.g. `'🔵'`) — not a asset/image.
  final String avatar;

  /// A `#RRGGBB` hex string (e.g. `'#4F8EF7'`) straight from the server.
  final String colorHex;
  final String content;
  final bool isUser;
  final DateTime receivedAt;
}
