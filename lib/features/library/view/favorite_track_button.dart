import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';
import '../state/library_controller.dart';

class FavoriteTrackButton extends ConsumerStatefulWidget {
  const FavoriteTrackButton({required this.track, super.key});

  final Track track;

  @override
  ConsumerState<FavoriteTrackButton> createState() =>
      _FavoriteTrackButtonState();
}

class _FavoriteTrackButtonState extends ConsumerState<FavoriteTrackButton> {
  late Future<bool> _favorite;
  late final ProviderSubscription<int> _favoriteSubscription;
  var _isToggling = false;

  @override
  void initState() {
    super.initState();
    _favorite = _loadFavorite();
    _favoriteSubscription = ref.listenManual(
      libraryProvider.select((state) => state.favoriteRevision),
      (previous, _) {
        if (previous != null && mounted) {
          setState(() => _favorite = _loadFavorite());
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant FavoriteTrackButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) _favorite = _loadFavorite();
  }

  Future<bool> _loadFavorite() =>
      ref.read(libraryProvider.notifier).isFavorite(widget.track.id);

  @override
  void dispose() {
    _favoriteSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _favorite,
        builder: (context, snapshot) => IconButton(
          tooltip: snapshot.data == true ? '取消收藏' : '收藏歌曲',
          onPressed:
              snapshot.connectionState != ConnectionState.done || _isToggling
                  ? null
                  : () async {
                      final previous = snapshot.data == true;
                      setState(() {
                        _isToggling = true;
                        _favorite = Future.value(!previous);
                      });
                      final favorite = await ref
                          .read(libraryProvider.notifier)
                          .toggleFavorite(widget.track);
                      if (!mounted || !context.mounted) return;
                      final error = ref.read(libraryProvider).error;
                      setState(() {
                        _isToggling = false;
                        _favorite = error == null
                            ? Future.value(favorite)
                            : _loadFavorite();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              error?.message ?? (favorite ? '已收藏歌曲' : '已取消收藏')),
                        ),
                      );
                    },
          icon: Icon(
            snapshot.data == true
                ? Icons.favorite_rounded
                : Icons.favorite_border,
            color: snapshot.data == true
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      );
}

class FavoriteOnlinePlaylistButton extends ConsumerStatefulWidget {
  const FavoriteOnlinePlaylistButton({required this.detail, super.key});

  final PlaylistDetail detail;

  @override
  ConsumerState<FavoriteOnlinePlaylistButton> createState() =>
      _FavoriteOnlinePlaylistButtonState();
}

class _FavoriteOnlinePlaylistButtonState
    extends ConsumerState<FavoriteOnlinePlaylistButton> {
  late Future<bool> _favorite;
  late final ProviderSubscription<int> _subscription;
  var _isToggling = false;

  @override
  void initState() {
    super.initState();
    _favorite = _loadFavorite();
    _subscription = ref.listenManual(
      libraryProvider.select((state) => state.playlistFavoriteRevision),
      (previous, _) {
        if (previous != null && mounted) {
          setState(() => _favorite = _loadFavorite());
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant FavoriteOnlinePlaylistButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.playlist.id != widget.detail.playlist.id ||
        oldWidget.detail.playlist.source != widget.detail.playlist.source) {
      _favorite = _loadFavorite();
    }
  }

  Future<bool> _loadFavorite() => ref
      .read(libraryProvider.notifier)
      .isFavoriteOnlinePlaylist(widget.detail.playlist);

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _favorite,
        builder: (context, snapshot) => IconButton(
          tooltip: snapshot.data == true ? '取消收藏歌单' : '收藏歌单',
          onPressed:
              snapshot.connectionState != ConnectionState.done || _isToggling
                  ? null
                  : () async {
                      final previous = snapshot.data == true;
                      setState(() {
                        _isToggling = true;
                        _favorite = Future.value(!previous);
                      });
                      final favorite = await ref
                          .read(libraryProvider.notifier)
                          .toggleFavoriteOnlinePlaylist(widget.detail);
                      if (!mounted) return;
                      final error = ref.read(libraryProvider).error;
                      setState(() {
                        _isToggling = false;
                        _favorite = error == null
                            ? Future.value(favorite)
                            : _loadFavorite();
                      });
                    },
          icon: Icon(
            snapshot.data == true ? Icons.bookmark : Icons.bookmark_border,
            color: snapshot.data == true
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      );
}

class FavoriteAlbumButton extends ConsumerStatefulWidget {
  const FavoriteAlbumButton({
    required this.name,
    required this.tracks,
    super.key,
  });

  final String name;
  final List<Track> tracks;

  @override
  ConsumerState<FavoriteAlbumButton> createState() =>
      _FavoriteAlbumButtonState();
}

class _FavoriteAlbumButtonState extends ConsumerState<FavoriteAlbumButton> {
  late Future<bool> _favorite;
  var _isToggling = false;

  @override
  void initState() {
    super.initState();
    _favorite = _loadFavorite();
  }

  @override
  void didUpdateWidget(covariant FavoriteAlbumButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name || oldWidget.tracks != widget.tracks) {
      _favorite = _loadFavorite();
    }
  }

  Future<bool> _loadFavorite() =>
      ref.read(libraryProvider.notifier).isFavoriteAlbum(
            widget.name,
            widget.tracks,
          );

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _favorite,
        builder: (context, snapshot) => IconButton(
          tooltip: snapshot.data == true ? '取消收藏专辑' : '收藏专辑',
          onPressed: snapshot.connectionState != ConnectionState.done ||
                  _isToggling ||
                  widget.tracks.isEmpty
              ? null
              : () async {
                  final previous = snapshot.data == true;
                  setState(() {
                    _isToggling = true;
                    _favorite = Future.value(!previous);
                  });
                  final favorite = await ref
                      .read(libraryProvider.notifier)
                      .toggleFavoriteAlbum(widget.name, widget.tracks);
                  if (!mounted) return;
                  final error = ref.read(libraryProvider).error;
                  setState(() {
                    _isToggling = false;
                    _favorite = error == null
                        ? Future.value(favorite)
                        : _loadFavorite();
                  });
                },
          icon: Icon(
            snapshot.data == true ? Icons.bookmark : Icons.bookmark_border,
            color: snapshot.data == true
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      );
}
