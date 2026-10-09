import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/core/utils/persian_server_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('مقادیر نمایشی سرور به فارسی و جلالی تبدیل می‌شوند', () {
    expect(
      formatJalaliDateTime(DateTime(2026, 10, 9, 22, 40)),
      '۲۲:۴۰، ۱۴۰۵/۰۷/۱۷',
    );
    expect(formatJalaliIso('1976-04-12'), '۱۳۵۵/۰۱/۲۳');
    expect(persianGenderLabel('Male'), 'مرد');
    expect(persianRequestFieldTypeLabel('Date'), 'تاریخ');
    expect(persianWorkflowStageTitle('Start'), 'شروع');
    expect(persianWorkflowStageTitle('User Task'), 'وظیفه کاربر');
    expect(persianWorkflowStageTitle('Approval'), 'تأیید');
    expect(persianWorkflowStageTitle('System Action'), 'اقدام خودکار');
    expect(
      persianServerMessage('Workflow stages and transitions are not complete'),
      'مراحل و مسیرهای گردش‌کار کامل نیستند.',
    );
    expect(persianRoleLabel('System Manager'), 'مدیر سیستم');
    expect(persianRoleLabel('Accounts User'), 'کارشناس مالی');
    expect(persianRoleLabel('نقش سفارشی'), 'نقش سفارشی');
  });
}
