import 'dart:ui';

import 'package:apex_dart/apex_dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApexColor.isColorHex', () {
    test('accepts valid hex forms', () {
      expect(ApexColor.isColorHex('#fff'), isTrue);
      expect(ApexColor.isColorHex('#FF0000'), isTrue);
      expect(ApexColor.isColorHex('#FF000080'), isTrue);
    });
    test('rejects invalid', () {
      expect(ApexColor.isColorHex('red'), isFalse);
      expect(ApexColor.isColorHex('#GG0000'), isFalse);
    });
  });

  group('ApexColor.fromHex', () {
    test('parses 6-digit hex', () {
      final c = ApexColor.fromHex('#FF8000');
      expect((c.r * 255).round(), 255);
      expect((c.g * 255).round(), 128);
      expect((c.b * 255).round(), 0);
    });
    test('expands 3-digit hex', () {
      final c = ApexColor.fromHex('#f00');
      expect((c.r * 255).round(), 255);
      expect((c.g * 255).round(), 0);
    });
    test('falls back to grey on malformed input', () {
      final c = ApexColor.fromHex('nonsense');
      expect(ApexColor.toHex(c), '#999999');
    });
  });

  group('ApexColor.toHex round-trip', () {
    test('hex -> color -> hex is stable', () {
      const hex = '#3366cc';
      expect(ApexColor.toHex(ApexColor.fromHex(hex)).toLowerCase(), hex);
    });
  });

  group('ApexColor.shade', () {
    test('positive percent lightens toward white', () {
      final shaded = ApexColor.shade(const Color(0xFF000000), 0.5);
      expect((shaded.r * 255).round(), closeTo(128, 1));
    });
    test('negative percent darkens toward black', () {
      final shaded = ApexColor.shade(const Color(0xFFFFFFFF), -0.5);
      expect((shaded.r * 255).round(), closeTo(128, 1));
    });
  });
}
