import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../domain/music.dart';
import '../../download/state/download_controller.dart';
import '../../library/view/playlist_picker.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';
import '../data/webdav_client.dart';
import '../data/webdav_credentials.dart';

class WebDavPage extends ConsumerStatefulWidget {
  const WebDavPage({super.key});

  @override
  ConsumerState<WebDavPage> createState() => _WebDavPageState();
}

class _WebDavPageState extends ConsumerState<WebDavPage> {
  final _endpoint = TextEditingController();
  final _accountName = TextEditingController();
  final _authorization = TextEditingController();
  final _client = WebDavClient(Dio());
  List<WebDavEntry>? _entries;
  Uri? _directory;
  String? _accountId;
  String? _error;
  String _query = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _restoreConnection();
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _accountName.dispose();
    _authorization.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('网盘资源'),
          actions: [
            IconButton(
              tooltip: '已保存的连接',
              onPressed: _loading ? null : _showAccountPicker,
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
            if (_directory != null)
              IconButton(
                tooltip: '刷新目录',
                onPressed: _loading ? null : () => _browse(_directory!),
                icon: const Icon(Icons.refresh),
              ),
            if (_directory != null)
              IconButton(
                tooltip: '更换连接',
                onPressed: _loading ? null : _showConnection,
                icon: const Icon(Icons.tune),
              ),
          ],
        ),
        body: _directory == null ? _connectionForm() : _directoryList(),
      );

  Widget _connectionForm() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(_accountId == null ? '连接你的 WebDAV' : '编辑 WebDAV 连接',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CoralPalette.sky,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_outlined, color: CoralPalette.brand),
                SizedBox(width: 10),
                Expanded(
                  child: Text('连接自己的 WebDAV 音乐目录。地址与授权信息只保存在本机系统安全存储中。'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _accountName,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '连接名称（可选）',
              hintText: '例如：家里的音乐库',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _endpoint,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'WebDAV 地址',
              hintText: 'https://dav.example.com/music/',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _authorization,
            autocorrect: false,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Authorization',
              hintText: 'Basic ... 或 Bearer ...',
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _loading ? null : _saveAndBrowse,
            style: FilledButton.styleFrom(
              backgroundColor: CoralPalette.brand,
              foregroundColor: Colors.white,
              side: BorderSide.none,
            ),
            child: Text(_loading ? '正在验证连接…' : '验证并保存'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      );

  Widget _directoryList() {
    final entries = _entries;
    if (_loading && entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && entries == null) {
      return Center(
          child: TextButton(
              onPressed: () => _browse(_directory!), child: Text(_error!)));
    }
    final visible = (entries ?? const <WebDavEntry>[])
        .where((entry) => _matchesQuery(entry))
        .toList(growable: false);
    final parent = _parentDirectory;
    final root = Uri.tryParse(_accountId ?? '');
    final breadcrumbs = root == null || _directory == null
        ? const <Uri>[]
        : webDavBreadcrumbs(_directory!, root);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: CoralPalette.sky,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (parent != null)
                  IconButton(
                    tooltip: '返回上级目录',
                    onPressed: _loading ? null : () => _browse(parent),
                    icon: const Icon(Icons.arrow_back_outlined),
                  ),
                const Icon(Icons.cloud_outlined, color: CoralPalette.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName(_directory!),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${visible.where(_client.isAudio).length} 首音频',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ]),
              if (breadcrumbs.length > 1) ...[
                const SizedBox(height: 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var index = 0;
                        index < breadcrumbs.length;
                        index++) ...[
                      TextButton(
                        onPressed: index == breadcrumbs.length - 1 || _loading
                            ? null
                            : () => _browse(breadcrumbs[index]),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(index == 0
                            ? _accountName.text
                            : _displayName(breadcrumbs[index])),
                      ),
                      if (index < breadcrumbs.length - 1)
                        const Icon(Icons.chevron_right_outlined, size: 15),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: '搜索当前目录',
            prefixIcon: Icon(Icons.search_outlined),
            isDense: true,
          ),
        ),
      ),
      Expanded(
        child: visible.isEmpty
            ? Center(child: Text(_query.isEmpty ? '此目录没有可显示的资源' : '没有匹配的资源'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _entryTile(visible[index]),
              ),
      ),
    ]);
  }

  Widget _entryTile(WebDavEntry entry) {
    final uri = _directory!.resolve(entry.path);
    final audio = _client.isAudio(entry);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: entry.isDirectory
          ? () => _browse(uri)
          : audio
              ? () => _play(entry)
              : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: entry.isDirectory ? CoralPalette.sky : CoralPalette.lilac,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              entry.isDirectory
                  ? Icons.folder_outlined
                  : audio
                      ? Icons.music_note_outlined
                      : Icons.insert_drive_file_outlined,
              size: 20,
              color: CoralPalette.brand,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_displayName(uri),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(
                  entry.isDirectory
                      ? '目录'
                      : audio
                          ? '音频文件'
                          : '其他文件',
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          if (entry.isDirectory)
            const Icon(Icons.chevron_right_outlined)
          else if (audio)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '下载到本机',
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => _download(entry),
                ),
                IconButton(
                  tooltip: '添加到我的列表',
                  icon: const Icon(Icons.playlist_add_outlined),
                  onPressed: () => _addToPlaylist(entry),
                ),
              ],
            ),
        ]),
      ),
    );
  }

  Future<void> _restoreConnection() async {
    final credentials = ref.read(webDavCredentialsProvider);
    final accountId = await credentials.readLastAccount();
    final authorization =
        accountId == null ? null : await credentials.read(accountId);
    final account = (await credentials.readAccounts())
        .where((item) => item.id == accountId)
        .firstOrNull;
    final uri = account?.endpoint ?? Uri.tryParse(accountId ?? '');
    if (!mounted || uri == null || authorization == null) return;
    _endpoint.text = uri.toString();
    _accountName.text = account?.name ?? _defaultAccountName(uri);
    _authorization.text = authorization;
    _accountId = accountId;
    if (account == null) {
      await credentials.saveAccount(
        WebDavAccount(
          id: accountId!,
          name: _accountName.text,
          endpoint: _directoryUri(uri),
        ),
        authorization,
      );
    }
    await _browse(_directoryUri(uri));
  }

  Future<void> _saveAndBrowse() async {
    final uri = Uri.tryParse(_endpoint.text.trim());
    final authorization = _authorization.text.trim();
    if (uri == null || uri.host.isEmpty || authorization.isEmpty) {
      setState(() => _error = '请填写有效的 WebDAV 地址和 Authorization。');
      return;
    }
    final directory = _directoryUri(uri);
    final account = WebDavAccount(
      id: directory.toString(),
      name: _accountName.text.trim().isEmpty
          ? _defaultAccountName(directory)
          : _accountName.text.trim(),
      endpoint: directory,
    );
    _accountId = account.id;
    await _browse(directory,
        authorization: authorization, saveAccount: account);
  }

  Future<void> _browse(Uri directory,
      {String? authorization, WebDavAccount? saveAccount}) async {
    final accountId = _accountId ?? _endpoint.text.trim();
    final auth = authorization ??
        await ref.read(webDavCredentialsProvider).read(accountId);
    if (auth == null || auth.isEmpty) return _showConnection();
    setState(() {
      _loading = true;
      _error = null;
      _directory = directory;
      _entries = null;
      _query = '';
    });
    try {
      final entries = await _client.list(directory, authorization: auth);
      if (saveAccount != null) {
        await ref
            .read(webDavCredentialsProvider)
            .saveAccount(saveAccount, auth);
      }
      if (mounted) setState(() => _entries = entries);
    } on Object {
      if (mounted) setState(() => _error = '无法连接 WebDAV 服务器或读取当前目录。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _play(WebDavEntry entry) {
    final accountId = _accountId;
    if (accountId == null || _directory == null) return;
    final tracks = _entries!
        .where(_client.isAudio)
        .map((item) =>
            _client.toTrack(item, accountId: accountId, endpoint: _directory!))
        .toList(growable: false);
    final index =
        tracks.indexWhere((track) => track.sourceTrackId == entry.path);
    if (index < 0) return;
    ref.read(playbackQueueProvider.notifier).replaceQueue(tracks,
        startIndex: index, contextId: 'webdav:$accountId');
    ref.read(playerProvider.notifier).playTrack(tracks[index]);
  }

  void _download(WebDavEntry entry) {
    final accountId = _accountId;
    if (accountId == null || _directory == null) return;
    ref.read(downloadProvider.notifier).enqueue(
        _client.toTrack(entry, accountId: accountId, endpoint: _directory!));
  }

  void _addToPlaylist(WebDavEntry entry) {
    final accountId = _accountId;
    if (accountId == null || _directory == null) return;
    addTrackToPlaylist(
      context,
      ref,
      _client.toTrack(entry, accountId: accountId, endpoint: _directory!),
    );
  }

  void _showConnection({bool newConnection = false}) => setState(() {
        _directory = null;
        _entries = null;
        _error = null;
        if (newConnection) {
          _accountId = null;
          _endpoint.clear();
          _accountName.clear();
          _authorization.clear();
        }
      });

  Future<void> _showAccountPicker() async {
    final accounts = await ref.read(webDavCredentialsProvider).readAccounts();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
          children: [
            const ListTile(title: Text('已保存的 WebDAV 连接')),
            ...accounts.map(
              (account) => ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(account.name),
                subtitle: Text(account.endpoint.toString(),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _selectAccount(account);
                },
                trailing: IconButton(
                  tooltip: '删除连接',
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _removeAccount(account);
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_outlined),
              title: const Text('添加新的 WebDAV 连接'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showConnection(newConnection: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectAccount(WebDavAccount account) async {
    final credentials = ref.read(webDavCredentialsProvider);
    final authorization = await credentials.read(account.id);
    if (!mounted) return;
    if (authorization == null || authorization.isEmpty) {
      setState(() => _error = '此连接的授权信息已不可用，请重新填写。');
      _showConnection();
      return;
    }
    setState(() {
      _accountId = account.id;
      _endpoint.text = account.endpoint.toString();
      _accountName.text = account.name;
      _authorization.text = authorization;
    });
    await credentials.saveLastAccount(account.id);
    await _browse(account.endpoint);
  }

  Future<void> _removeAccount(WebDavAccount account) async {
    await ref.read(webDavCredentialsProvider).removeAccount(account.id);
    if (!mounted) return;
    if (_accountId != account.id) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已删除 ${account.name}')));
      return;
    }
    setState(() {
      _accountId = null;
      _directory = null;
      _entries = null;
      _error = null;
      _endpoint.clear();
      _accountName.clear();
      _authorization.clear();
    });
    await _restoreConnection();
  }

  Uri _directoryUri(Uri uri) =>
      uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');

  Uri? get _parentDirectory {
    final directory = _directory;
    final root = Uri.tryParse(_accountId ?? '');
    if (directory == null || root == null) return null;
    return parentWebDavDirectory(directory, root);
  }

  bool _matchesQuery(WebDavEntry entry) {
    final query = _query.trim().toLowerCase();
    return query.isEmpty ||
        _displayName(_directory!.resolve(entry.path))
            .toLowerCase()
            .contains(query);
  }

  String _displayName(Uri uri) {
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? uri.toString() : parts.last;
  }

  String _defaultAccountName(Uri uri) =>
      uri.host.isEmpty ? 'WebDAV 连接' : uri.host;
}
