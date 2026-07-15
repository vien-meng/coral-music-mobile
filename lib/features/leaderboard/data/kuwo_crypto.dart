import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

final class KuwoCrypto {
  static const appId = 'y67sprxhhpws';
  static final _key = Uint8List.fromList(
    const [
      112,
      87,
      39,
      61,
      199,
      250,
      41,
      191,
      57,
      68,
      45,
      114,
      221,
      94,
      140,
      228
    ],
  );

  static String buildQuery(
    Map<String, Object?> payload, {
    DateTime? now,
  }) {
    final data = base64Encode(_process(utf8.encode(jsonEncode(payload)), true));
    final time = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final sign =
        md5.convert(utf8.encode('$appId$data$time')).toString().toUpperCase();
    return 'data=${Uri.encodeQueryComponent(data)}&time=$time&appId=$appId&sign=$sign';
  }

  static Map<String, Object?> decodeResponse(String response) {
    final decoded = utf8.decode(
      _process(base64Decode(Uri.decodeComponent(response)), false),
    );
    final value = jsonDecode(decoded);
    if (value is! Map<String, Object?>) {
      throw const FormatException('Kuwo response is not an object');
    }
    return value;
  }

  static Uint8List _process(List<int> input, bool encrypt) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      ECBBlockCipher(AESEngine()),
    )..init(
        encrypt,
        PaddedBlockCipherParameters<KeyParameter, Null>(
          KeyParameter(_key),
          null,
        ),
      );
    return cipher.process(Uint8List.fromList(input));
  }
}
