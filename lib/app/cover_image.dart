import 'dart:io';

import 'package:flutter/material.dart';

const _coverUserAgent = 'Mozilla/5.0 (Linux; Android 13) '
    'AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36';

class CoverImage extends StatelessWidget {
  const CoverImage({
    required this.uri,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  final Uri? uri;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final value = uri;
    if (value == null) return fallback;
    if (value.scheme == 'file') {
      return Image.file(
        File.fromUri(value),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: _error,
      );
    }
    final remote = _httpsUri(value);
    if (remote == null) return fallback;
    return Image.network(
      remote.toString(),
      width: width,
      height: height,
      fit: fit,
      headers: coverImageHeadersFor(remote),
      errorBuilder: _error,
    );
  }

  Widget _error(BuildContext _, Object __, StackTrace? ___) => fallback;
}

Uri? _httpsUri(Uri value) {
  if (value.host.isEmpty) return null;
  return switch (value.scheme) {
    'https' => value,
    'http' || '' => value.replace(scheme: 'https'),
    _ => null,
  };
}

Map<String, String> coverImageHeadersFor(Uri uri) => {
      'User-Agent': _coverUserAgent,
      'Accept':
          'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      if (_coverReferer(uri) case final referer?) 'Referer': referer,
    };

String? _coverReferer(Uri uri) => switch (uri.host) {
      'y.gtimg.cn' => 'https://y.qq.com/',
      final host when host.endsWith('.y.qq.com') || host == 'y.qq.com' =>
        'https://y.qq.com/',
      final host when host.endsWith('.music.126.net') =>
        'https://music.163.com/',
      final host when host.endsWith('.kuwo.cn') || host == 'kuwo.cn' =>
        'https://www.kuwo.cn/',
      final host when host.endsWith('.migu.cn') || host == 'migu.cn' =>
        'https://m.music.migu.cn/',
      final host when host.endsWith('.kugou.com') || host == 'kugou.com' =>
        'https://www.kugou.com/',
      _ => null,
    };
