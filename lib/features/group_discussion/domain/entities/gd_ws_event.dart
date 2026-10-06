import 'gd_message.dart';
import 'gd_report.dart';
import 'gd_speaker.dart';

/// The 4 real `type` values `GDConsumer._send` ever emits
/// (`GD_app/consumers.py`) — every server-to-client WebSocket frame parses
/// into exactly one of these. An unrecognized/malformed frame parses to
/// `null` (see `parseGdWsEvent`) rather than throwing, so one unexpected
/// frame can't take down the whole live connection.
sealed class GdWsEvent {
  const GdWsEvent();
}

/// `{"type": "status", "status": ..., "topic": ...}` — session-state
/// transitions. Real `status` values: `'started'` (with `topic`, sent once
/// right after `action: 'start'`), `'user_speaking'` (ack of the client's
/// own `action: 'user_speaking'`), `'analyzing'` (sent right after
/// `action: 'end'`, before the `report` event), `'ended'` (sent right after
/// the `report` event, once analysis + persistence is done).
class GdStatusEvent extends GdWsEvent {
  const GdStatusEvent({required this.status, this.topic});

  final String status;
  final String? topic;
}

/// `{"type": "typing", "speaker", "speaker_name", "avatar", "color"}` — an
/// agent is about to speak (sent right before the blocking Sarvam API call
/// in `_agent_loop`). Never sent for the user's own turn.
class GdTypingEvent extends GdWsEvent {
  const GdTypingEvent({
    required this.speaker,
    required this.speakerName,
    required this.avatar,
    required this.colorHex,
  });

  final GdSpeaker speaker;
  final String speakerName;
  final String avatar;
  final String colorHex;
}

/// `{"type": "message", ...}` — one transcript line, either an agent's
/// response or (echoed straight back) the user's own just-sent turn. See
/// [GdMessage]'s doc comment for the exact field mapping.
class GdMessageEvent extends GdWsEvent {
  const GdMessageEvent(this.message);

  final GdMessage message;
}

/// `{"type": "report", "report": {...}}` — the final performance report,
/// sent once, right after `status: 'analyzing'` and right before
/// `status: 'ended'`.
class GdReportEvent extends GdWsEvent {
  const GdReportEvent(this.report);

  final GdReport report;
}

/// Parses one already-JSON-decoded server frame. Returns `null` for an
/// unrecognized `type` (forward-compatibility) or a structurally-broken
/// payload, rather than throwing — a single bad frame must not crash the
/// live discussion.
GdWsEvent? parseGdWsEvent(Map<String, dynamic> json) {
  try {
    return switch (json['type']) {
      'status' => GdStatusEvent(status: json['status'] as String? ?? '', topic: json['topic'] as String?),
      'typing' => GdTypingEvent(
        speaker: GdSpeaker.fromKey(json['speaker'] as String?),
        speakerName: json['speaker_name'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '',
        colorHex: json['color'] as String? ?? '',
      ),
      'message' => GdMessageEvent(
        GdMessage(
          speaker: GdSpeaker.fromKey(json['speaker'] as String?),
          speakerName: json['speaker_name'] as String? ?? '',
          avatar: json['avatar'] as String? ?? '',
          colorHex: json['color'] as String? ?? '',
          content: json['content'] as String? ?? '',
          isUser: json['is_user'] as bool? ?? false,
          receivedAt: DateTime.now(),
        ),
      ),
      'report' => GdReportEvent(GdReport.fromJson((json['report'] as Map?)?.cast<String, dynamic>() ?? const {})),
      _ => null,
    };
  } catch (_) {
    return null;
  }
}
