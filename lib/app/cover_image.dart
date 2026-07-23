import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

const _coverUserAgent = 'Mozilla/5.0 (Linux; Android 13) '
    'AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36';

class CoverImage extends StatefulWidget {
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
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  Uint8List? _bytes;
  bool _failed = false;
  Uri? _loadingUri;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final uri = widget.uri;
    if (uri == null) return;
    if (uri.scheme == 'file') return; // handled by build()
    final remote = _httpsUri(uri);
    if (remote == null) {
      debugPrint('[CoverImage] invalid uri scheme: $uri');
      return;
    }
    _loadingUri = remote;
    try {
      final client = HttpClient();
      final request = await client.getUrl(remote);
      final headers = coverImageHeadersFor(remote);
      headers.forEach((name, value) {
        request.headers.set(name, value);
      });
      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('[CoverImage] HTTP ${response.statusCode}: $remote');
        if (mounted) setState(() => _failed = true);
        return;
      }
      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      if (_loadingUri != remote) return;
      if (mounted) {
        setState(() => _bytes = Uint8List.fromList(bytes));
      }
    } on Object catch (error) {
      debugPrint('[CoverImage] load failed: $uri → $error');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.uri;
    if (value == null || _failed) return widget.fallback;
    if (value.scheme == 'file') {
      return Image.file(
        File.fromUri(value),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.fallback,
      );
    }
    final data = _bytes;
    if (data != null) {
      return Image.memory(
        data,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.fallback,
      );
    }
    return widget.fallback;
  }
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
