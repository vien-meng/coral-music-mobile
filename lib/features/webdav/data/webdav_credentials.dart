import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';

final webDavCredentialsProvider = Provider((_) => WebDavCredentials());

final class WebDavCredentials {
  WebDavCredentials([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _accountsKey = 'webdav:accounts';

  Future<void> save(String accountId, String authorization) =>
      _storage.write(key: 'webdav:$accountId', value: authorization);

  Future<String?> read(String accountId) async {
    try {
      return await _storage.read(key: 'webdav:$accountId');
    } on Object {
      // ponytail: missing secure storage is equivalent to no usable WebDAV credential.
      return null;
    }
  }

  Future<void> remove(String accountId) =>
      _storage.delete(key: 'webdav:$accountId');

  Future<void> saveLastAccount(String accountId) =>
      _storage.write(key: 'webdav:last-account', value: accountId);

  Future<String?> readLastAccount() =>
      _storage.read(key: 'webdav:last-account');

  Future<void> clearLastAccount() =>
      _storage.delete(key: 'webdav:last-account');

  Future<List<WebDavAccount>> readAccounts() async =>
      decodeAccounts(await _storage.read(key: _accountsKey));

  Future<void> saveAccount(WebDavAccount account, String authorization) async {
    final accounts = await readAccounts();
    final updated = [
      ...accounts.where((item) => item.id != account.id),
      account,
    ];
    await _storage.write(key: 'webdav:${account.id}', value: authorization);
    await _storage.write(key: _accountsKey, value: encodeAccounts(updated));
    await saveLastAccount(account.id);
  }

  Future<void> removeAccount(String accountId) async {
    final accounts = await readAccounts();
    final updated = accounts.where((item) => item.id != accountId).toList();
    await _storage.delete(key: 'webdav:$accountId');
    if (updated.isEmpty) {
      await _storage.delete(key: _accountsKey);
      await clearLastAccount();
      return;
    }
    await _storage.write(key: _accountsKey, value: encodeAccounts(updated));
    if (await readLastAccount() == accountId) {
      await saveLastAccount(updated.last.id);
    }
  }

  static String encodeAccounts(List<WebDavAccount> accounts) => jsonEncode(
        accounts
            .map((account) => {
                  'id': account.id,
                  'name': account.name,
                  'endpoint': account.endpoint.toString(),
                  'rootPath': account.rootPath,
                })
            .toList(growable: false),
      );

  static List<WebDavAccount> decodeAccounts(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final values = jsonDecode(raw);
      if (values is! List) return const [];
      return values
          .whereType<Map>()
          .map((value) {
            final id = value['id'];
            final name = value['name'];
            final endpoint = Uri.tryParse(value['endpoint']?.toString() ?? '');
            if (id is! String || name is! String || endpoint == null) {
              return null;
            }
            return WebDavAccount(
              id: id,
              name: name,
              endpoint: endpoint,
              rootPath: value['rootPath']?.toString() ?? '/',
            );
          })
          .whereType<WebDavAccount>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }
}
