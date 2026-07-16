import 'package:dio/dio.dart';

import 'app_failure.dart';

Dio createHttpClient() => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              'Chrome/120 Mobile Safari/537.36',
        },
      ),
    );

AppFailure mapDioException(DioException error) {
  final target = _safeTarget(error.requestOptions.uri);
  return switch (error.type) {
    DioExceptionType.cancel => AppFailure(
        code: AppFailureCode.cancelled,
        message: '请求已取消',
        diagnostic: target,
      ),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      AppFailure(
        code: AppFailureCode.timeout,
        message: '请求超时，请稍后重试',
        diagnostic: target,
      ),
    DioExceptionType.connectionError => AppFailure(
        code: AppFailureCode.noNetwork,
        message: '网络不可用，请检查网络连接',
        diagnostic: target,
      ),
    DioExceptionType.badResponse => AppFailure(
        code: AppFailureCode.badResponse,
        message: '服务暂时不可用',
        diagnostic: '$target status=${error.response?.statusCode ?? 'unknown'}',
      ),
    _ => AppFailure(
        code: AppFailureCode.unknown,
        message: '请求失败，请稍后重试',
        diagnostic: target,
      ),
  };
}

String _safeTarget(Uri uri) => Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
