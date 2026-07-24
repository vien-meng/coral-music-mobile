import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../platform/ohos_file_access.dart';

// ponytail: cap tag reads at 2 MiB; use a native metadata reader only if
// real-world libraries show larger embedded covers are common.
const _maxId3Bytes = 2 * 1024 * 1024;

final class LocalAudioMetadata {
  const LocalAudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.year,
    this.genre,
    this.artwork,
    this.artworkExtension,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? year;
  final String? genre;
  final Uint8List? artwork;
  final String? artworkExtension;

  Map<String, Object?> get extra => {
        if (year != null) 'year': year,
        if (genre != null) 'genre': genre,
      };
}

Future<LocalAudioMetadata> readLocalAudioMetadata(File file) async {
  try {
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'flac') {
      return parseFlacMetadata(await _readPrefix(file, _maxId3Bytes));
    }
    if (extension == 'ogg' || extension == 'opus') {
      return parseOggMetadata(await _readPrefix(file, _maxId3Bytes));
    }
    if (extension == 'wav') {
      return parseWavMetadata(await _readPrefix(file, _maxId3Bytes));
    }
    final header = await _readPrefix(file, 10);
    if (header.length >= 10 && _hasPrefix(header, 'ID3')) {
      final tagSize = _syncSafe(header, 6);
      if (tagSize <= 0) return const LocalAudioMetadata();
      return parseId3v2Metadata(await _readPrefix(
        file,
        (tagSize + 10).clamp(10, _maxId3Bytes).toInt(),
      ));
    }
    if (extension != 'm4a') return const LocalAudioMetadata();
    final prefix = parseM4aMetadata(await _readPrefix(file, _maxId3Bytes));
    if (_hasM4aValue(prefix)) return prefix;
    return parseM4aMetadata(await _readSuffix(file, _maxId3Bytes));
  } on Object {
    return const LocalAudioMetadata();
  }
}

