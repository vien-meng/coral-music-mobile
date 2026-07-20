import 'package:coral_music_mobile/features/webdav/data/webdav_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps WebDAV parent navigation inside the configured root', () {
    final root = Uri.parse('https://dav.example.com/music/');

    expect(
      parentWebDavDirectory(
        Uri.parse('https://dav.example.com/music/album/disc/'),
        root,
      ),
      Uri.parse('https://dav.example.com/music/album/'),
    );
    expect(parentWebDavDirectory(root, root), isNull);
    expect(
      parentWebDavDirectory(Uri.parse('https://dav.example.com/other/'), root),
      isNull,
    );
  });

  test('builds breadcrumbs only inside the configured root', () {
    final root = Uri.parse('https://dav.example.com/music/');
    final breadcrumbs = webDavBreadcrumbs(
      Uri.parse('https://dav.example.com/music/album/disc-1/'),
      root,
    );

    expect(
      breadcrumbs.map((item) => item.path),
      ['/music/', '/music/album/', '/music/album/disc-1/'],
    );
    expect(
      webDavBreadcrumbs(Uri.parse('https://dav.example.com/other/'), root),
      [root],
    );
  });
}
