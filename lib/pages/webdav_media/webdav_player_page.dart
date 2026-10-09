import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog.dart';
import 'package:kazumi/pages/webdav_media/webdav_media_utils.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/sync/webdav.dart';

/// 播放参数, 经路由 arguments 传入。
class WebDavPlayerPageArgs {
  const WebDavPlayerPageArgs({required this.path, required this.name});

  /// 文件在 WebDAV 服务器上的绝对路径。
  final String path;

  /// 用于展示的文件名。
  final String name;
}

/// WebDAV 网盘视频播放页: 携带 Basic 鉴权头使用直链流式播放, 无需下载到本地。
class WebDavPlayerPage extends StatefulWidget {
  const WebDavPlayerPage({
    super.key,
    required this.path,
    required this.name,
  });

  final String path;
  final String name;

  @override
  State<WebDavPlayerPage> createState() => _WebDavPlayerPageState();
}

class _WebDavPlayerPageState extends State<WebDavPlayerPage> {
  late final Player _player;
  late final VideoController _videoController;
  bool _opening = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player(configuration: const PlayerConfiguration(osc: false));
    _videoController = VideoController(_player);
    _player.stream.error.listen(_onPlayerError);
    _open();
  }

  Future<void> _open() async {
    if (mounted) {
      setState(() {
        _opening = true;
        _error = null;
      });
    }
    try {
      final webDav = WebDav();
      if (!webDav.initialized) {
        await webDav.init();
      }
      final url = WebDavMediaUtils.buildFileUrl(
        baseUrl: webDav.webDavURL,
        path: widget.path,
      );
      final headers = WebDavMediaUtils.buildAuthHeaders(
        username: webDav.webDavUsername,
        password: webDav.webDavPassword,
      );
      await _player.open(Media(url, httpHeaders: headers));
      if (mounted) setState(() => _opening = false);
    } catch (e) {
      KazumiLogger().e('WebDavPlayer: failed to open ${widget.path}',
          error: e);
      if (mounted) {
        setState(() {
          _opening = false;
          _error = '视频打开失败, 请检查 WebDAV 连接与文件是否可用。';
        });
      }
    }
  }

  void _onPlayerError(String event) {
    KazumiLogger().w('WebDavPlayer: player error $event');
    if (mounted && !_opening) {
      KazumiDialog.showToast(message: '播放出错, 请尝试其他文件或检查网络');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: SysAppBar(
        title: Text(widget.name),
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: _error != null ? _buildError() : _buildPlayer(),
      ),
    );
  }

  Widget _buildPlayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Video(controller: _videoController),
        if (_opening)
          const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 12,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.white70),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          FilledButton.tonal(
            onPressed: _open,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
