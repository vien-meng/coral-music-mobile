import 'dart:convert';
import 'dart:io';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/independent_lyric_service.dart';
import 'package:coral_music_mobile/features/player/data/kugou_krc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes KRC into LX word timings', () {
    final payload = _encodeKrc('[1000,800]<0,300,0>你<300,500,0>好');

    expect(decodeKugouKrc(payload), '[00:01.000]<1000,300>你<1300,500>好');
  });

  test('chooses the matching KuGou lyric instead of the first candidate', () {
    final candidate = selectKugouLyricCandidate(
        [
          {'id': 'wrong', 'accesskey': 'a', 'song': '别的歌', 'singer': '别人'},
          {
            'id': 'right',
            'accesskey': 'b',
            'song': '目标歌曲',
            'singer': '目标歌手',
            'duration': 180,
            'krctype': 1,
            'contenttype': 0,
          },
        ],
        const Track(
          sourceKind: TrackSourceKind.online,
          sourceId: 'kg',
          sourceTrackId: '1',
          title: '目标歌曲',
          artist: '目标歌手',
          duration: Duration(minutes: 3),
        ));

    expect(candidate?['id'], 'right');
  });
}

String _encodeKrc(String lyric) {
  const key = [
    0x40,
    0x47,
    0x61,
    0x77,
    0x5e,
    0x32,
    0x74,
    0x47,
    0x51,
    0x36,
    0x31,
    0x2d,
    0xce,
    0xd2,
    0x6e,
    0x69,
  ];
  final compressed = ZLibEncoder().convert(utf8.encode(lyric));
  for (var index = 0; index < compressed.length; index++) {
    compressed[index] ^= key[index % key.length];
  }
  return base64.encode([0, 0, 0, 0, ...compressed]);
}
