import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import 'package:kazumi/bean/dialog/dialog.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/pages/webdav_media/webdav_media_utils.dart';
import 'package:kazumi/pages/webdav_media/webdav_player_page.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/webdav.dart';

/// WebDAV 网盘媒体浏览页: 按目录浏览云盘文件, 点选视频文件调用内置播放器播放。
class WebDavMediaPage extends StatefulWidget {
  const WebDavMediaPage({super.key});

  @override
  State<WebDavMediaPage> createState() => _WebDavMediaPageState();
}

class _WebDavMediaPageState extends State<WebDavMediaPage> {
  static const String _rootPath = '/';

  String _path = _rootPath;
  List<webdav.File> _entries = const [];
  bool _loading = true;
  bool _needsConfig = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openDirectory(_rootPath);
  }

  Future<void> _openDirectory(String path) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _needsConfig = false;
    });
    try {
      if (GStorage.getSetting(SettingsKeys.webDavURL).trim().isEmpty) {
        setState(() {
          _loading = false;
          _needsConfig = true;
          _error = '尚未配置 WebDAV 服务器, 请先在同步设置中填写连接信息。';
        });
        return;
      }
      final webDav = WebDav();
      if (!webDav.initialized) {
        await webDav.init();
      }
      final entries = await webDav.client.readDir(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = _sortEntries(entries);
        _loading = false;
      });
    } catch (e) {
      KazumiLogger()
          .w('WebDavMedia: failed to read directory $path', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '目录读取失败, 请检查 WebDAV 连接后重试。';
      });
    }
  }

  List<webdav.File> _sortEntries(List<webdav.File> entries) {
    final sorted = entries
        .where((entry) => !(entry.name ?? '').startsWith('.'))
        .toList();
    sorted.sort((a, b) {
      final dirA = a.isDir == true;
      final dirB = b.isDir == true;
      if (dirA != dirB) {
        return dirA ? -1 : 1;
      }
      return (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
    });
    return sorted;
  }

  void _enterDirectory(String name) {
    _openDirectory(WebDavMediaUtils.joinPath(_path, name));
  }

  void _playFile(webdav.File entry) {
    final name = entry.name ?? '';
    context.pushNamed(
      '/webdav-media/player',
      arguments: WebDavPlayerPageArgs(
        path: WebDavMediaUtils.joinPath(_path, name),
        name: name,
      ),
    );
  }

  /// 当前路径的面包屑: (显示名, 对应路径) 列表, 首项固定为根目录。
  List<(String, String)> _buildCrumbs(String path) {
    final crumbs = <(String, String)>[('根目录', _rootPath)];
    var accumulated = '';
    for (final segment in path.split('/')) {
      if (segment.isEmpty) continue;
      accumulated += '/$segment';
      crumbs.add((segment, accumulated));
    }
    return crumbs;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('网盘媒体'),
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: _loading ? null : () => _openDirectory(_path),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        children: [
          _buildBreadcrumb(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    final crumbs = _buildCrumbs(_path);
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (var index = 0; index < crumbs.length; index++) ...[
            if (index > 0)
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: colorScheme.outline),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: index == crumbs.length - 1
                  ? null
                  : () => _openDirectory(crumbs[index].$2),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                child: Text(
                  crumbs[index].$1,
                  style: TextStyle(
                    color: index == crumbs.length - 1
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: index == crumbs.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError();
    }
    if (_entries.isEmpty) {
      return const Center(child: Text('此目录为空'));
    }
    return ListView.builder(
      itemCount: _entries.length,
      itemBuilder: (context, index) => _buildEntryTile(_entries[index]),
    );
  }

  Widget _buildError() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 12,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: colorScheme.outline),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
          ),
          StateActionButton(
            onPressed: () => _openDirectory(_path),
            text: '重试',
            icon: Icons.refresh_rounded,
          ),
          if (_needsConfig)
            TextButton(
              onPressed: () => context.pushNamed('/settings/webdav/editor'),
              child: const Text('前往 WebDAV 配置'),
            ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(webdav.File entry) {
    final name = entry.name ?? '';
    final isDir = entry.isDir == true;
    final isVideo = !isDir && WebDavMediaUtils.isVideoFile(name);
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle = isDir ? null : WebDavMediaUtils.formatFileSize(entry.size);
    return ListTile(
      leading: Icon(
        isDir
            ? Icons.folder_rounded
            : (isVideo ? Icons.movie_rounded : Icons.insert_drive_file_rounded),
        color: isVideo ? colorScheme.primary : null,
      ),
      title: Text(name),
      subtitle: (subtitle == null || subtitle.isEmpty) ? null : Text(subtitle),
      trailing: isDir
          ? const Icon(Icons.chevron_right_rounded)
          : (isVideo
              ? Icon(
                  Icons.play_circle_outline_rounded,
                  color: colorScheme.primary,
                )
              : null),
      onTap: () {
        if (isDir) {
          _enterDirectory(name);
        } else if (isVideo) {
          _playFile(entry);
        } else {
          KazumiDialog.showToast(message: '暂不支持在线播放此类型的文件');
        }
      },
    );
  }
}
