import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'user_api_script_fetcher.dart';

final class UserApiSavedSource {
  const UserApiSavedSource({
    required this.id,
    required this.name,
    required this.script,
    this.originUrl,
  });

  final String id;
  final String name;
  final String script;
  final Uri? originUrl;
}

final class UserApiSavedSources {
  const UserApiSavedSources({
    required this.sources,
    this.activeSourceId,
  });

  final List<UserApiSavedSource> sources;
  final String? activeSourceId;
}

class UserApiSourcePreferences {
  UserApiSourcePreferences([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'user-api:active-url-source';
  static const _localKey = 'user-api:active-local-source';
  static const _sourcesKey = 'user-api:sources-v2';
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

  Future<UserApiSavedSources?> readSources() async {
    try {
      final raw = await _storage.read(key: _sourcesKey);
      if (raw == null) return null;
      final data = jsonDecode(raw);
      if (data is! Map || data['sources'] is! List) return null;
      final sources = <UserApiSavedSource>[];
      for (final value in data['sources'] as List) {
        if (value is! Map) continue;
        final id = value['id'] as String?;
        final name = value['name'] as String?;
        if (id == null || name == null || !_isSafeSourceId(id)) continue;
        final script = await _readSourceScript(id);
        if (script == null) continue;
        final rawUrl = value['originUrl'] as String?;
        final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
        sources.add(UserApiSavedSource(
          id: id,
          name: name,
          script: script,
          originUrl: uri?.scheme == 'https' ? uri : null,
        ));
      }
      if (sources.isEmpty) return null;
      final activeSourceId = data['activeSourceId'] as String?;
      return UserApiSavedSources(
        sources: sources,
        activeSourceId: sources.any((source) => source.id == activeSourceId)
            ? activeSourceId
            : null,
      );
    } on Object {
      return null;
    }
  }

  Future<void> saveSources(
    List<UserApiSavedSource> sources, {
    String? activeSourceId,
  }) async {
    if (sources.isEmpty) return clear();
    try {
      final entries = <Map<String, String>>[];
      for (final source in sources) {
        if (!_isSafeSourceId(source.id) ||
            source.name.trim().isEmpty ||
            source.script.trim().isEmpty ||
            source.script.length > UserApiScriptFetcher.maxBytes) {
          continue;
        }
        await _writeSourceScript(source.id, source.script);
        entries.add({
          'id': source.id,
          'name': source.name,
          if (source.originUrl != null)
            'originUrl': source.originUrl.toString(),
        });
      }
      if (entries.isEmpty) return;
      await _storage.write(
        key: _sourcesKey,
        value: jsonEncode({
          'activeSourceId': activeSourceId,
          'sources': entries,
        }),
      );
      await _storage.delete(key: _key);
      await _storage.delete(key: _localKey);
      final legacy = await _localScriptFile();
      if (await legacy.exists()) await legacy.delete();
    } on Object {
      // ponytail: the in-memory source list stays usable if persistence fails.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
      await _storage.delete(key: _localKey);
      await _storage.delete(key: _sourcesKey);
      final file = await _localScriptFile();
      if (await file.exists()) await file.delete();
      final directory = await _sourceScriptsDirectory();
      if (await directory.exists()) await directory.delete(recursive: true);
    } on Object {
      // ponytail: unavailable secure storage leaves no persisted source data to remove.
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

  Future<String?> _readSourceScript(String id) async {
    try {
      final script = await (await _sourceScriptFile(id)).readAsString();
      return script.trim().isEmpty ||
              script.length > UserApiScriptFetcher.maxBytes
          ? null
          : script;
    } on Object {
      return null;
    }
  }

  Future<void> _writeSourceScript(String id, String script) async {
    final file = await _sourceScriptFile(id);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(script, flush: true);
    await temporary.rename(file.path);
  }

  Future<File> _sourceScriptFile(String id) async {
    final directory = await _sourceScriptsDirectory();
    return File('${directory.path}/$id.js');
  }

  Future<Directory> _sourceScriptsDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory('${supportDirectory.path}/user-api-sources');
    await directory.create(recursive: true);
    return directory;
  }

  static bool _isSafeSourceId(String value) =>
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
}
