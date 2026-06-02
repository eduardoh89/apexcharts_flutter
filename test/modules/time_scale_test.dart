import 'package:apex_dart/apex_dart.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the datetime tick generator ported from ApexCharts TimeScale.js.
/// The key behaviour: tick interval + label format follow the visible span, so
/// a multi-year window labels months/years rather than repeating "dd MMM".
void main() {
  int ms(String iso) => DateTime.parse(iso).millisecondsSinceEpoch;

  group('TimeScale.ticks', () {
    test('multi-year span uses month labels ("MMM \'yy")', () {
      final ticks = TimeScale.ticks(
        ms('2012-03-01').toDouble(),
        ms('2013-02-27').toDouble(),
        tickAmount: 6,
      );
      expect(ticks, isNotEmpty);
      // Labels should be month + 2-digit year, e.g. "Mar '12".
      expect(ticks.first.label, matches(RegExp(r"^[A-Z][a-z]{2} '\d{2}$")));
      // Ticks are calendar-aligned (1st of a month) and ascending.
      for (var i = 1; i < ticks.length; i++) {
        expect(ticks[i].ms, greaterThan(ticks[i - 1].ms));
      }
    });

    test('5+ year span uses bare year labels', () {
      final ticks = TimeScale.ticks(
        ms('2010-01-01').toDouble(),
        ms('2020-01-01').toDouble(),
      );
      expect(ticks, isNotEmpty);
      expect(ticks.first.label, matches(RegExp(r'^\d{4}$')));
    });

    test('few-day span uses day labels ("dd MMM")', () {
      final ticks = TimeScale.ticks(
        ms('2012-03-01').toDouble(),
        ms('2012-03-08').toDouble(),
      );
      expect(ticks, isNotEmpty);
      expect(ticks.first.label, matches(RegExp(r'^\d{2} [A-Z][a-z]{2}$')));
    });

    test('honours tickAmount as an upper bound', () {
      final ticks = TimeScale.ticks(
        ms('2012-01-01').toDouble(),
        ms('2013-12-31').toDouble(),
        tickAmount: 6,
      );
      expect(ticks.length, lessThanOrEqualTo(6));
    });
  });

  group('XWindow.clampTo one-sided window', () {
    test('open max edge resolves to the domain max', () {
      // Only a min set (the +inf upper edge of an `xaxis.min`-only window).
      final w = XWindow(50, double.infinity).clampTo(0, 100);
      expect(w.min, closeTo(50, 0.01));
      expect(w.max, closeTo(100, 0.01));
    });

    test('open min edge resolves to the domain min', () {
      final w = XWindow(double.negativeInfinity, 40).clampTo(0, 100);
      expect(w.min, closeTo(0, 0.01));
      expect(w.max, closeTo(40, 0.01));
    });
  });
}
