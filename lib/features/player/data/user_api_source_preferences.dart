import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class UserApiSourcePreferences {
  UserApiSourcePreferences([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'user-api:active-url-source';
  final FlutterSecureStorage _storage;

  Future<({String name, Uri url})?> read() async {
    String? raw;
    try {
      raw = await _storage.read(key: _key);
    } on Object {
      return null;
    }
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final name = data['name'] as String?;
      final url = Uri.tryParse(data['url'] as String? ?? '');
      return name == null || url == null || url.scheme != 'https'
          ? null
          : (name: name, url: url);
    } on Object {
      return null;
    }
  }

  Future<void> save(String name, Uri url) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({'name': name, 'url': url.toString()}),
      );
    } on Object {
      // ponytail: session-only scripts remain usable if secure storage is unavailable.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object {
      // ponytail: there is no persisted URL to remove when secure storage is unavailable.
    }
  }
}
