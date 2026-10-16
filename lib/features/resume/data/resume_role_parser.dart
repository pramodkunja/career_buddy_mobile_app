import '../domain/entities/level_common_suggestions.dart';
import '../domain/entities/resume_role.dart';

List<String> _stringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

List<ResumeRoleSkillField> _parseFields(Object? value) {
  if (value is! List) return const [];
  final out = <ResumeRoleSkillField>[];
  for (final entry in value) {
    if (entry is! Map<String, dynamic>) continue;
    final key = entry['key'];
    final label = entry['label'];
    if (key is! String || label is! String || key.isEmpty || label.isEmpty) {
      continue;
    }
    out.add(
      ResumeRoleSkillField(
        key: key,
        label: label,
        options: _stringList(entry['options']),
      ),
    );
  }
  return out;
}

ResumeRoleLevelSuggestions _parseLevelSuggestions(Object? value) {
  if (value is! Map<String, dynamic>) return const ResumeRoleLevelSuggestions();
  return ResumeRoleLevelSuggestions(
    skills: _stringList(value['skills']),
    responsibilities: _stringList(value['responsibilities']),
    projects: _stringList(value['projects']),
    training: _stringList(value['training']),
  );
}

Map<String, ResumeRoleLevelSuggestions> _parseLevels(Object? value) {
  if (value is! Map<String, dynamic>) return const {};
  return {
    for (final key in kManualResumeLevelKeys)
      if (value[key] != null) key: _parseLevelSuggestions(value[key]),
  };
}

Map<String, List<String>> _parseSummaries(Object? value) {
  if (value is! Map<String, dynamic>) return const {};
  return {
    for (final key in kManualResumeLevelKeys)
      if (value[key] != null) key: _stringList(value[key]),
  };
}

/// Parses `manual_resume_roles`'s real JSON response (verified directly
/// against `career_app/manual_resume_views.py:111`/`resume_roles.py`'s
/// `client_payload(full=True)` — a bare GET with no `?slug=`/`?spec=`
/// always returns `{"roles": [...], "levels": [...], ...}`). Defensive by
/// design: a malformed top-level shape yields an empty list (never throws
/// — the picker screen treats that the same as a genuinely empty catalog,
/// which is itself a real, handled state); one malformed role entry inside
/// an otherwise-valid list is skipped individually rather than failing the
/// whole parse, since the endpoint is admin-extensible and a single bad
/// admin-added row should not hide every other real role.
///
/// Phase 26 extended this to also keep each role's `fields`/`levels`/
/// `summaries`/`recommended_skills`/`certifications`/`experience_label` —
/// previously discarded here since only the Role Picker (Phase 22/23)
/// existed yet. The Role Picker itself is unaffected: it never reads these
/// new fields.
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
    if (slug is! String ||
        title is! String ||
        category is! String ||
        subtitle is! String) {
      continue;
    }
    // `_remember_target_role` (`career_app/views.py:200-214`) only sets the
    // session role when BOTH role and dept slugify non-empty — a role
    // with an empty title/subtitle could never actually be selected
    // server-side, so it's excluded here rather than shown as a dead end.
    if (title.isEmpty || category.isEmpty || subtitle.isEmpty) continue;
    final categoryLabel = entry['category_label'];
    final experienceLabel = entry['experience_label'];
    roles.add(
      ResumeRole(
        slug: slug,
        title: title,
        category: category,
        categoryLabel: categoryLabel is String && categoryLabel.isNotEmpty
            ? categoryLabel
            : category,
        subtitle: subtitle,
        fields: _parseFields(entry['fields']),
        levels: _parseLevels(entry['levels']),
        summaries: _parseSummaries(entry['summaries']),
        recommendedSkills: _stringList(entry['recommended_skills']),
        certifications: _stringList(entry['certifications']),
        experienceLabel: experienceLabel is String && experienceLabel.isNotEmpty
            ? experienceLabel
            : 'Professional Experience',
      ),
    );
  }
  return roles;
}

/// Parses the same response's top-level `level_common`
/// (`resume_roles.py`'s `LEVEL_COMMON`, `client_payload`'s
/// `'level_common': LEVEL_COMMON`) — role-independent soft-skill and
/// achievement suggestions per experience level. Defensive like the role
/// parser above: a missing/malformed shape yields an empty map, never a
/// throw, treated by the builder exactly like "no suggestions available".
Map<String, LevelCommonSuggestions> parseLevelCommon(dynamic body) {
  if (body is! Map<String, dynamic>) return const {};
  final raw = body['level_common'];
  if (raw is! Map<String, dynamic>) return const {};
  final out = <String, LevelCommonSuggestions>{};
  for (final key in kManualResumeLevelKeys) {
    final entry = raw[key];
    if (entry is! Map<String, dynamic>) continue;
    final emphasis = entry['emphasis'];
    out[key] = LevelCommonSuggestions(
      softSkills: _stringList(entry['soft_skills']),
      achievements: _stringList(entry['achievements']),
      emphasis: emphasis is String ? emphasis : '',
    );
  }
  return out;
}
