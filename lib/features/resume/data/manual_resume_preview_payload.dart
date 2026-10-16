import '../domain/entities/manual_resume_draft.dart';

/// Builds the exact JSON body `preview_api` expects, verified directly
/// against `career_app/resume_document.py`'s `normalize_state(raw)` —
/// **snake_case** keys (`target_title`, `role_def`, `decl_date`) matching
/// `raw.get(...)`'s own calls exactly. This is deliberately **not**
/// [ManualResumeDraft.toJson], which uses this app's own camelCase local-
/// persistence schema (`targetTitle`, `roleDef`, `declDate`) — sending that
/// shape directly to Django would leave every one of those fields silently
/// read as missing (`raw.get('target_title')` → `None` → cleaned to `''`),
/// a real, silent correctness bug this separate mapping exists to avoid.
/// [ManualResumeDraft.currentStep] is never included — confirmed directly
/// that `normalize_state` has no such key and the server has no concept of
/// a wizard step at all.
Map<String, dynamic> toManualResumePreviewPayload(ManualResumeDraft draft) {
  Map<String, dynamic> job(ManualResumeJobEntry e) => {
    'title': e.title,
    'company': e.company,
    'location': e.location,
    'start': e.start,
    'end': e.end,
    'current': e.current,
    'bullets': e.bullets,
  };

  Map<String, dynamic> project(ManualResumeProjectEntry e) => {
    'name': e.name,
    'context': e.context,
    'tools': e.tools,
    'start': e.start,
    'end': e.end,
    'bullets': e.bullets,
  };

  Map<String, dynamic> education(ManualResumeEducationEntry e) => {
    'degree': e.degree,
    'institution': e.institution,
    'location': e.location,
    'year': e.year,
    'score': e.score,
  };

  Map<String, dynamic> certification(ManualResumeCertificationEntry e) => {
    'name': e.name,
    'issuer': e.issuer,
    'year': e.year,
  };

  Map<String, dynamic> training(ManualResumeTrainingEntry e) => {
    'name': e.name,
    'provider': e.provider,
    'year': e.year,
  };

  return {
    'role': draft.role,
    'role_def': draft.roleDef,
    'level': draft.level,
    'personal': {
      'name': draft.personal.name,
      'email': draft.personal.email,
      'phone': draft.personal.phone,
      'location': draft.personal.location,
      'linkedin': draft.personal.linkedin,
      'website': draft.personal.website,
      'dob': draft.personal.dob,
      'passport': draft.personal.passport,
    },
    'target_title': draft.targetTitle,
    'domain': draft.domain,
    'years': draft.years,
    'skills': {
      'groups': draft.skills.groups,
      'suggested': draft.skills.suggested,
      'soft': draft.skills.soft,
      'other': draft.skills.other,
    },
    'employment': draft.employment.map(job).toList(),
    'internships': draft.internships.map(job).toList(),
    'projects': draft.projects.map(project).toList(),
    'education': draft.education.map(education).toList(),
    'certifications': draft.certifications.map(certification).toList(),
    'training': draft.training.map(training).toList(),
    'achievements': draft.achievements,
    'languages': draft.languages,
    'additional': draft.additional,
    'summary': draft.summary,
    'declaration': draft.declaration,
    'place': draft.place,
    'decl_date': draft.declDate,
  };
}
