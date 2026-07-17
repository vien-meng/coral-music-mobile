import 'dart:convert';
import 'dart:io';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/search/data/kuwo_search_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes and de-duplicates Kuwo search tracks', () async {
    final text = await File('test/fixtures/kuwo_search.json').readAsString();
    final result = KuwoSearchParser.parse(
      jsonDecode(text) as Map<String, Object?>,
      page: 2,
    );

    expect(result.page, 2);
    expect(result.pageSize, 30);
    expect(result.total, 2);
    expect(result.items, hasLength(2));
    expect(result.items.first.id, 'online:kw:123');
    expect(result.items.first.title, '晴天&雨');
    expect(result.items.first.artist, '周杰伦、测试歌手');
    expect(result.items.first.duration, const Duration(seconds: 269));
    expect(
      result.items.first.coverUri.toString(),
      'https://img3.kuwo.cn/star/albumcover/500/s3s94/93/211513640.jpg',
    );
    expect(
      result.items.first.availableQualities,
      [AudioQuality.flac, AudioQuality.high320k, AudioQuality.standard128k],
    );
    expect(result.items.last.availableQualities, [AudioQuality.flac24bit]);
  });
}
