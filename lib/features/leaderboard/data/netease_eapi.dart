import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

String neteaseEapiParams(String path, Map<String, Object?> payload) {
  final text = jsonEncode(payload);
  final digest = md5
      .convert(utf8.encode('nobody${path}use${text}md5forencrypt'))
      .toString();
  final raw = '$path-36cd479b6b5-$text-36cd479b6b5-$digest';
  final cipher = PaddedBlockCipher('AES/ECB/PKCS7')
    ..init(
      true,
      PaddedBlockCipherParameters<KeyParameter, Null>(
        KeyParameter(Uint8List.fromList(utf8.encode('e82ckenh8dichen8'))),
        null,
      ),
    );
  return cipher
      .process(Uint8List.fromList(utf8.encode(raw)))
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
}