LocalAudioMetadata parseFlacMetadata(List<int> raw) {
  final bytes = Uint8List.fromList(raw);
  if (bytes.length < 8 || !_hasPrefix(bytes, 'fLaC')) {
    return const LocalAudioMetadata();
  }
  String? title;
  String? artist;
  String? album;
  String? year;
  String? genre;
  Uint8List? artwork;
  String? artworkExtension;
  for (var offset = 4; offset + 4 <= bytes.length;) {
    final isLast = bytes[offset] & 0x80 != 0;
    final type = bytes[offset] & 0x7f;
    final length = (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    final bodyStart = offset + 4;
    final bodyEnd = bodyStart + length;
    if (bodyEnd > bytes.length) break;
    final body = Uint8List.sublistView(bytes, bodyStart, bodyEnd);
    if (type == 4) {
      final tags = _flacComments(body);
      title ??= tags['TITLE'];
      artist ??= tags['ARTIST'];
      album ??= tags['ALBUM'];
      year ??= _year(tags['DATE'] ?? tags['YEAR']);
      genre ??= _clean(tags['GENRE']);
    } else if (type == 6 && artwork == null) {
      final picture = _flacPicture(body);
      artwork = picture?.bytes;
      artworkExtension = picture?.extension;
    }
    offset = bodyEnd;
    if (isLast) break;
  }
  return LocalAudioMetadata(
    title: _clean(title),
    artist: _clean(artist),
    album: _clean(album),
    year: year,
    genre: genre,
    artwork: artwork,
    artworkExtension: artworkExtension,
  );
}

LocalAudioMetadata parseM4aMetadata(List<int> raw) {
  final bytes = Uint8List.fromList(raw);
  String? title;
  String? artist;
  String? album;
  String? year;
  String? genre;
  Uint8List? artwork;
  String? artworkExtension;

  void visit(int start, int end) {
    for (var offset = start; offset + 8 <= end;) {
      final length = _uint32(bytes, offset);
      if (length < 8 || offset + length > end) break;
      final type = latin1.decode(bytes.sublist(offset + 4, offset + 8));
      final bodyStart = offset + 8;
      final bodyEnd = offset + length;
      switch (type) {
        case 'moov' || 'udta':
          visit(bodyStart, bodyEnd);
          break;
        case 'meta':
          if (bodyStart + 4 <= bodyEnd) visit(bodyStart + 4, bodyEnd);
          break;
        case 'ilst':
          for (var item = bodyStart; item + 8 <= bodyEnd;) {
            final itemLength = _uint32(bytes, item);
            if (itemLength < 16 || item + itemLength > bodyEnd) break;
            final itemType = latin1.decode(bytes.sublist(item + 4, item + 8));
            final data = _m4aData(bytes, item + 8, item + itemLength);
            if (data != null) {
              switch (itemType) {
                case '©nam':
                  title ??= _m4aText(data);
                  break;
                case '©ART' || 'aART':
                  artist ??= _m4aText(data);
                  break;
                case '©alb':
                  album ??= _m4aText(data);
                  break;
                case '©day':
                  year ??= _year(_m4aText(data));
                  break;
                case '©gen':
                  genre ??= _m4aText(data);
                  break;
                case 'covr':
                  artwork ??= data.bytes;
                  artworkExtension ??= _imageExtension(data.bytes);
                  break;
              }
            }
            item += itemLength;
          }
          break;
      }
      offset += length;
    }
  }

  visit(0, bytes.length);
  return LocalAudioMetadata(
    title: _clean(title),
    artist: _clean(artist),
    album: _clean(album),
    year: year,
    genre: _clean(genre),
    artwork: artwork,
    artworkExtension: artworkExtension,
  );
}

LocalAudioMetadata parseOggMetadata(List<int> raw) {
  final bytes = Uint8List.fromList(raw);
  final packet = BytesBuilder(copy: false);
  String? title;
  String? artist;
  String? album;
  String? year;
  String? genre;
  Uint8List? artwork;
  String? artworkExtension;
  var offset = 0;
  while (offset + 27 <= bytes.length && _hasPrefixAt(bytes, offset, 'OggS')) {
    final segments = bytes[offset + 26];
    final tableStart = offset + 27;
    final dataStart = tableStart + segments;
    if (dataStart > bytes.length) break;
    var dataOffset = dataStart;
    for (var index = 0; index < segments; index++) {
      final length = bytes[tableStart + index];
      if (dataOffset + length > bytes.length) return const LocalAudioMetadata();
      packet.add(bytes.sublist(dataOffset, dataOffset + length));
      dataOffset += length;
      if (length == 255) continue;
      final value = packet.takeBytes();
      final commentOffset = _oggCommentOffset(value);
      if (commentOffset == null) continue;
      final tags = _flacComments(Uint8List.sublistView(value, commentOffset));
      title ??= tags['TITLE'];
      artist ??= tags['ARTIST'];
      album ??= tags['ALBUM'];
      year ??= _year(tags['DATE'] ?? tags['YEAR']);
      genre ??= _clean(tags['GENRE']);
      final cover = tags['METADATA_BLOCK_PICTURE'];
      if (artwork == null && cover != null) {
        try {
          final picture =
              _flacPicture(Uint8List.fromList(base64.decode(cover)));
          artwork = picture?.bytes;
          artworkExtension = picture?.extension;
        } on FormatException {
          // Invalid optional art must not discard readable text labels.
        }
      }
    }
    offset = dataOffset;
  }
  return LocalAudioMetadata(
    title: _clean(title),
    artist: _clean(artist),
    album: _clean(album),
    year: year,
    genre: genre,
    artwork: artwork,
    artworkExtension: artworkExtension,
  );
}

LocalAudioMetadata parseWavMetadata(List<int> raw) {
  final bytes = Uint8List.fromList(raw);
  if (bytes.length < 12 ||
      !_hasPrefix(bytes, 'RIFF') ||
      latin1.decode(bytes.sublist(8, 12)) != 'WAVE') {
    return const LocalAudioMetadata();
  }
  String? title;
  String? artist;
  String? album;
  String? year;
  String? genre;
  for (var offset = 12; offset + 8 <= bytes.length;) {
    final type = latin1.decode(bytes.sublist(offset, offset + 4));
    final length = _uint32Le(bytes, offset + 4);
    final bodyStart = offset + 8;
    final bodyEnd = bodyStart + length;
    if (bodyEnd > bytes.length) break;
    if (type == 'LIST' &&
        bodyStart + 4 <= bodyEnd &&
        latin1.decode(bytes.sublist(bodyStart, bodyStart + 4)) == 'INFO') {
      for (var item = bodyStart + 4; item + 8 <= bodyEnd;) {
        final itemType = latin1.decode(bytes.sublist(item, item + 4));
        final itemLength = _uint32Le(bytes, item + 4);
        final itemStart = item + 8;
        final itemEnd = itemStart + itemLength;
        if (itemEnd > bodyEnd) break;
        final value = _clean(latin1.decode(bytes.sublist(itemStart, itemEnd)));
        switch (itemType) {
          case 'INAM':
            title ??= value;
            break;
          case 'IART':
            artist ??= value;
            break;
          case 'IPRD':
            album ??= value;
            break;
          case 'ICRD':
            year ??= _year(value);
            break;
          case 'IGNR':
            genre ??= value;
            break;
        }
        item = itemEnd + itemLength.remainder(2);
      }
    }
    offset = bodyEnd + length.remainder(2);
  }
  return LocalAudioMetadata(
    title: _clean(title),
    artist: _clean(artist),
    album: _clean(album),
    year: year,
    genre: _clean(genre),
  );
}

Future<Uri?> cacheEmbeddedArtwork(
    File source, LocalAudioMetadata metadata) async {
  final artwork = metadata.artwork;
  if (artwork == null || artwork.isEmpty) return null;
  try {
    final stat = await source.stat();
    final key = sha1
        .convert(utf8
            .encode('${source.absolute.path}:${stat.size}:${stat.modified}'))
        .toString();
    final directory = await OhosFileAccess.applicationSupportDirectory();
    final extension = metadata.artworkExtension ?? 'jpg';
    final target = File('${directory.path}/local-covers/$key.$extension');
    if (!await target.exists()) {
      await target.parent.create(recursive: true);
      await target.writeAsBytes(artwork, flush: true);
    }
    return target.absolute.uri;
  } on Object {
    return null;
  }
}

LocalAudioMetadata parseId3v2Metadata(List<int> raw) {
  final bytes = Uint8List.fromList(raw);
  if (bytes.length < 10 || !_hasPrefix(bytes, 'ID3')) {
    return const LocalAudioMetadata();
  }
  final version = bytes[3];
  if (version != 3 && version != 4) return const LocalAudioMetadata();
  final hasUnsynchronisation = bytes[5] & 0x80 != 0;
  final end = (10 + _syncSafe(bytes, 6)).clamp(10, bytes.length);
  String? title;
  String? artist;
  String? album;
  String? year;
  String? genre;
  Uint8List? artwork;
  String? artworkExtension;

  for (var offset = 10; offset + 10 <= end;) {
    final id =
        ascii.decode(bytes.sublist(offset, offset + 4), allowInvalid: true);
    if (id.trim().isEmpty || id.contains('\u0000')) break;
    final size = version == 4
        ? _syncSafe(bytes, offset + 4)
        : _uint32(bytes, offset + 4);
    final frameStart = offset + 10;
    final frameEnd = frameStart + size;
    if (size <= 0 || frameEnd > end) break;
    var frame = Uint8List.sublistView(bytes, frameStart, frameEnd);
    if (hasUnsynchronisation) frame = _removeUnsynchronisation(frame);
    switch (id) {
      case 'TIT2':
        title ??= _text(frame);
        break;
      case 'TPE1':
        artist ??= _text(frame);
        break;
      case 'TALB':
        album ??= _text(frame);
        break;
      case 'TDRC' || 'TYER':
        year ??= _year(_text(frame));
        break;
      case 'TCON':
        genre ??= _clean(_text(frame));
        break;
      case 'APIC':
        final picture = _picture(frame);
        artwork ??= picture?.bytes;
        artworkExtension ??= picture?.extension;
        break;
    }
    offset = frameEnd;
  }
  return LocalAudioMetadata(
    title: _clean(title),
    artist: _clean(artist),
    album: _clean(album),
    year: year,
    genre: genre,
    artwork: artwork,
    artworkExtension: artworkExtension,
  );
}

Future<Uint8List> _readPrefix(File file, int count) async {
  return _readRange(file, 0, count);
}

Future<Uint8List> _readSuffix(File file, int count) async {
  final length = await file.length();
  return _readRange(file, (length - count).clamp(0, length).toInt(), length);
}

Future<Uint8List> _readRange(File file, int start, int end) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead(start, end)) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

