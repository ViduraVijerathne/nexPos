import 'package:flutter_test/flutter_test.dart';
import 'package:nex_pos_desktop/core/widgets/app_date_field.dart';

void main() {
  test('accepts real calendar dates, including leap days', () {
    expect(parseAppDate(' 2024-02-29 '), DateTime(2024, 2, 29));
    expect(parseAppDate('2026-12-31'), DateTime(2026, 12, 31));
  });

  test('rejects overflowing dates and non-date input', () {
    for (final input in [
      null,
      '',
      '2026-02-29',
      '2026-02-30',
      '2026-04-31',
      '2026-13-01',
      '2026-01-00',
      '20260101',
      '2026-01-01T12:00:00',
    ]) {
      expect(parseAppDate(input), isNull, reason: 'Invalid date: $input');
    }
  });
}
