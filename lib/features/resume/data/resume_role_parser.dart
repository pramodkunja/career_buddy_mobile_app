import '../domain/entities/resume_role.dart';

/// Parses `manual_resume_roles`'s real JSON response (verified directly
/// against `career_app/manual_resume_views.py:111`/`resume_roles.py`'s
/// `client_payload(full=True)` — a bare GET with no `?slug=`/`?spec=`
/// always returns `{"roles": [...], "levels": [...], ...}`). Only `roles`
/// is used here. Defensive by design: a malformed top-level shape yields
/// an empty list (never throws — the picker screen treats that the same
/// as a genuinely empty catalog, which is itself a real, handled state);
/// one malformed role entry inside an otherwise-valid list is skipped
/// individually rather than failing the whole parse, since the endpoint
/// is admin-extensible and a single bad admin-added row should not hide
/// every other real role.
List<ResumeRole> parseManualResumeRoles(dynamic body) {
  if (body is! Map<String, dynamic>) return const [];
  final rawRoles = body['roles'];
  if (rawRoles is! List) return const [];

  final roles = <ResumeRole>[];
  for (final entry in rawRoles) {
    if (entry is! Map<String, dynamic>) continue;
    final slug = entry['slug'];
    final title = entry['title'];
    final category = entry['category'];
    final subtitle = entry['subtitle'];
    if (slug is! String || title is! String || category is! String || subtitle is! String) continue;
    // `_remember_target_role` (`career_app/views.py:200-214`) only sets the
    // session role when BOTH role and dept slugify non-empty — a role
    // with an empty title/subtitle could never actually be selected
    // server-side, so it's excluded here rather than shown as a dead end.
    if (title.isEmpty || category.isEmpty || subtitle.isEmpty) continue;
    final categoryLabel = entry['category_label'];
    roles.add(
      ResumeRole(
        slug: slug,
        title: title,
        category: category,
        categoryLabel: categoryLabel is String && categoryLabel.isNotEmpty ? categoryLabel : category,
        subtitle: subtitle,
      ),
    );
  }
  return roles;
}
