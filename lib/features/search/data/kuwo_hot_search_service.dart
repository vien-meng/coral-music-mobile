import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';

final class KuwoHotSearchService {
  KuwoHotSearchService(this._dio);

  final Dio _dio;

  Future<List<String>> load() async {
    final uri = Uri.https('hotword.kuwo.cn', '/hotword.s', {
      'prod': 'kwplayer_ar_9.3.0.1',
      'corp': 'kuwo',
      'newver': '2',
      'vipver': '9.3.0.1',
      'source': 'kwplayer_ar_9.3.0.1_40.apk',
      'p2p': '1',
      'notrace': '0',
      'uid': '0',
      'plat': 'kwplayer_ar',
      'rformat': 'json',
      'encoding': 'utf8',
      'tabid': '1',
    });
    try {
      final response = await _dio.getUri<Object?>(uri);
      return parse(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '热搜词数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  static List<String> parse(Object? raw) {
    if (raw is! Map || raw['status'] != 'ok' || raw['tagvalue'] is! List) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '热搜词响应异常',
      );
    }
    return raw['tagvalue']
        .whereType<Map>()
        .map((item) => '${item['key'] ?? ''}'.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
