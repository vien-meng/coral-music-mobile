import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';

final class HotSearchService {
  HotSearchService(this._dio);

  final Dio _dio;

  Future<List<String>> load() async {
    final uri = Uri.https('u.y.qq.com', '/cgi-bin/musicu.fcg');
    try {
      final response = await _dio.postUri<Object?>(
        uri,
        data: const {
          'comm': {
            'ct': '19',
            'cv': '1803',
            'guid': '0',
            'patch': '118',
            'psrf_access_token_expiresAt': 0,
            'psrf_qqaccess_token': '',
            'psrf_qqopenid': '',
            'psrf_qqunionid': '',
            'tmeAppID': 'qqmusic',
            'tmeLoginType': 0,
            'uin': '0',
            'wid': '0',
          },
          'hotkey': {
            'method': 'GetHotkeyForQQMusicPC',
            'module': 'tencent_musicsoso_hotkey.HotkeyService',
            'param': {'search_id': '', 'uin': 0},
          },
        },
        options: Options(headers: const {
          'Referer': 'https://y.qq.com/portal/player.html',
        }),
      );
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
    final value = raw is String ? jsonDecode(raw) : raw;
    final hotkey = value is Map ? value['hotkey'] : null;
    final data = hotkey is Map ? hotkey['data'] : null;
    final items = data is Map ? data['vec_hotkey'] : null;
    if (value is! Map || value['code'] != 0 || items is! List) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '热搜词响应异常',
      );
    }
    return items
        .whereType<Map>()
        .map((item) => '${item['query'] ?? ''}'.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(20)
        .toList(growable: false);
  }
}
