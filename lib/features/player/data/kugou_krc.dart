import 'dart:convert';
import 'dart:io';

/// Converts KuGou's encrypted KRC payload into the existing LX word timing.
String decodeKugouKrc(String encoded) {
  final encrypted = base64.decode(encoded);
  if (encrypted.length <= 4) throw const FormatException('KRC 内容为空');
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
  final compressed = encrypted.sublist(4);
  for (var index = 0; index < compressed.length; index++) {
    compressed[index] ^= key[index % key.length];
  }
  final raw = utf8.decode(ZLibDecoder().convert(compressed));
  return raw
      .split(RegExp(r'\r?\n'))
      .map(_convertLine)
      .where((line) => line.isNotEmpty)
      .join('\n');
}

String _convertLine(String line) {
  final timing = RegExp(r'^\[(\d+),\d+\]').firstMatch(line);
  if (timing == null) return line;
  final start = int.parse(timing.group(1)!);
  return line
      .replaceFirst(timing.group(0)!, '[${_timeLabel(start)}]')
      .replaceAllMapped(
          RegExp(r'<(\d+),(\d+),\d+>'),
          (match) =>
              '<${start + int.parse(match.group(1)!)},${match.group(2)}>');
}

String _timeLabel(int milliseconds) {
  final minutes = milliseconds ~/ 60000;
  final seconds = (milliseconds ~/ 1000) % 60;
  final fraction = milliseconds % 1000;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${fraction.toString().padLeft(3, '0')}';
}
