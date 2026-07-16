import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import '../../search/data/kuwo_search_parser.dart';
import 'kuwo_crypto.dart';
import 'kuwo_leaderboard_parser.dart';
import 'online_catalog_service.dart';

final class KuwoCatalogService implements OnlineCatalogService {
  KuwoCatalogService(this._dio);

  final Dio _dio;

  static const _pageSize = 100;
  static const _searchPageSize = 30;
  static const _boards = <LeaderboardBoard>[
    LeaderboardBoard(
        id: 'kw__93', source: OnlineSource.kuwo, name: '飙升榜', remoteId: '93'),
    LeaderboardBoard(
        id: 'kw__17', source: OnlineSource.kuwo, name: '新歌榜', remoteId: '17'),
    LeaderboardBoard(
        id: 'kw__16', source: OnlineSource.kuwo, name: '热歌榜', remoteId: '16'),
    LeaderboardBoard(
        id: 'kw__158',
        source: OnlineSource.kuwo,
        name: '抖音热歌榜',
        remoteId: '158'),
    LeaderboardBoard(
        id: 'kw__284', source: OnlineSource.kuwo, name: '热评榜', remoteId: '284'),
    LeaderboardBoard(
        id: 'kw__290',
        source: OnlineSource.kuwo,
        name: 'ACG新歌榜',
        remoteId: '290'),
    LeaderboardBoard(
        id: 'kw__26', source: OnlineSource.kuwo, name: '经典怀旧榜', remoteId: '26'),
    LeaderboardBoard(
        id: 'kw__104', source: OnlineSource.kuwo, name: '华语榜', remoteId: '104'),
    LeaderboardBoard(
        id: 'kw__182', source: OnlineSource.kuwo, name: '粤语榜', remoteId: '182'),
    LeaderboardBoard(
        id: 'kw__22', source: OnlineSource.kuwo, name: '欧美榜', remoteId: '22'),
    LeaderboardBoard(
        id: 'kw__184', source: OnlineSource.kuwo, name: '韩语榜', remoteId: '184'),
    LeaderboardBoard(
        id: 'kw__183', source: OnlineSource.kuwo, name: '日语榜', remoteId: '183'),
  ];

  @override
  Future<List<LeaderboardBoard>> getLeaderboardBoards(
      OnlineSource source) async {
    if (source != OnlineSource.kuwo) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '该音乐来源尚未接入排行榜',
      );
    }
    return _boards;
  }

  @override
  Future<PageResult<Track>> getLeaderboardDetail(
    OnlineSource source,
    String boardId,
    int page,
  ) async {
    if (source != OnlineSource.kuwo || page < 1) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '榜单请求参数无效',
      );
    }
    final board = _boards.where((item) => item.id == boardId).firstOrNull;
    if (board == null) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '榜单不存在',
      );
    }
    final payload = <String, Object?>{
      'uid': '',
      'devId': '',
      'sFrom': 'kuwo_sdk',
      'user_type': 'AP',
      'carSource': 'kwplayercar_ar_6.0.1.0_apk_keluze.apk',
      'id': board.remoteId,
      'pn': page - 1,
      'rn': _pageSize,
    };
    final uri = Uri.parse('https://wbd.kuwo.cn/api/bd/bang/bang_info')
        .replace(query: KuwoCrypto.buildQuery(payload));
    try {
      final response = await _dio.getUri<String>(
        uri,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null || body.isEmpty) {
        throw const AppFailure(
          code: AppFailureCode.invalidData,
          message: '榜单响应为空',
        );
      }
      return KuwoLeaderboardParser.parse(
        KuwoCrypto.decodeResponse(body),
        page: page,
        pageSize: _pageSize,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '榜单数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<PageResult<Track>> searchTracks(
    OnlineSource source,
    String query,
    int page,
  ) async {
    final keyword = query.trim();
    if (source != OnlineSource.kuwo || keyword.isEmpty || page < 1) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '搜索请求参数无效',
      );
    }
    final uri = Uri.https('search.kuwo.cn', '/r.s', {
      'client': 'kt',
      'all': keyword,
      'pn': '${page - 1}',
      'rn': '$_searchPageSize',
      'uid': '794762570',
      'ver': 'kwplayer_ar_9.2.2.1',
      'vipver': '1',
      'show_copyright_off': '1',
      'newver': '1',
      'ft': 'music',
      'cluster': '0',
      'strategy': '2012',
      'encoding': 'utf8',
      'rformat': 'json',
      'vermerge': '1',
      'mobi': '1',
      'issubtitle': '1',
    });
    try {
      final response = await _dio.getUri<String>(
        uri,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null || body.isEmpty) {
        throw const AppFailure(
          code: AppFailureCode.invalidData,
          message: '搜索响应为空',
        );
      }
      return KuwoSearchParser.parse(
        Map<String, Object?>.from(jsonDecode(body) as Map),
        page: page,
        pageSize: _searchPageSize,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '搜索数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }
}
