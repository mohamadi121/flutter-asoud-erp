import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const table = {
    'submitted': ('ارسال شده', 'pending', AsoudColors.primary),
    'in_review': ('در حال بررسی', 'pending', AsoudColors.warning),
    'returned': ('برگشت برای اصلاح', 'pending', AsoudColors.warning),
    'failed': ('نیازمند بررسی', 'pending', AsoudColors.danger),
    'approved': ('تأیید شده', 'approved', AsoudColors.success),
    'rejected': ('رد شده', 'rejected', AsoudColors.danger),
    'cancelled': ('لغو شده', '', AsoudColors.muted),
    'draft': ('پیش‌نویس', '', AsoudColors.warning),
  };

  test('every status_key maps to its label, color and tab (§5)', () {
    expect(RequestStatusKey.values.map((key) => key.serverKey).toSet(),
        table.keys.toSet());
    for (final entry in table.entries) {
      final (label, group, color) = entry.value;
      final key = RequestStatusKey.fromServer(entry.key);
      expect(key.label, label, reason: entry.key);
      expect(key.group, group, reason: entry.key);
      final status = requestStatus({'status_key': entry.key});
      expect(status.$1, label, reason: entry.key);
      expect(status.$2, color, reason: entry.key);
      expect(
          RequestSummary.fromMap({'status_key': entry.key}).statusGroup, group,
          reason: entry.key);
    }
  });

  test('status_label overrides the table label (custom display_status)', () {
    final status = requestStatus(
        {'status_key': 'submitted', 'status_label': 'در انتظار تأیید مالی'});
    expect(status.$1, 'در انتظار تأیید مالی');
    expect(status.$2, AsoudColors.primary);
    // The table label is used when the server sends the same text.
    expect(
        requestStatus({'status_key': 'approved', 'status_label': 'تأیید شده'})
            .$2,
        AsoudColors.success);
  });

  test('client-only states come first and sit under the pending tab', () {
    expect(
        requestStatus({
          'status_key': 'approved',
          'pending_sync': true,
          'local_preview': true
        }),
        ('ذخیره روی گوشی', AsoudColors.primary));
    expect(requestStatus({'status_key': 'submitted', 'pending_sync': true}),
        ('در انتظار همگام‌سازی', AsoudColors.primary));
    // A queued request the server refused.
    expect(requestStatus({'status_key': 'failed', 'pending_sync': true}),
        ('نیازمند بررسی', AsoudColors.danger));
    final queued = RequestSummary.fromMap({
      'name': 'generic-request:x',
      'pending_sync': true,
      'status_group': 'pending',
      'status_key': 'submitted'
    });
    expect(queued.pendingSync, isTrue);
    expect(queued.statusGroup, 'pending');
    expect(queued.number, '—');
  });

  test('rows without a status_key use the legacy mapping', () {
    expect(requestStatus({'status': 'Running'}).$1, 'در انتظار تأیید');
    expect(requestStatus({'status': 'Completed'}).$1, 'تکمیل شده');
    expect(requestStatus({'status': 'Rejected'}).$1, 'رد شده');
    expect(requestStatus({'status': 'Cancelled'}).$1, 'لغو شده');
    expect(requestStatus({'status': 'Failed'}).$1, 'نیازمند بررسی');
    expect(requestStatus({'status': 'Draft'}).$1, 'پیش‌نویس');
    expect(requestStatus({'status': 'Running', 'display_status': 'در بازبینی'}),
        ('در بازبینی', AsoudColors.primary));
    expect(RequestStatusKey.fromMap({'status': 'Completed'}),
        RequestStatusKey.approved);
    expect(RequestStatusKey.fromMap({'status': 'Running'}),
        RequestStatusKey.submitted);
    expect(RequestStatusKey.fromServer('nonsense'), RequestStatusKey.submitted);
    expect(RequestStatusKey.isKnown('nonsense'), isFalse);
  });

  test('request links round-trip', () {
    expect(requestLink('PR-1405-0023'), 'asoud://request/PR-1405-0023');
    expect(parseRequestLink('asoud://request/PR-1405-0023'), 'PR-1405-0023');
    expect(parseRequestLink('  asoud://request/LV-1405-0042 '), 'LV-1405-0042');
    expect(parseRequestLink(requestLink('REQ 00007/x')), 'REQ 00007/x');
    for (final text in [
      '',
      'PR-1405-0023',
      'https://request/PR-1',
      'asoud://other/PR-1',
      'asoud://request/',
      'asoud://request',
      'asoud://request/a/b',
    ]) {
      expect(parseRequestLink(text), isNull, reason: text);
    }
  });

  test('requestErrorMessage shows the message of API and state errors', () {
    expect(
        requestErrorMessage(
            const ApiException(
                kind: ApiFailureKind.validation, message: 'پیام سرور'),
            'عمومی'),
        'پیام سرور');
    expect(requestErrorMessage(StateError('پیام مخزن'), 'عمومی'), 'پیام مخزن');
    expect(requestErrorMessage(Exception('x'), 'عمومی'), 'عمومی');
    expect(
        requestErrorMessage(
            const ApiException(kind: ApiFailureKind.network, message: ' '),
            'عمومی'),
        'عمومی');
  });
}
