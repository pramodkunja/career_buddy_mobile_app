import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/roleplay_generated_content.dart';

/// Parses `roleplay_practice`'s response body (`activities/views.py:2076-2080`,
/// `{"topic": ..., "used_prompt": ..., "result": {...}}`) — [json] is the
/// whole decoded body, not just the nested `result` object, since
/// [RoleplayGeneratedContent.usedPrompt] lives at the top level, a sibling
/// of `result`, not inside it.
extension RoleplayGeneratedContentParsing on RoleplayGeneratedContent {
  static RoleplayGeneratedContent fromResponseJson(Map<String, dynamic> json) {
    final result = requireMap(json, 'result');
    return RoleplayGeneratedContent(
      usedPrompt: requireString(json, 'used_prompt'),
      title: requireString(result, 'title'),
      contentHeading: requireString(result, 'content_heading'),
      content: requireString(result, 'content'),
      followUps: requireList(
        result,
        'follow_ups',
      ).map((e) => e is String ? e : (throw FormatException('Expected "follow_ups[]" to be a string, got: $e'))).toList(),
      coachTip: requireString(result, 'coach_tip'),
    );
  }
}
