import 'package:coral_music_mobile/core/app_failure.dart';
import 'package:coral_music_mobile/core/http_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps timeout without leaking query values', () {
    final failure = mapDioException(
      DioException(
        requestOptions: RequestOptions(
          path: 'https://example.com/music?token=secret',
        ),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    expect(failure.code, AppFailureCode.timeout);
    expect(failure.diagnostic, 'https://example.com/music');
    expect(failure.diagnostic, isNot(contains('secret')));
  });
}
