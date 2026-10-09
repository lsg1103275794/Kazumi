import 'dart:convert';

/// WebDAV 媒体浏览的工具集合: 视频文件识别、直链拼接、鉴权头与文件大小展示。
class WebDavMediaUtils {
  WebDavMediaUtils._();

  /// 常见视频容器扩展名 (小写, 不含点)。
  static const Set<String> _videoExtensions = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'flv',
    'wmv',
    'webm',
    'm4v',
    'ts',
    'm2ts',
    'mts',
    'mpg',
    'mpeg',
    'rm',
    'rmvb',
    '3gp',
    'ogv',
  };

  /// 根据扩展名判断是否为可播放的视频文件。
  static bool isVideoFile(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == name.length - 1) {
      return false;
    }
    return _videoExtensions.contains(name.substring(dotIndex + 1).toLowerCase());
  }

  /// 拼接父目录与文件名为服务器上的绝对路径。
  static String joinPath(String parent, String name) {
    final base =
        parent.endsWith('/') ? parent.substring(0, parent.length - 1) : parent;
    return '$base/$name';
  }

  /// 基于服务器根地址与文件在服务器上的绝对路径拼接直链。
  ///
  /// 路径逐段进行 URL 编码并保留分隔符, 以兼容中文与空格文件名。
  static String buildFileUrl({
    required String baseUrl,
    required String path,
  }) {
    final root =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .toList();
    if (segments.isEmpty) {
      return root;
    }
    return '$root/${segments.join('/')}';
  }

  /// 构建 WebDAV Basic 鉴权请求头; 匿名访问 (账号密码均为空) 时返回空 Map。
  static Map<String, String> buildAuthHeaders({
    required String username,
    required String password,
  }) {
    if (username.isEmpty && password.isEmpty) {
      return const {};
    }
    final token = base64Encode(utf8.encode('$username:$password'));
    return {'authorization': 'Basic $token'};
  }

  /// 将字节数格式化为易读的大小文本, 无法识别时返回空字符串。
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes < 0) {
      return '';
    }
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text =
        unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$text ${units[unit]}';
  }
}
