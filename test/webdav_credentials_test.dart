import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/webdav/data/webdav_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WebDAV account index never serializes authorization', () {
    final encoded = WebDavCredentials.encodeAccounts([
      WebDavAccount(
        id: 'https://dav.example.com/music/',
        name: '家庭音乐库',
        endpoint: Uri.parse('https://dav.example.com/music/'),
      ),
    ]);

    final accounts = WebDavCredentials.decodeAccounts(encoded);

    expect(accounts.single.name, '家庭音乐库');
    expect(accounts.single.endpoint.host, 'dav.example.com');
    expect(encoded, isNot(contains('Authorization')));
  });
}
