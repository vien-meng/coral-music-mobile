import 'dart:io';

import 'package:flutter/material.dart';

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
    return value.scheme == 'file'
        ? Image.file(
            File.fromUri(value),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: _error,
          )
        : Image.network(
            value.toString(),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: _error,
          );
  }

  Widget _error(BuildContext _, Object __, StackTrace? ___) => fallback;
}
