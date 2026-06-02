import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads a real sans-serif font (Inter, OFL) for all tests so axis/legend text
/// rasterizes as actual glyphs instead of the test-only "Ahem" font (which
/// draws every character as a solid box and wrecks the visual diff against the
/// ApexCharts reference, whose default family is Helvetica/Arial).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fontData = File('test/assets/fonts/Inter-Variable.ttf').readAsBytesSync();
  final loader = FontLoader('Inter')
    ..addFont(Future.value(ByteData.view(fontData.buffer)));
  await loader.load();

  await testMain();
}
