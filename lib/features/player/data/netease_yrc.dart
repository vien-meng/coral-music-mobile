String neteaseYrcToLx(String raw) => raw
    .split(RegExp(r'\r?\n'))
    .map(_convertLine)
    .where((line) => line.isNotEmpty)
    .join('\n');

String _convertLine(String line) {
  final timing = RegExp(r'^\[(\d+),\d+\]').firstMatch(line);
  if (timing == null) return '';
  final start = int.parse(timing.group(1)!);
  return line
      .replaceFirst(timing.group(0)!, '[${_timeLabel(start)}]')
      .replaceAllMapped(RegExp(r'\((\d+),(\d+),\d+\)'),
          (match) => '<${match.group(1)},${match.group(2)}>');
}

String _timeLabel(int milliseconds) {
  final minutes = milliseconds ~/ 60000;
  final seconds = (milliseconds ~/ 1000) % 60;
  final fraction = milliseconds % 1000;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${fraction.toString().padLeft(3, '0')}';
}
