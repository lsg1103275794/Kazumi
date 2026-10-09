import 'package:kazumi/pages/webdav_media/webdav_media_utils.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/sync/webdav.dart';

/// WebDAV 网盘中的一条路径条目 (命中的番剧文件夹或其中的视频选集)。
class WebDavSourceEntry {
  const WebDavSourceEntry({required this.path, required this.name});

  /// 在 WebDAV 服务器上的绝对路径。
  final String path;

  /// 展示用名称。
  final String name;
}

/// 在 WebDAV 网盘中按名称检索番剧文件夹, 供来源弹层作为内置片源使用。
///
/// 从根目录出发做深度受限的广度优先扫描: 文件夹名包含关键词即视为命中,
/// 命中的文件夹不再继续下探; 每层并发受限, 命中数达到上限后提前收敛,
/// 避免大容量网盘拖慢来源弹层的呈现。
class WebDavSourceService {
  WebDavSourceService._();

  static const int _defaultMaxDepth = 3;
  static const int _defaultMaxResults = 8;
  static const int _concurrency = 6;

  /// 检索名称包含 [keyword] 的文件夹, 返回按扫描顺序排列的命中结果。
  static Future<List<WebDavSourceEntry>> searchFolders({
    required String keyword,
    int maxDepth = _defaultMaxDepth,
    int maxResults = _defaultMaxResults,
  }) async {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }
    final webDav = WebDav();
    if (!webDav.initialized) {
      await webDav.init();
    }
    final matches = <WebDavSourceEntry>[];
    var frontier = <String>['/'];
    for (var depth = 0; depth < maxDepth && frontier.isNotEmpty; depth++) {
      final nextFrontier = <String>[];
      for (final batch in _chunks(frontier, _concurrency)) {
        final childrenGroups = await Future.wait(
          batch.map((dir) => _listChildFolders(webDav, dir)),
        );
        for (final children in childrenGroups) {
          for (final child in children) {
            if (child.name.toLowerCase().contains(normalized)) {
              matches.add(WebDavSourceEntry(
                path: child.path,
                name: child.name,
              ));
              if (matches.length >= maxResults) {
                return matches;
              }
            } else {
              nextFrontier.add(child.path);
            }
          }
        }
      }
      frontier = nextFrontier;
    }
    return matches;
  }

  /// 列出 [folderPath] 内的视频文件, 按自然序排序作为选集。
  static Future<List<WebDavSourceEntry>> listEpisodes(String folderPath) async {
    final webDav = WebDav();
    if (!webDav.initialized) {
      await webDav.init();
    }
    final entries = await webDav.client.readDir(folderPath);
    final episodes = <WebDavSourceEntry>[];
    for (final entry in entries) {
      final name = entry.name ?? '';
      if (entry.isDir == true || name.isEmpty || name.startsWith('.')) {
        continue;
      }
      if (!WebDavMediaUtils.isVideoFile(name)) {
        continue;
      }
      episodes.add(WebDavSourceEntry(
        path: WebDavMediaUtils.joinPath(folderPath, name),
        name: name,
      ));
    }
    episodes.sort((a, b) => WebDavMediaUtils.compareNatural(a.name, b.name));
    return episodes;
  }

  static Future<List<_WebDavChildFolder>> _listChildFolders(
    WebDav webDav,
    String dir,
  ) async {
    try {
      final entries = await webDav.client.readDir(dir);
      final children = <_WebDavChildFolder>[];
      for (final entry in entries) {
        final name = entry.name ?? '';
        if (entry.isDir != true || name.isEmpty || name.startsWith('.')) {
          continue;
        }
        children.add(_WebDavChildFolder(
          name: name,
          path: WebDavMediaUtils.joinPath(dir, name),
        ));
      }
      return children;
    } catch (e) {
      KazumiLogger().w('WebDavSource: failed to read $dir', error: e);
      return const [];
    }
  }

  static Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var offset = 0; offset < list.length; offset += size) {
      yield list.sublist(
        offset,
        offset + size > list.length ? list.length : offset + size,
      );
    }
  }
}

class _WebDavChildFolder {
  const _WebDavChildFolder({required this.name, required this.path});

  final String name;
  final String path;
}
