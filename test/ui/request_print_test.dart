import 'package:asoud_erp/features/workflows/presentation/widgets/request_print.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('printed values use the formatted text, not the raw stored value', () {
    final rows = requestPrintFields(
      {'leave_date': '2026-10-06', 'kind': 'sick', 'days': 3},
      labels: const {
        'leave_date': 'تاریخ مرخصی',
        'kind': 'نوع',
        'days': 'تعداد روز'
      },
      formatted: const {'leave_date': '۱۴۰۵/۰۷/۱۴', 'kind': 'استعلاجی'},
    );
    expect(rows, [
      ['تاریخ مرخصی', '۱۴۰۵/۰۷/۱۴'],
      ['نوع', 'استعلاجی'],
      ['تعداد روز', '۳'],
    ]);
    expect(rows.expand((row) => row).join(' '), isNot(contains('sick')));
    expect(rows.expand((row) => row).join(' '), isNot(contains('2026')));
  });

  test('table values are left out of the field rows', () {
    final rows = requestPrintFields({
      'items': [
        {'item_code': 'A'}
      ],
      'note': 'x'
    }, labels: const {
      'note': 'یادداشت'
    });
    expect(rows.map((row) => row.first), ['یادداشت']);
  });

  test('a rejected request prints the rejection reason', () {
    expect(requestPrintReasons({'rejection_reason': ' بودجه کافی نیست '}), [
      ['علت رد', 'بودجه کافی نیست'],
    ]);
  });

  test('a returned step prints its comment as the return reason', () {
    expect(
        requestPrintReasons({
          'stages': [
            {'status': 'done', 'comment': 'ok'},
            {'status': 'returned', 'comment': 'پیوست را کامل کنید'},
            {'status': 'pending', 'comment': ''},
          ]
        }),
        [
          ['علت بازگشت', 'پیوست را کامل کنید'],
        ]);
  });

  test('a request without reasons prints none', () {
    expect(requestPrintReasons({'stages': const []}), isEmpty);
  });
}
