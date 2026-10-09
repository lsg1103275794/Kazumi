import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/webdav_media/webdav_media_utils.dart';

void main() {
  group('WebDavMediaUtils.isVideoFile', () {
    test('识别常见视频扩展名', () {
      expect(WebDavMediaUtils.isVideoFile('01.mp4'), isTrue);
      expect(WebDavMediaUtils.isVideoFile('EP01.MKV'), isTrue);
      expect(WebDavMediaUtils.isVideoFile('movie.webm'), isTrue);
    });

    test('忽略非视频与无扩展名文件', () {
      expect(WebDavMediaUtils.isVideoFile('cover.jpg'), isFalse);
      expect(WebDavMediaUtils.isVideoFile('readme'), isFalse);
      expect(WebDavMediaUtils.isVideoFile('file.'), isFalse);
    });
  });

  group('WebDavMediaUtils.compareNatural', () {
    test('数字段按数值排序', () {
      final names = ['10.mp4', '2.mp4', '1.mp4']
        ..sort(WebDavMediaUtils.compareNatural);
      expect(names, ['1.mp4', '2.mp4', '10.mp4']);
    });

    test('相同数字前缀时按数值比较', () {
      expect(
        WebDavMediaUtils.compareNatural('EP2.mp4', 'EP10.mp4'),
        lessThan(0),
      );
    });
  });

  group('WebDavMediaUtils.matchScore', () {
    test('连续包含得 2 分', () {
      expect(WebDavMediaUtils.matchScore('凡人修仙传', '凡人修仙传'), 2);
      expect(WebDavMediaUtils.matchScore('凡人修仙传 第一季', '凡人修仙传'), 2);
    });

    test('子序列包含得 1 分 (兼容干扰字符命名)', () {
      expect(
        WebDavMediaUtils.matchScore('C 苍沧Y元1T图第三季.2026', '沧元图'),
        1,
      );
    });

    test('大小写不敏感', () {
      expect(WebDavMediaUtils.matchScore('Grand Blue S3', 'grand blue'), 2);
    });

    test('不匹配得 0 分', () {
      expect(WebDavMediaUtils.matchScore('航海王', '沧元图'), 0);
    });

    test('空关键词得 0 分', () {
      expect(WebDavMediaUtils.matchScore('任意', ''), 0);
    });
  });

  group('WebDavMediaUtils.buildFileUrl', () {
    test('逐段编码并保留根地址', () {
      expect(
        WebDavMediaUtils.buildFileUrl(
          baseUrl: 'http://127.0.0.1:5244/dav/',
          path: '/电视/凡人修仙传/01.mp4',
        ),
        'http://127.0.0.1:5244/dav/%E7%94%B5%E8%A7%86/'
        '%E5%87%A1%E4%BA%BA%E4%BF%AE%E4%BB%99%E4%BC%A0/01.mp4',
      );
    });
  });

  group('WebDavMediaUtils.formatFileSize', () {
    test('按量级格式化', () {
      expect(WebDavMediaUtils.formatFileSize(null), '');
      expect(WebDavMediaUtils.formatFileSize(512), '512 B');
      expect(WebDavMediaUtils.formatFileSize(625800192), '596.8 MB');
      expect(WebDavMediaUtils.formatFileSize(1073741824), '1.0 GB');
    });
  });
}
