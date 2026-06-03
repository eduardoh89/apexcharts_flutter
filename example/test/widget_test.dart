import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apexcharts_flutter_example/main.dart';

void main() {
  testWidgets('Gallery renders its app bar title', (tester) async {
    await tester.pumpWidget(const GalleryApp());
    await tester.pump();
    expect(find.byType(GalleryApp), findsOneWidget);
  });
}
