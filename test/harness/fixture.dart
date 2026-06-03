import 'dart:convert';
import 'dart:io';

/// A test fixture shared between the ApexCharts reference renderer
/// (`tool/render_reference.mjs`) and the Flutter golden tests.
///
/// The same JSON file drives both sides so geometry and data are identical.
class ChartFixture {
  ChartFixture({
    required this.name,
    required this.width,
    required this.height,
    required this.options,
  });

  final String name;
  final double width;
  final double height;

  /// The raw ApexCharts `options` object. `apex_dart` parses the subset it
  /// supports into its own typed model.
  final Map<String, dynamic> options;

  factory ChartFixture.fromJson(Map<String, dynamic> json) {
    return ChartFixture(
      name: json['name'] as String,
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      options: Map<String, dynamic>.from(json['options'] as Map),
    );
  }

  /// Load a single fixture by name (without extension).
  static ChartFixture load(String name) {
    final file = File('tool/fixtures/$name.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return ChartFixture.fromJson(json);
  }

  /// Load every fixture in `tool/fixtures/`.
  static List<ChartFixture> loadAll() {
    final dir = Directory('tool/fixtures');
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => ChartFixture.fromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Path to the ApexCharts reference PNG for this fixture (may not exist
  /// until `render_reference.mjs` has been run).
  String get referencePngPath => 'test/golden/reference/$name.png';

  bool get hasReference => File(referencePngPath).existsSync();
}
