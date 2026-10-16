/// The assembled resume document `preview_api`/`pages_api`/`pdf_download`
/// all build from (`career_app.create_resume.build_document()`, verified
/// directly). A different shape from [ManualResumeDocument] — the real web
/// has two separate resume builders with two separate document schemas, not
/// one shared format (confirmed: `create_resume.py`'s own `kind` values are
/// `text`/`lines`/`entries`/`items`, never [ManualResumeDocument]'s
/// `jobs`/`projects`/`skills`/`compact`/`education`/`declaration`).
library;

class CreateResumeContact {
  const CreateResumeContact({required this.text, required this.href});
  final String text;
  final String href;
}

class CreateResumeLink {
  const CreateResumeLink({required this.text, required this.href});
  final String text;
  final String href;
}

/// One `notes[]`/`groups[]` entry shared by several section kinds —
/// `{label, text}` for a note, `{label, bullets}` for a group.
class CreateResumeNote {
  const CreateResumeNote({required this.label, required this.text});
  final String label;
  final String text;
}

class CreateResumeBulletGroup {
  const CreateResumeBulletGroup({required this.label, required this.bullets});
  final String label;
  final List<String> bullets;
}

/// One `kind: 'entries'` item (experience/internships/volunteering/
/// projects/education, `build_document()`'s `job_items()`/inline loops).
class CreateResumeEntryItem {
  const CreateResumeEntryItem({
    required this.title,
    required this.subtitle,
    required this.meta,
    this.link,
    this.paragraphs = const [],
    this.bullets = const [],
    this.groups = const [],
    this.notes = const [],
  });

  final String title;
  final String subtitle;
  final String meta;
  final CreateResumeLink? link;
  final List<String> paragraphs;
  final List<String> bullets;
  final List<CreateResumeBulletGroup> groups;
  final List<CreateResumeNote> notes;
}

/// One `kind: 'items'` item (certifications/achievements) —
/// `{title, text, detail, link}`.
class CreateResumeCompactItem {
  const CreateResumeCompactItem({
    required this.title,
    required this.text,
    required this.detail,
    this.link,
  });
  final String title;
  final String text;
  final String detail;
  final CreateResumeLink? link;
}

/// One `kind: 'lines'` item (skills/additional) — `{label, text}`.
class CreateResumeLineItem {
  const CreateResumeLineItem({required this.label, required this.text});
  final String label;
  final String text;
}

sealed class CreateResumeSectionBody {
  const CreateResumeSectionBody();
}

final class CreateResumeTextBody extends CreateResumeSectionBody {
  const CreateResumeTextBody(this.text);
  final String text;
}

final class CreateResumeLinesBody extends CreateResumeSectionBody {
  const CreateResumeLinesBody(this.items);
  final List<CreateResumeLineItem> items;
}

final class CreateResumeEntriesBody extends CreateResumeSectionBody {
  const CreateResumeEntriesBody(this.items);
  final List<CreateResumeEntryItem> items;
}

final class CreateResumeItemsBody extends CreateResumeSectionBody {
  const CreateResumeItemsBody(this.items);
  final List<CreateResumeCompactItem> items;
}

/// Defensive fallback for a `kind` this app doesn't recognize — never
/// thrown, rendered as nothing rather than crashing the preview over one
/// unexpected section (same posture as [ManualResumeUnknownBody]).
final class CreateResumeUnknownBody extends CreateResumeSectionBody {
  const CreateResumeUnknownBody(this.kind);
  final String kind;
}

class CreateResumeDocumentSection {
  const CreateResumeDocumentSection({
    required this.key,
    required this.heading,
    required this.body,
  });
  final String key;
  final String heading;
  final CreateResumeSectionBody body;
}

/// `build_document()`'s full return shape.
class CreateResumeDocument {
  const CreateResumeDocument({
    required this.template,
    required this.name,
    required this.title,
    required this.contact,
    required this.links,
    required this.address,
    required this.sections,
  });

  final String template;
  final String name;
  final String title;
  final List<CreateResumeContact> contact;
  final List<CreateResumeLink> links;
  final String address;
  final List<CreateResumeDocumentSection> sections;
}
