import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';

final class UserApiScriptFetcher {
  UserApiScriptFetcher(this._dio);

  final Dio _dio;
  static const maxBytes = 256 * 1024;

  Future<String> fetch(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '音源地址必须使用 HTTPS',
      );
    }
    try {
      final response = await _dio.getUri<ResponseBody>(
        uri,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
        ),
      );
      final contentLength =
          int.tryParse(response.headers.value('content-length') ?? '');
      if (contentLength != null && contentLength > maxBytes) {
        throw const AppFailure(
          code: AppFailureCode.invalidData,
          message: '音源脚本超过大小限制',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.data!.stream) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const AppFailure(
            code: AppFailureCode.invalidData,
            message: '音源脚本超过大小限制',
          );
        }
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on DioException catch (error) {
      throw mapDioException(error);
    } on FormatException {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '音源脚本不是 UTF-8 文本',
      );
    }
  }
}
