import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../domain/music.dart';

final class WebDavEntry {
  const WebDavEntry({required this.path, required this.isDirectory});

  final String path;
  final bool isDirectory;
}

Uri? parentWebDavDirectory(Uri directory, Uri root) {
  if (directory.scheme != root.scheme ||
      directory.host != root.host ||
      directory.port != root.port) {
    return null;
  }
  final rootPath = root.path.endsWith('/') ? root.path : '${root.path}/';
  final directoryPath =
      directory.path.endsWith('/') ? directory.path : '${directory.path}/';
  if (!directoryPath.startsWith(rootPath) || directoryPath == rootPath) {
    return null;
  }
  final withoutTrailingSlash =
      directoryPath.substring(0, directoryPath.length - 1);
  final parent = withoutTrailingSlash.substring(
    0,
    withoutTrailingSlash.lastIndexOf('/') + 1,
  );
  return parent.startsWith(rootPath) ? directory.replace(path: parent) : null;
}

List<Uri> webDavBreadcrumbs(Uri directory, Uri root) {
  if (directory.scheme != root.scheme ||
      directory.host != root.host ||
      directory.port != root.port) {
    return [_webDavDirectoryUri(root)];
  }
  final normalizedRoot = _webDavDirectoryUri(root);
  final normalizedDirectory = _webDavDirectoryUri(directory);
  if (!normalizedDirectory.path.startsWith(normalizedRoot.path)) {
    return [normalizedRoot];
  }
  final paths = <Uri>[normalizedRoot];
  var path = normalizedRoot.path;
  final suffix = normalizedDirectory.path.substring(path.length);
  for (final part in suffix.split('/').where((item) => item.isNotEmpty)) {
    path = '$path$part/';
    paths.add(normalizedDirectory.replace(path: path));
  }
  return paths;
}

Uri _webDavDirectoryUri(Uri uri) =>
    uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');

final class WebDavClient {
  WebDavClient(this._dio);

  final Dio _dio;
  static const audioExtensions = {
    'mp3',
    'm4a',
    'aac',
    'flac',
    'wav',
    'ogg',
    'opus',
    'ape',
    'aiff',
    'alac'
  };

  bool isAudio(WebDavEntry entry) {
    if (entry.isDirectory) return false;
    final path = Uri.decodeComponent(entry.path).toLowerCase();
    return audioExtensions.contains(path.split('.').last);
  }

  Options rangeOptions(String authorization, {int? start}) => Options(
        headers: {
          'Authorization': authorization,
          if (start != null) 'Range': 'bytes=$start-',
        },
        responseType: ResponseType.stream,
      );

  Track toTrack(WebDavEntry entry,
      {required String accountId, required Uri endpoint}) {
    final uri = endpoint.resolve(entry.path);
    final name = uri.pathSegments.isEmpty ? entry.path : uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    return Track(
      sourceKind: TrackSourceKind.webdav,
      sourceId: accountId,
      sourceTrackId: entry.path,
      title: dot > 0 ? name.substring(0, dot) : name,
      artist: '',
      localUri: uri,
    );
  }

  Future<List<WebDavEntry>> list(Uri endpoint,
      {required String authorization}) async {
    if (!{'http', 'https'}.contains(endpoint.scheme) ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        authorization.isEmpty) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: 'WebDAV 地址或授权信息无效',
      );
    }
    try {
      final response = await _dio.request<String>(
        endpoint.toString(),
        options: Options(
          method: 'PROPFIND',
          headers: {'Authorization': authorization, 'Depth': '1'},
          responseType: ResponseType.plain,
        ),
        data:
            '''<?xml version="1.0"?><propfind xmlns="DAV:"><prop><resourcetype/></prop></propfind>''',
      );
      if (response.statusCode != 207 || response.data == null) {
        throw const AppFailure(
            code: AppFailureCode.badResponse, message: 'WebDAV 目录读取失败');
      }
      return RegExp(r'<D:response[\s\S]*?</D:response>', caseSensitive: false)
          .allMatches(response.data!)
          .map((match) => match.group(0)!)
          .map((raw) => WebDavEntry(
                path: Uri.decodeComponent(
                    RegExp(r'<D:href>(.*?)</D:href>', caseSensitive: false)
                            .firstMatch(raw)
                            ?.group(1) ??
                        ''),
                isDirectory:
                    RegExp(r'<D:collection\s*/?>', caseSensitive: false)
                        .hasMatch(raw),
              ))
          .where((entry) => entry.path.isNotEmpty)
          .where((entry) => endpoint.resolve(entry.path) != endpoint)
          .toList(growable: false);
    } on DioException {
      throw const AppFailure(
          code: AppFailureCode.noNetwork, message: '无法连接 WebDAV 服务器');
    }
  }
}
