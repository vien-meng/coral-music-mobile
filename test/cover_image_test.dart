import 'package:coral_music_mobile/app/cover_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('normalizes remote cover URLs and sends CDN request headers',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CoverImage(
          uri: Uri.parse('http://cover.example.com/album.jpg'),
          fallback: const SizedBox(),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as NetworkImage;
    expect(provider.url, 'https://cover.example.com/album.jpg');
    expect(provider.headers,
        coverImageHeadersFor(Uri.parse('https://cover.example.com/album.jpg')));
  });

  test('adds the source referer required by music CDNs', () {
    expect(
      coverImageHeadersFor(Uri.parse(
          'https://y.gtimg.cn/music/photo_new/T002albumR500x500M000.jpg')),
      containsPair('Referer', 'https://y.qq.com/'),
    );
    expect(
      coverImageHeadersFor(
          Uri.parse('https://qpic.y.qq.com/music_cover/cover/300')),
      containsPair('Referer', 'https://y.qq.com/'),
    );
    expect(
      coverImageHeadersFor(Uri.parse('https://p1.music.126.net/cover.jpg')),
      containsPair('Referer', 'https://music.163.com/'),
    );
  });
}
