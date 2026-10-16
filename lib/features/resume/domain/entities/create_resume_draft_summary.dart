/// One row of `drafts_list`'s own `_summary(draft)` shape (confirmed
/// directly: `{id, title, template, updated}`) — never the full `data`
/// payload, which [CreateResumeFormState.fromDraftData] builds separately
/// from `draft_detail`'s own response.
class CreateResumeDraftSummary {
  const CreateResumeDraftSummary({
    required this.id,
    required this.title,
    required this.template,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String template;
  final DateTime updatedAt;

  factory CreateResumeDraftSummary.fromJson(Map<String, dynamic> json) =>
      CreateResumeDraftSummary(
        id: json['id'] as int,
        title: json['title'] as String? ?? 'Untitled resume',
        template: json['template'] as String? ?? 'classic',
        updatedAt:
            DateTime.tryParse(json['updated'] as String? ?? '') ??
            DateTime.now(),
      );
}
