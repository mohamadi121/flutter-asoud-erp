import 'package:asoud_erp/features/workflows/data/offline_preview_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// The offline leave preview follows the server's `leave_hours.py`: exact
/// half-up rounding, no duration when a time rule fails, the same messages.
void main() {
  Map<String, dynamic> hourly(String start, String end,
          {String date = '2026-10-07'}) =>
      offlinePreviewLeave({
        'leave_type': 'Casual Leave',
        'request_kind': 'Hourly',
        'leave_date': date,
        'start_time': start,
        'end_time': end,
      });

  Map<String, dynamic> duration(Map<String, dynamic> preview) =>
      Map<String, dynamic>.from(preview['duration'] as Map);

  test('hours and day equivalent round half up like the server', () {
    // 15 min: 0.25 h, 0.25 / 8 = 0.03125 -> 0.0313 (half up).
    expect(duration(hourly('09:00', '09:15'))['hours'], 0.25);
    expect(duration(hourly('09:00', '09:15'))['day_equivalent'], 0.0313);
    // 21 min: 0.35 h, 0.35 / 8 = 0.04375 -> 0.0438 (a binary double gives 0.0437).
    expect(duration(hourly('09:00', '09:21'))['hours'], 0.35);
    expect(duration(hourly('09:00', '09:21'))['day_equivalent'], 0.0438);
    // 22 min: 0.37 h -> 0.04625 -> 0.0463.
    expect(duration(hourly('09:00', '09:22'))['day_equivalent'], 0.0463);
    // 4 h at 8 h/day is half a day.
    expect(duration(hourly('08:00', '12:00'))['day_equivalent'], 0.5);
  });

  test('a failed time rule returns no duration and the server message', () {
    final short = hourly('09:00', '09:10');
    expect(short['valid'], isFalse);
    expect(duration(short)['hours'], isNull);
    expect((short['errors'] as List).single['code'], 'INVALID_TIME_RANGE');
    expect((short['errors'] as List).single['message'],
        'حداقل مدت مرخصی ساعتی ۱۵ دقیقه است.');

    final long = hourly('06:00', '15:00');
    expect(duration(long)['hours'], isNull);
    expect((long['errors'] as List).single['code'], 'HOURLY_EXCEEDS_DAY');
  });

  test('Friday is the only holiday and uses the server message', () {
    final friday = hourly('09:00', '10:00', date: '2026-10-09');
    final error = (friday['errors'] as List).single as Map;
    expect(error['code'], 'HOURLY_ON_HOLIDAY');
    expect(error['message'], 'تاریخ انتخاب‌شده برای شما تعطیل است.');
    final range = offlinePreviewLeave({
      'leave_type': 'Casual Leave',
      'request_kind': 'Daily',
      'start_date': '2026-10-09',
      'end_date': '2026-10-09',
    });
    expect((range['errors'] as List).single['code'], 'LEAVE_ALL_HOLIDAYS');
    expect((range['errors'] as List).single['message'],
        'روزهای انتخاب‌شده همگی تعطیل هستند و نیازی به مرخصی نیست.');
  });
}