bool _hasPrefix(List<int> bytes, String value) =>
    bytes.length >= value.length &&
    List.generate(
            value.length, (index) => bytes[index] == value.codeUnitAt(index))
        .every((matches) => matches);

bool _hasPrefixAt(List<int> bytes, int offset, String value) =>
    offset + value.length <= bytes.length &&
    List.generate(value.length,
            (index) => bytes[offset + index] == value.codeUnitAt(index))
        .every((matches) => matches);

int? _oggCommentOffset(Uint8List packet) {
  if (_hasPrefix(packet, 'OpusTags')) return 8;
  if (_hasPrefix(packet, '\x03vorbis')) return 7;
  return null;
}

int _syncSafe(List<int> bytes, int offset) =>
    ((bytes[offset] & 0x7f) << 21) |
    ((bytes[offset + 1] & 0x7f) << 14) |
    ((bytes[offset + 2] & 0x7f) << 7) |
    (bytes[offset + 3] & 0x7f);

int _uint32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

int _uint32Le(List<int> bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

Uint8List _removeUnsynchronisation(Uint8List bytes) {
  final result = BytesBuilder(copy: false);
  for (var index = 0; index < bytes.length; index++) {
    if (index > 0 && bytes[index - 1] == 0xff && bytes[index] == 0) continue;
    result.addByte(bytes[index]);
  }
  return result.takeBytes();
}

String? _text(Uint8List bytes) {
  if (bytes.length < 2) return null;
  final encoding = bytes.first;
  return _decode(bytes.sublist(1), encoding);
}

String? _decode(Uint8List bytes, int encoding) {
  try {
    final value = switch (encoding) {
      0 => latin1.decode(bytes),
      1 => _utf16(bytes),
      2 => _utf16(bytes, bigEndian: true),
      3 => utf8.decode(bytes, allowMalformed: true),
      _ => '',
    };
    return _clean(value);
  } on Object {
    return null;
  }
}

String _utf16(Uint8List bytes, {bool bigEndian = false}) {
  var offset = 0;
  if (!bigEndian && bytes.length >= 2) {
    if (bytes[0] == 0xff && bytes[1] == 0xfe) {
      offset = 2;
    } else if (bytes[0] == 0xfe && bytes[1] == 0xff) {
      bigEndian = true;
      offset = 2;
    }
  }
  final units = <int>[];
  for (; offset + 1 < bytes.length; offset += 2) {
    final value = bigEndian
        ? (bytes[offset] << 8) | bytes[offset + 1]
        : bytes[offset] | (bytes[offset + 1] << 8);
    if (value == 0) break;
    units.add(value);
  }
  return String.fromCharCodes(units);
}

String? _clean(String? value) {
  final trimmed = value?.replaceAll('\u0000', '').trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _year(String? value) =>
    RegExp(r'\b(\d{4})\b').firstMatch(value ?? '')?.group(1);

Map<String, String> _flacComments(Uint8List bytes) {
  if (bytes.length < 8) return const {};
  var offset = 0;
  final vendorLength = _uint32Le(bytes, offset);
  offset += 4 + vendorLength;
  if (offset + 4 > bytes.length) return const {};
  final count = _uint32Le(bytes, offset);
  offset += 4;
  final values = <String, String>{};
  for (var index = 0; index < count && offset + 4 <= bytes.length; index++) {
    final length = _uint32Le(bytes, offset);
    offset += 4;
    if (length < 0 || offset + length > bytes.length) break;
    final entry = utf8.decode(bytes.sublist(offset, offset + length),
        allowMalformed: true);
    offset += length;
    final separator = entry.indexOf('=');
    if (separator > 0) {
      values.putIfAbsent(
        entry.substring(0, separator).toUpperCase(),
        () => entry.substring(separator + 1),
      );
    }
  }
  return values;
}

bool _hasM4aValue(LocalAudioMetadata metadata) =>
    metadata.title != null ||
    metadata.artist != null ||
    metadata.album != null ||
    metadata.artwork != null;

_M4aData? _m4aData(Uint8List bytes, int start, int end) {
  for (var offset = start; offset + 16 <= end;) {
    final length = _uint32(bytes, offset);
    if (length < 16 || offset + length > end) return null;
    if (latin1.decode(bytes.sublist(offset + 4, offset + 8)) == 'data') {
      return _M4aData(
          Uint8List.fromList(bytes.sublist(offset + 16, offset + length)));
    }
    offset += length;
  }
  return null;
}

String? _m4aText(_M4aData data) =>
    _clean(utf8.decode(data.bytes, allowMalformed: true));

String _imageExtension(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'png';
  }
  if (bytes.length >= 12 &&
      latin1.decode(bytes.sublist(0, 4)) == 'RIFF' &&
      latin1.decode(bytes.sublist(8, 12)) == 'WEBP') {
    return 'webp';
  }
  return 'jpg';
}

_Artwork? _flacPicture(Uint8List bytes) {
  if (bytes.length < 32) return null;
  var offset = 4;
  final mimeLength = _uint32(bytes, offset);
  offset += 4;
  if (offset + mimeLength + 4 > bytes.length) return null;
  final mime = utf8
      .decode(bytes.sublist(offset, offset + mimeLength), allowMalformed: true)
      .toLowerCase();
  offset += mimeLength;
  final descriptionLength = _uint32(bytes, offset);
  offset += 4 + descriptionLength;
  if (offset + 20 > bytes.length) return null;
  offset += 16; // Width, height, bit depth and indexed-color count.
  final dataLength = _uint32(bytes, offset);
  offset += 4;
  if (dataLength <= 0 || offset + dataLength > bytes.length) return null;
  final extension = switch (mime) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
  return _Artwork(
    Uint8List.fromList(bytes.sublist(offset, offset + dataLength)),
    extension,
  );
}

_Artwork? _picture(Uint8List frame) {
  if (frame.length < 5) return null;
  final encoding = frame.first;
  var offset = 1;
  final mimeEnd = _zero(frame, offset);
  if (mimeEnd < 0 || mimeEnd + 2 >= frame.length) return null;
  final mime = latin1.decode(frame.sublist(offset, mimeEnd)).toLowerCase();
  offset = mimeEnd + 1 + 1; // MIME terminator and picture type.
  final descriptionEnd = _textEnd(frame, offset, encoding);
  if (descriptionEnd < 0 || descriptionEnd >= frame.length) return null;
  offset = descriptionEnd + (encoding == 0 || encoding == 3 ? 1 : 2);
  if (offset >= frame.length) return null;
  final extension = switch (mime) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
  return _Artwork(Uint8List.fromList(frame.sublist(offset)), extension);
}

int _zero(Uint8List bytes, int start) {
  for (var index = start; index < bytes.length; index++) {
    if (bytes[index] == 0) return index;
  }
  return -1;
}

int _textEnd(Uint8List bytes, int start, int encoding) {
  if (encoding == 0 || encoding == 3) return _zero(bytes, start);
  for (var index = start; index + 1 < bytes.length; index += 2) {
    if (bytes[index] == 0 && bytes[index + 1] == 0) return index;
  }
  return -1;
}

final class _Artwork {
  const _Artwork(this.bytes, this.extension);

  final Uint8List bytes;
  final String extension;
}

final class _M4aData {
  const _M4aData(this.bytes);

  final Uint8List bytes;
}
