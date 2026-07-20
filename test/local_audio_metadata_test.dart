import 'dart:convert';

import 'package:coral_music_mobile/features/library/data/local_audio_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads common ID3v2 metadata and embedded cover', () {
    final tag = [
      ..._textFrame('TIT2', '春日海风'),
      ..._textFrame('TPE1', '珊瑚'),
      ..._textFrame('TALB', '海岸线'),
      ..._textFrame('TDRC', '2026-07-20'),
      ..._textFrame('TCON', '流行'),
      ..._frame('APIC', [
        3,
        ...ascii.encode('image/png'),
        0,
        3,
        0,
        0x89,
        0x50,
        0x4e,
        0x47,
      ]),
    ];
    final metadata = parseId3v2Metadata([
      0x49,
      0x44,
      0x33,
      3,
      0,
      0,
      ..._syncSafe(tag.length),
      ...tag,
    ]);

    expect(metadata.title, '春日海风');
    expect(metadata.artist, '珊瑚');
    expect(metadata.album, '海岸线');
    expect(metadata.year, '2026');
    expect(metadata.genre, '流行');
    expect(metadata.artworkExtension, 'png');
    expect(metadata.artwork, [0x89, 0x50, 0x4e, 0x47]);
  });

  test('reads FLAC comments and embedded cover', () {
    final comments = [
      ..._littleEndian(0),
      ..._littleEndian(5),
      ..._comment('TITLE=夜航'),
      ..._comment('ARTIST=珊瑚'),
      ..._comment('ALBUM=海面'),
      ..._comment('DATE=2025'),
      ..._comment('GENRE=电子'),
    ];
    final picture = [
      0,
      0,
      0,
      3,
      0,
      0,
      0,
      9,
      ...ascii.encode('image/png'),
      0,
      0,
      0,
      0,
      ...List.filled(16, 0),
      0,
      0,
      0,
      4,
      0x89,
      0x50,
      0x4e,
      0x47,
    ];
    final metadata = parseFlacMetadata([
      ...ascii.encode('fLaC'),
      4,
      ..._uint24(comments.length),
      ...comments,
      0x86,
      ..._uint24(picture.length),
      ...picture,
    ]);

    expect(metadata.title, '夜航');
    expect(metadata.artist, '珊瑚');
    expect(metadata.album, '海面');
    expect(metadata.year, '2025');
    expect(metadata.genre, '电子');
    expect(metadata.artworkExtension, 'png');
    expect(metadata.artwork, [0x89, 0x50, 0x4e, 0x47]);
  });

  test('reads M4A ilst labels and embedded cover', () {
    final ilst = _atom('ilst', [
      ..._m4aItem('©nam', utf8.encode('日落海岸')),
      ..._m4aItem('©ART', utf8.encode('珊瑚')),
      ..._m4aItem('©alb', utf8.encode('夏日信笺')),
      ..._m4aItem('©day', utf8.encode('2024-08-01')),
      ..._m4aItem('©gen', utf8.encode('流行')),
      ..._m4aItem('covr', [
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]),
    ]);
    final metadata = parseM4aMetadata(_atom('moov', [
      ..._atom('udta', [
        ..._atom('meta', [0, 0, 0, 0, ...ilst]),
      ]),
    ]));

    expect(metadata.title, '日落海岸');
    expect(metadata.artist, '珊瑚');
    expect(metadata.album, '夏日信笺');
    expect(metadata.year, '2024');
    expect(metadata.genre, '流行');
    expect(metadata.artworkExtension, 'png');
    expect(metadata.artwork, [
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
  });

  test('reads Opus Vorbis comment labels', () {
    final comments = [
      ..._littleEndian(0),
      ..._littleEndian(5),
      ..._comment('TITLE=薄暮'),
      ..._comment('ARTIST=珊瑚'),
      ..._comment('ALBUM=潮汐'),
      ..._comment('DATE=2023'),
      ..._comment('GENRE=氛围'),
    ];
    final metadata = parseOggMetadata([
      ..._oggPage([...ascii.encode('OpusHead'), ...List.filled(11, 0)]),
      ..._oggPage([...ascii.encode('OpusTags'), ...comments]),
    ]);

    expect(metadata.title, '薄暮');
    expect(metadata.artist, '珊瑚');
    expect(metadata.album, '潮汐');
    expect(metadata.year, '2023');
    expect(metadata.genre, '氛围');
  });

  test('reads WAV RIFF INFO labels', () {
    final info = _riffChunk('LIST', [
      ...ascii.encode('INFO'),
      ..._riffChunk('INAM', [...latin1.encode('Waves'), 0]),
      ..._riffChunk('IART', [...latin1.encode('Coral'), 0]),
      ..._riffChunk('IPRD', [...latin1.encode('Ocean'), 0]),
      ..._riffChunk('ICRD', [...latin1.encode('2022'), 0]),
      ..._riffChunk('IGNR', [...latin1.encode('Ambient'), 0]),
    ]);
    final metadata = parseWavMetadata([
      ...ascii.encode('RIFF'),
      ..._littleEndian(0),
      ...ascii.encode('WAVE'),
      ...info,
    ]);

    expect(metadata.title, 'Waves');
    expect(metadata.artist, 'Coral');
    expect(metadata.album, 'Ocean');
    expect(metadata.year, '2022');
    expect(metadata.genre, 'Ambient');
  });
}

List<int> _textFrame(String id, String value) =>
    _frame(id, [3, ...utf8.encode(value)]);

List<int> _frame(String id, List<int> value) => [
      ...ascii.encode(id),
      (value.length >> 24) & 0xff,
      (value.length >> 16) & 0xff,
      (value.length >> 8) & 0xff,
      value.length & 0xff,
      0,
      0,
      ...value,
    ];

List<int> _syncSafe(int value) => [
      (value >> 21) & 0x7f,
      (value >> 14) & 0x7f,
      (value >> 7) & 0x7f,
      value & 0x7f,
    ];

List<int> _littleEndian(int value) => [
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ];

List<int> _comment(String value) => [
      ..._littleEndian(utf8.encode(value).length),
      ...utf8.encode(value),
    ];

List<int> _uint24(int value) => [
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];

List<int> _atom(String type, List<int> body) => [
      ..._uint32(body.length + 8),
      ...latin1.encode(type),
      ...body,
    ];

List<int> _m4aItem(String type, List<int> value) => _atom(
      type,
      _atom('data', [0, 0, 0, 1, 0, 0, 0, 0, ...value]),
    );

List<int> _uint32(int value) => [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];

List<int> _oggPage(List<int> packet) => [
      ...ascii.encode('OggS'),
      0,
      0,
      ...List.filled(8, 0),
      ...List.filled(4, 0),
      ...List.filled(4, 0),
      ...List.filled(4, 0),
      1,
      packet.length,
      ...packet,
    ];

List<int> _riffChunk(String type, List<int> body) => [
      ...latin1.encode(type),
      ..._littleEndian(body.length),
      ...body,
      if (body.length.isOdd) 0,
    ];
