/// Python's `str(bool)` convention (`"True"`/`"False"`, capitalized) — the
/// value every Django `TypedChoiceField` backing a yes/no question on this
/// app's forms actually expects, confirmed live against production
/// (`has_experience`/`has_abroad_experience`'s `<option value="True">`/
/// `<option value="False">`). Dart's own `bool.toString()` produces
/// lowercase `"true"`/`"false"`, which matches neither `<option>`'s value,
/// so Django's `ChoiceField` rejects the whole submission with "Select a
/// valid choice" — shared by every remote datasource that posts one of
/// these fields (Profile Edit, Registration) so the fix lives in exactly
/// one place.
String djangoBool(bool value) => value ? 'True' : 'False';
