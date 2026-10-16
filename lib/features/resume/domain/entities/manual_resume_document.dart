/// The assembled resume document `preview_api` returns — a faithful model
/// of `career_app/resume_document.py`'s `build_document()` return shape
/// (verified directly). This is **pure structured data, never HTML** — the
/// real web itself only ever turns this into markup client-side
/// (`landing.html`'s own `docHTML()`, confirmed directly: no Django
/// template or server-rendered HTML fragment exists for this preview
/// anywhere in the reference source). [ManualResumeSectionBody]'s
/// subclasses mirror `docHTML()`'s own per-`kind` switch exactly, so the
/// Flutter rendering can follow the same logic natively.
library;

/// One `document['contact']` entry — `{'text', 'href'}`. `href` is `''`
/// when the real value couldn't be turned into a safe link (e.g. an
/// invalid email), matching `build_document()`'s own defensive checks
/// (`resume_document.py:556-568`) — never invented here.
class ManualResumeContact {
  const ManualResumeContact({required this.text, required this.href});
  final String text;
  final String href;
}

/// One `sections[].kind == 'jobs'` or `'projects'` item's shared shape —
/// `projects` additionally carries [tech] (`build_document()`'s `_job_items`
/// vs. the inline `projects` list comprehension, `resume_document.py:508-519`
/// /`597-603`).
class ManualResumeWorkItem {
  const ManualResumeWorkItem({
    required this.title,
    required this.subtitle,
    this.location = '',
    required this.dates,
    this.duration = '',
    required this.bullets,
    this.tech = '',
  });

  final String title;
  final String subtitle;
  final String location;
  final String dates;
  final String duration;
  final List<String> bullets;
  final String tech;
}

/// One skill group inside a `kind: 'skills'` section
/// (`resume_document.py:584-595`'s `skill_groups`).
class ManualResumeSkillGroup {
  const ManualResumeSkillGroup({required this.label, required this.items});
  final String label;
  final List<String> items;
}

/// One `kind: 'compact'` item (Certifications/Training,
/// `resume_document.py:616-617`).
class ManualResumeCompactItem {
  const ManualResumeCompactItem({required this.title, required this.subtitle, required this.dates});
  final String title;
  final String subtitle;
  final String dates;
}

/// One `kind: 'education'` item (`resume_document.py:623-626`) — [meta] is
/// the server's own already-joined "institution | location | year | score"
/// string, not re-split here.
class ManualResumeEducationItem {
  const ManualResumeEducationItem({required this.title, required this.meta});
  final String title;
  final String meta;
}

class ManualResumeDeclarationBody {
  const ManualResumeDeclarationBody({
    required this.text,
    required this.place,
    required this.date,
    required this.name,
  });
  final String text;
  final String place;
  final String date;
  final String name;
}

/// One resume section's own content, keyed by its `kind`
/// (`resume_document.py:543-662`) — mirrors `docHTML()`'s per-`kind`
/// branch (`landing.html:8950-8974`) exactly, so each subclass maps 1:1 to
/// one rendering branch.
sealed class ManualResumeSectionBody {
  const ManualResumeSectionBody();
}

final class ManualResumeTextBody extends ManualResumeSectionBody {
  const ManualResumeTextBody(this.text);
  final String text;
}

final class ManualResumeBulletsBody extends ManualResumeSectionBody {
  const ManualResumeBulletsBody(this.items);
  final List<String> items;
}

final class ManualResumeJobsBody extends ManualResumeSectionBody {
  const ManualResumeJobsBody(this.items);
  final List<ManualResumeWorkItem> items;
}

final class ManualResumeProjectsBody extends ManualResumeSectionBody {
  const ManualResumeProjectsBody(this.items);
  final List<ManualResumeWorkItem> items;
}

final class ManualResumeSkillsBody extends ManualResumeSectionBody {
  const ManualResumeSkillsBody(this.groups);
  final List<ManualResumeSkillGroup> groups;
}

final class ManualResumeCompactBody extends ManualResumeSectionBody {
  const ManualResumeCompactBody(this.items);
  final List<ManualResumeCompactItem> items;
}

final class ManualResumeEducationBody extends ManualResumeSectionBody {
  const ManualResumeEducationBody(this.items);
  final List<ManualResumeEducationItem> items;
}

final class ManualResumeDeclarationSectionBody extends ManualResumeSectionBody {
  const ManualResumeDeclarationSectionBody(this.declaration);
  final ManualResumeDeclarationBody declaration;
}

/// An unrecognised `kind` — defensive fallback only (every `kind` the real
/// server ever emits is already covered by the subclasses above); never
/// thrown, just rendered as nothing rather than crashing the preview over
/// a single unexpected section.
final class ManualResumeUnknownBody extends ManualResumeSectionBody {
  const ManualResumeUnknownBody(this.kind);
  final String kind;
}

/// One `document['sections']` entry (`resume_document.py:572-653`, each
/// tagged with its own `key` at line 661).
class ManualResumeDocumentSection {
  const ManualResumeDocumentSection({required this.key, required this.heading, required this.body});
  final String key;
  final String heading;
  final ManualResumeSectionBody body;
}

/// `preview_api`'s `document` field in full (`build_document()`'s return
/// dict, `resume_document.py:654-662`).
class ManualResumeDocument {
  const ManualResumeDocument({
    required this.name,
    required this.title,
    required this.contact,
    required this.level,
    required this.levelLabel,
    required this.role,
    required this.sections,
  });

  final String name;
  final String title;
  final List<ManualResumeContact> contact;
  final String level;
  final String levelLabel;
  final String role;
  final List<ManualResumeDocumentSection> sections;
}
