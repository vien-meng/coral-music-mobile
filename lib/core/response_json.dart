import 'dart:convert';

/// Accepts JSON objects returned as JSON, JSONP, or Kuwo's single-quoted text.
Map<Object?, Object?> decodeJsonMap(Object? raw) {
  if (raw is Map) return Map<Object?, Object?>.from(raw);
  if (raw is! String) return const {};
  final text = raw.trim().replaceFirst('\ufeff', '');
  final decoded =
      _decode(text) ?? _decodeJsonp(text) ?? _decodeSingleQuoted(text);
  return decoded is Map ? Map<Object?, Object?>.from(decoded) : const {};
}

Object? _decode(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

Object? _decodeJsonp(String text) {
  final start = text.indexOf('(');
  final end = text.lastIndexOf(')');
  if (start < 1 || end <= start) return null;
  return _decode(text.substring(start + 1, end).trim());
}

Object? _decodeSingleQuoted(String text) {
  final normalized = text
      .replaceAll(r"\'", "'")
      .replaceAllMapped(
          RegExp(r"(^|[\[{,:]\s*)'"), (match) => '${match.group(1)}"')
      .replaceAllMapped(RegExp(r"'(?=\s*[:,}\]])"), (_) => '"');
  return _decode(normalized);
}
