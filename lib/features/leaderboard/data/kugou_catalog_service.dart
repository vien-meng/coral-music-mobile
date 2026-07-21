import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import 'kugou_search_parser.dart';
import 'online_catalog_service.dart';

final class KugouCatalogService implements OnlineCatalogService {
  KugouCatalogService(this._dio);

  final Dio _dio;

  @override
  Future<List<LeaderboardBoard>> getLeaderboardBoards(
      OnlineSource source) async {
    throw _unsupported('排行榜');
  }

  @override
  Future<PageResult<Track>> getLeaderboardDetail(
    OnlineSource source,
    String boardId,
    int page,
  ) async =>
      throw _unsupported('排行榜');

  @override
  Future<PageResult<Track>> searchTracks(
    OnlineSource source,
    String query,
    int page,
  ) async {
    final keyword = query.trim();
    if (source != OnlineSource.kugou || keyword.isEmpty || page < 1) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '酷狗音乐搜索请求参数无效',
      );
    }
    final uri = Uri.https('songsearch.kugou.com', '/song_search_v2', {
      'keyword': keyword,
      'page': '$page',
      'pagesize': '30',
      'userid': '0',
      'clientver': '',
      'platform': 'WebFilter',
      'filter': '2',
      'iscorrection': '1',
      'privilege_filter': '0',
      'area_code': '1',
    });
    try {
      final response = await _dio.getUri<Object?>(
        uri,
        options: Options(headers: const {
          'Referer': 'https://kugou.com',
          'Origin': 'https://kugou.com',
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) '
              'AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 '
              'Mobile/13B143 Safari/601.1',
        }),
      );
      return KugouSearchParser.parse(response.data, page: page);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '酷狗音乐搜索数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  AppFailure _unsupported(String capability) => AppFailure(
        code: AppFailureCode.invalidData,
        message: '酷狗音乐暂未接入$capability',
      );
}
