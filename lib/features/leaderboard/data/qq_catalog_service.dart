import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import 'online_catalog_service.dart';
import 'qq_leaderboard_parser.dart';

final class QqCatalogService implements OnlineCatalogService {
  QqCatalogService(this._dio);

  final Dio _dio;

  static const _boards = <LeaderboardBoard>[
    LeaderboardBoard(
        id: 'tx__4', source: OnlineSource.qq, name: '流行指数榜', remoteId: '4'),
    LeaderboardBoard(
        id: 'tx__26', source: OnlineSource.qq, name: '热歌榜', remoteId: '26'),
    LeaderboardBoard(
        id: 'tx__27', source: OnlineSource.qq, name: '新歌榜', remoteId: '27'),
    LeaderboardBoard(
        id: 'tx__62', source: OnlineSource.qq, name: '飙升榜', remoteId: '62'),
    LeaderboardBoard(
        id: 'tx__58', source: OnlineSource.qq, name: '说唱榜', remoteId: '58'),
    LeaderboardBoard(
        id: 'tx__57', source: OnlineSource.qq, name: '喜力电音榜', remoteId: '57'),
    LeaderboardBoard(
        id: 'tx__28', source: OnlineSource.qq, name: '网络歌曲榜', remoteId: '28'),
    LeaderboardBoard(
        id: 'tx__5', source: OnlineSource.qq, name: '内地榜', remoteId: '5'),
    LeaderboardBoard(
        id: 'tx__3', source: OnlineSource.qq, name: '欧美榜', remoteId: '3'),
    LeaderboardBoard(
        id: 'tx__59', source: OnlineSource.qq, name: '香港地区榜', remoteId: '59'),
    LeaderboardBoard(
        id: 'tx__16', source: OnlineSource.qq, name: '韩国榜', remoteId: '16'),
    LeaderboardBoard(
        id: 'tx__60', source: OnlineSource.qq, name: '抖快榜', remoteId: '60'),
    LeaderboardBoard(
        id: 'tx__29', source: OnlineSource.qq, name: '影视金曲榜', remoteId: '29'),
    LeaderboardBoard(
        id: 'tx__17', source: OnlineSource.qq, name: '日本榜', remoteId: '17'),
    LeaderboardBoard(
        id: 'tx__52',
        source: OnlineSource.qq,
        name: '腾讯音乐人原创榜',
        remoteId: '52'),
    LeaderboardBoard(
        id: 'tx__36', source: OnlineSource.qq, name: 'K歌金曲榜', remoteId: '36'),
    LeaderboardBoard(
        id: 'tx__61', source: OnlineSource.qq, name: '台湾地区榜', remoteId: '61'),
    LeaderboardBoard(
        id: 'tx__63', source: OnlineSource.qq, name: 'DJ舞曲榜', remoteId: '63'),
    LeaderboardBoard(
        id: 'tx__64', source: OnlineSource.qq, name: '综艺新歌榜', remoteId: '64'),
    LeaderboardBoard(
        id: 'tx__65', source: OnlineSource.qq, name: '国风热歌榜', remoteId: '65'),
    LeaderboardBoard(
        id: 'tx__67', source: OnlineSource.qq, name: '听歌识曲榜', remoteId: '67'),
    LeaderboardBoard(
        id: 'tx__72', source: OnlineSource.qq, name: '动漫音乐榜', remoteId: '72'),
    LeaderboardBoard(
        id: 'tx__73', source: OnlineSource.qq, name: '游戏音乐榜', remoteId: '73'),
    LeaderboardBoard(
        id: 'tx__75', source: OnlineSource.qq, name: '有声榜', remoteId: '75'),
    LeaderboardBoard(
        id: 'tx__131',
        source: OnlineSource.qq,
        name: '校园音乐人排行榜',
        remoteId: '131'),
  ];

  @override
  Future<List<LeaderboardBoard>> getLeaderboardBoards(
      OnlineSource source) async {
    if (source != OnlineSource.qq) throw _unsupported('排行榜');
    return _boards;
  }

  @override
  Future<PageResult<Track>> getLeaderboardDetail(
      OnlineSource source, String boardId, int page) async {
    if (source != OnlineSource.qq ||
        page != 1 ||
        !_boards.any((board) => board.id == boardId)) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: 'QQ 音乐榜单请求参数无效');
    }
    final board = _boards.firstWhere((item) => item.id == boardId);
    const uri = 'https://u.y.qq.com/cgi-bin/musicu.fcg';
    final payload = {
      'toplist': {
        'module': 'musicToplist.ToplistInfoServer',
        'method': 'GetDetail',
        'param': {'topid': int.parse(board.remoteId), 'num': 300, 'period': ''},
      },
      'comm': {'uin': 0, 'format': 'json', 'ct': 20, 'cv': 1859},
    };
    try {
      final response = await _dio.post<String>(
        uri,
        data: jsonEncode(payload),
        options: Options(
            contentType: Headers.jsonContentType,
            responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null || body.isEmpty) {
        throw const AppFailure(
            code: AppFailureCode.invalidData, message: 'QQ 音乐榜单响应为空');
      }
      return QqLeaderboardParser.parse(
          Map<String, Object?>.from(jsonDecode(body) as Map));
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
          code: AppFailureCode.invalidData,
          message: 'QQ 音乐榜单数据解析失败',
          diagnostic: error.runtimeType.toString());
    }
  }

  @override
  Future<PageResult<Track>> searchTracks(
      OnlineSource source, String query, int page) async {
    if (source != OnlineSource.qq || query.trim().isEmpty || page < 1) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐搜索请求参数无效',
      );
    }
    const uri = 'https://u.y.qq.com/cgi-bin/musicu.fcg';
    final payload = {
      'comm': {'uin': 0, 'format': 'json', 'ct': 20, 'cv': 1859},
      'req': {
        'module': 'music.search.SearchCgiService',
        'method': 'DoSearchForQQMusicMobile',
        'param': {
          'search_type': 0,
          'query': query.trim(),
          'page_num': page,
          'num_per_page': 30,
          'highlight': 0,
          'nqc_flag': 0,
          'multi_zhida': 0,
          'cat': 2,
          'grp': 1,
          'sin': 0,
          'sem': 0,
        },
      },
    };
    try {
      final response = await _dio.post<String>(
        uri,
        data: jsonEncode(payload),
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.plain,
        ),
      );
      final body = response.data;
      if (body == null || body.isEmpty) {
        throw const AppFailure(
          code: AppFailureCode.invalidData,
          message: 'QQ 音乐搜索响应为空',
        );
      }
      return QqLeaderboardParser.parseSearch(
        Map<String, Object?>.from(jsonDecode(body) as Map),
        page: page,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐搜索数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  AppFailure _unsupported(String capability) => AppFailure(
      code: AppFailureCode.invalidData, message: 'QQ 音乐暂未接入$capability');
}
