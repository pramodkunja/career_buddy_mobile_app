/// Defensive JSON-field extraction shared by every feature's `data/models/`
/// layer. A missing/wrong-type *required* field throws a [FormatException]
/// (callers map this to `UnexpectedResponseException`) rather than being
/// silently defaulted — a malformed response should never look like valid,
/// if sparse, data. Optional fields default safely instead.
library;

Map<String, dynamic> requireMap(Map<String, dynamic> json, String key) => asMap(json[key], key);

Map<String, dynamic> asMap(Object? value, String key) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('Expected "$key" to be an object, got: $value');
}

List<dynamic> requireList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw FormatException('Expected "$key" to be a list, got: $value');
}

List<dynamic>? optionalList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is List) return value;
  throw FormatException('Expected "$key" to be a list or null, got: $value');
}

String requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected "$key" to be a string, got: $value');
}

int requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected "$key" to be an int, got: $value');
}

num requireNum(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value;
  throw FormatException('Expected "$key" to be a number, got: $value');
}

bool requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Expected "$key" to be a bool, got: $value');
}

DateTime requireDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Expected "$key" to be an ISO-8601 date string, got: $value');
}

DateTime? optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return requireDateTime(json, key);
}
