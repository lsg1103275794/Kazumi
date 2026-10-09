import 'dart:convert';

/// WebDAV 媒体浏览的工具集合: 视频文件识别、直链拼接、鉴权头与文件大小展示。
class WebDavMediaUtils {
  WebDavMediaUtils._();

  /// 匹配时的空白字符 (空格/制表符等, 不含换行外的路径分隔语义)。
  static final RegExp _whitespacePattern = RegExp(r'[ \t\u3000]');

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

  /// 关键词与文件夹名的匹配打分。
  ///
  /// 匹配前会去掉两侧与中间的空白字符 (网盘文件夹与番剧名的空格习惯
  /// 往往不一致); 连续包含得 2 分; 字符按顺序出现 (子序列) 得 1 分,
  /// 用于兼容资源站在文件名中插入干扰字符的情况 (如 "C 苍沧Y元1T图第三季"
  /// 命中 "沧元图 第三季"); 不匹配得 0 分。
  static int matchScore(String folderName, String keyword) {
    final name = folderName.replaceAll(_whitespacePattern, '').toLowerCase();
    final kw = keyword.replaceAll(_whitespacePattern, '').toLowerCase();
    if (kw.isEmpty) {
      return 0;
    }
    if (name.contains(kw)) {
      return 2;
    }
    var matched = 0;
    for (var i = 0; i < name.length && matched < kw.length; i++) {
      if (name[i] == kw[matched]) {
        matched++;
      }
    }
    return matched == kw.length ? 1 : 0;
  }

  /// 自然序比较: 数字段按数值比较, 避免 '2' 排在 '10' 之后。
  static int compareNatural(String a, String b) {
    var i = 0;
    var j = 0;
    while (i < a.length && j < b.length) {
      final digitA = _isDigit(a[i]);
      final digitB = _isDigit(b[j]);
      if (digitA && digitB) {
        final startA = i;
        final startB = j;
        while (i < a.length && _isDigit(a[i])) {
          i++;
        }
        while (j < b.length && _isDigit(b[j])) {
          j++;
        }
        final numberA = int.tryParse(a.substring(startA, i)) ?? 0;
        final numberB = int.tryParse(b.substring(startB, j)) ?? 0;
        final byNumber = numberA.compareTo(numberB);
        if (byNumber != 0) {
          return byNumber;
        }
      } else {
        final byChar = a[i].toLowerCase().compareTo(b[j].toLowerCase());
        if (byChar != 0) {
          return byChar;
        }
        i++;
        j++;
      }
    }
    return (a.length - i).compareTo(b.length - j);
  }

  static bool _isDigit(String char) {
    return char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39;
  }
}
