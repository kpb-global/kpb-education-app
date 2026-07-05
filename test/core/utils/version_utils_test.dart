import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/utils/version_utils.dart';

void main() {
  group('isVersionBelow', () {
    test('detects a lower version', () {
      expect(isVersionBelow('1.0.0', '1.2.0'), isTrue);
      expect(isVersionBelow('0.9.9', '1.0.0'), isTrue);
    });

    test('is false for equal or higher versions', () {
      expect(isVersionBelow('1.2.0', '1.2.0'), isFalse);
      expect(isVersionBelow('1.3.0', '1.2.9'), isFalse);
      expect(isVersionBelow('2.0.0', '1.9.9'), isFalse);
    });

    test('ignores build metadata and pre-release suffixes', () {
      expect(isVersionBelow('1.0.0+45', '1.0.0'), isFalse);
      expect(isVersionBelow('1.0.0+45', '1.0.1'), isTrue);
      expect(isVersionBelow('1.2.0-beta', '1.2.0'), isFalse);
    });

    test('treats missing segments as zero', () {
      expect(isVersionBelow('1.2', '1.2.0'), isFalse);
      expect(isVersionBelow('1.2', '1.2.1'), isTrue);
    });

    test('fails open on unparseable input', () {
      expect(isVersionBelow('abc', '1.0.0'), isFalse);
      expect(isVersionBelow('1.0.0', 'abc'), isFalse);
      expect(isVersionBelow('', ''), isFalse);
    });
  });
}
