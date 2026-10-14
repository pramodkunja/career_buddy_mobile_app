/// One role from `manual_resume_roles` (`career_app/resume_roles.py`'s
/// `client_payload(full=True)['roles']`, confirmed by direct source read).
/// Only the fields this picker actually uses are kept here — the real
/// response also carries `fields`/`levels`/`summary_focus`/etc. (the
/// manual-builder's own form data), irrelevant until that feature exists.
class ResumeRole {
  const ResumeRole({
    required this.slug,
    required this.title,
    required this.category,
    required this.categoryLabel,
    required this.subtitle,
  });

  final String slug;

  /// `title` — the exact string the `role=` query parameter must carry
  /// (`career_app/role_fit.py`'s `_template_roles()` keys roles by
  /// `r['title']`, confirmed directly).
  final String title;

  /// `category` — one of `'it'`/`'tech'`/`'nt'` (`CATEGORY_LABELS`).
  /// **Not** the same string the `track=` query parameter needs — see
  /// [track].
  final String category;

  /// `category_label` — the human-readable form ("IT Role", "Non-IT ·
  /// Technical", "Non-IT · Non-Technical") for display only.
  final String categoryLabel;

  /// `subtitle` — the exact string the `dept=` query parameter must carry
  /// (same `_template_roles()` keying as [title]'s doc comment). Despite
  /// the parameter being named `dept`, this is the role's own subtitle
  /// field (e.g. "Frontend, backend, full-stack"), not a department name —
  /// confirmed directly against `pickRole()`'s own JS (`landing.html:8738`,
  /// `dept: r.sub` where `r.sub` is mapped from `subtitle` at line 7767).
  final String subtitle;

  /// The `track=` query parameter value — confirmed directly against both
  /// `pickRole()`'s JS (`landing.html:8738`, `track: r.c === 'it' ?
  /// 'tech' : 'nonit'`) and `role_fit.py`'s `_template_roles()` key
  /// construction (`'tech' if r['category'] == 'it' else 'nonit'`): only
  /// an `'it'`-category role maps to `'tech'`; **both** other categories
  /// (`'tech'`/`'nt'`) map to `'nonit'` — the role's own [category] string
  /// and this value share the word "tech" but are never interchangeable.
  String get track => category == 'it' ? 'tech' : 'nonit';
}
