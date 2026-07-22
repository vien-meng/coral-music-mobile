import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'user_api_script_fetcher.dart';

class UserApiSourcePreferences {
  UserApiSourcePreferences([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'user-api:active-url-source';
  static const _localKey = 'user-api:active-local-source';
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
      await _storage.delete(key: _localKey);
    } on Object {
      // ponytail: session-only scripts remain usable if secure storage is unavailable.
    }
  }

  Future<({String name, String script})?> readLocalScript() async {
    try {
      final raw = await _storage.read(key: _localKey);
      if (raw == null) return null;
      final name = (jsonDecode(raw) as Map<String, dynamic>)['name'] as String?;
      final script = await (await _localScriptFile()).readAsString();
      return name == null ||
              script.trim().isEmpty ||
              script.length > UserApiScriptFetcher.maxBytes
          ? null
          : (name: name, script: script);
    } on Object {
      return null;
    }
  }

  Future<void> saveLocalScript(String name, String script) async {
    if (script.trim().isEmpty ||
        script.length > UserApiScriptFetcher.maxBytes) {
      return;
    }
    try {
      final file = await _localScriptFile();
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(script, flush: true);
      await temporary.rename(file.path);
      await _storage.write(key: _localKey, value: jsonEncode({'name': name}));
      await _storage.delete(key: _key);
    } on Object {
      // ponytail: file import remains usable for this session if persistence fails.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
      await _storage.delete(key: _localKey);
      final file = await _localScriptFile();
      if (await file.exists()) await file.delete();
    } on Object {
      // ponytail: there is no persisted URL to remove when secure storage is unavailable.
    }
  }

  Future<String?> readCachedScript(Uri url) async {
    try {
      final script = await (await _scriptFile(url)).readAsString();
      return script.trim().isEmpty ||
              script.length > UserApiScriptFetcher.maxBytes
          ? null
          : script;
    } on FileSystemException {
      return null;
    } on Object {
      return null;
    }
  }

  Future<void> cacheScript(Uri url, String script) async {
    if (script.trim().isEmpty ||
        script.length > UserApiScriptFetcher.maxBytes) {
      return;
    }
    try {
      final file = await _scriptFile(url);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(script, flush: true);
      await temporary.rename(file.path);
    } on FileSystemException {
      // ponytail: a network-loaded source remains usable when its local cache cannot be written.
    } on Object {
      // ponytail: unsupported platforms fall back to the existing secure URL preference.
    }
  }

  Future<File> _scriptFile(Uri url) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final key = base64Url
        .encode(sha256.convert(utf8.encode(url.toString())).bytes)
        .replaceAll('=', '');
    final directory = Directory('${supportDirectory.path}/user-api-scripts');
    await directory.create(recursive: true);
    return File('${directory.path}/$key.js');
  }

  Future<File> _localScriptFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory('${supportDirectory.path}/user-api-scripts');
    await directory.create(recursive: true);
    return File('${directory.path}/imported.js');
  }
}
