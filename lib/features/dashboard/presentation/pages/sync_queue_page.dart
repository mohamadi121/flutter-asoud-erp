import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/offline/local_record.dart';
import '../../../../core/offline/offline_failure.dart';
import '../../../../core/offline/offline_sync_service.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';

/// «صف ارسال به سرور» — every write this phone still holds for the server, so
/// an unsent record is never invisible.
class SyncQueuePage extends StatefulWidget {
  const SyncQueuePage({required this.service, super.key});

  final OfflineSyncService service;

  @override
  State<SyncQueuePage> createState() => _SyncQueuePageState();
}

class _SyncQueuePageState extends State<SyncQueuePage> {
  List<LocalRecord>? _rows;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final rows = await widget.service.unsent();
    if (!mounted) return;
    setState(() => _rows = rows);
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDiscard(LocalRecord row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف از صف'),
        content: const Text(
          'این نوشته از صف ارسال حذف می‌شود و دیگر به سرور ارسال نخواهد شد. تا چند لحظه می‌توانید آن را بازگردانید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AsoudColors.danger),
            child: const Text('حذف می‌کنم'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final removed = await widget.service.discardReturning(row.id);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    final name = outboxRecordName(row);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(
          '«${name.isEmpty ? persianMutationLabel(row) : name}» از صف حذف شد'),
      action: SnackBarAction(
        label: 'بازگردانی',
        onPressed: () => unawaited(_restore(removed)),
      ),
    ));
  }

  Future<void> _restore(List<LocalRecord> removed) async {
    await widget.service.restore(removed);
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('صف ارسال به سرور'),
        ),
        body: rows == null
            ? const Center(child: CircularProgressIndicator())
            : rows.isEmpty
                ? const _QueueIsClear()
                : Column(children: [
                    _QueueSummary(rows: rows, busy: _busy, onSendAll: _sendAll),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return SyncQueueItemCard(
                            row: row,
                            enabled: !_busy,
                            onRetry: () =>
                                _act(() => widget.service.retry(row.id)),
                            onDiscard: () => _confirmDiscard(row),
                          );
                        },
                      ),
                    ),
                  ]),
      ),
    );
  }

  Future<void> _sendAll() => _act(widget.service.retryAll);
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({
    required this.rows,
    required this.busy,
    required this.onSendAll,
  });

  final List<LocalRecord> rows;
  final bool busy;
  final Future<void> Function() onSendAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.cloud_upload_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${toPersianDigits(rows.length)} نوشته در انتظار ارسال به سرور است',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy ? null : () => onSendAll(),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.send_rounded, size: 17),
              label:
                  const Text('ارسال دوباره همه', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
}

class SyncQueueItemCard extends StatelessWidget {
  const SyncQueueItemCard({
    required this.row,
    required this.enabled,
    required this.onRetry,
    required this.onDiscard,
    super.key,
  });

  final LocalRecord row;
  final bool enabled;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final failed = row.status == LocalSyncStatus.syncFailed;
    final message = persianSyncErrorMessage(row.lastError);
    final operation = persianMutationLabel(row);
    final name = outboxRecordName(row);
    final title = name.isEmpty ? operation : name;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                failed ? Icons.error_outline_rounded : Icons.schedule_rounded,
                size: 18,
                color: failed ? AsoudColors.danger : AsoudColors.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ]),
            if (name.isNotEmpty) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Text(
                  operation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: AsoudColors.muted),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Text(
                formatJalaliDateTimeIso(row.createdAt.toIso8601String()),
                style: const TextStyle(fontSize: 10, color: AsoudColors.muted),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Text(
                failed
                    ? 'ناموفق: ${message.isEmpty ? 'خطای نامشخص سرور' : message}'
                    : 'در انتظار اتصال',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: failed ? AsoudColors.danger : AsoudColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تلاش‌ها: ${toPersianDigits(row.attempts)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton(
                    onPressed: enabled ? onRetry : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('تلاش دوباره',
                        style: TextStyle(fontSize: 12)),
                  ),
                  OutlinedButton(
                    onPressed: enabled ? onDiscard : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: AsoudColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('حذف از صف',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueIsClear extends StatelessWidget {
  const _QueueIsClear();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFFE8F8EE),
                child: Icon(Icons.check_circle_rounded,
                    size: 34, color: AsoudColors.success),
              ),
              const SizedBox(height: 14),
              const Text('همه داده‌ها ارسال شده',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(
                'هیچ نوشته‌ای روی این گوشی منتظر ارسال به سرور نیست.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AsoudColors.muted),
              ),
            ],
          ),
        ),
      );
}

/// The queue service of the running app, or one of its own when the app shell
/// did not register one. Null when the widget tree has no client to use.
OfflineSyncService? syncServiceOf(BuildContext context) =>
    _provided<OfflineSyncService>(context) ??
    (() {
      final client = _provided<FrappeApiClient>(context);
      return client == null ? null : OfflineSyncService(client);
    })();

/// Opens «صف ارسال به سرور».
void openSyncQueue(BuildContext context, OfflineSyncService service) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SyncQueuePage(service: service)));

T? _provided<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

const _mutationLabels = <String, String>{
  'save_office': 'ذخیره دفتر کار',
  'set_default_office': 'انتخاب دفتر پیش‌فرض',
  'update_company_settings': 'ویرایش تنظیمات شرکت',
  'update_account_code_settings': 'ویرایش تنظیمات کد حساب',
  'create_fiscal_year': 'ایجاد سال مالی',
  'create_account': 'ایجاد حساب',
  'update_account': 'ویرایش حساب',
  'delete_account': 'حذف حساب',
  'import_accounts': 'درون‌ریزی سرفصل‌ها',
  'apply_chart_template': 'اعمال قالب سرفصل‌ها',
  'save_detail_group': 'ذخیره گروه تفصیلی',
  'disable_detail_group': 'غیرفعال‌سازی گروه تفصیلی',
  'seed_default_detail_groups': 'ایجاد گروه‌های تفصیلی پیش‌فرض',
  'create_floating_detail': 'ایجاد تفصیلی شناور',
  'link_floating_detail': 'اتصال تفصیلی به گروه',
  'save_party': 'ذخیره طرف حساب',
  'disable_party': 'غیرفعال‌سازی طرف حساب',
  'create_purchase_request': 'ثبت درخواست خرید',
  'save_voucher': 'ثبت سند',
  'submit_for_approval': 'ارسال سند برای تأیید',
  'approve_voucher': 'تأیید سند',
  'reject_voucher': 'رد سند',
  'create_workflow_draft': 'ایجاد پیش‌نویس گردش کار',
  'add_workflow_stage': 'افزودن مرحله گردش کار',
  'add_condition_branch': 'افزودن شاخه شرط',
  'connect_workflow_stages': 'اتصال مراحل گردش کار',
  'insert_workflow_stage': 'درج مرحله گردش کار',
  'save_stage_routes': 'ذخیره مسیرهای مرحله',
  'save_stage_settings': 'ذخیره تنظیمات مرحله',
  'save_start_settings': 'ذخیره تنظیمات شروع',
  'update_stage_positions': 'جابه‌جایی مراحل',
  'set_workflow_status': 'تغییر وضعیت گردش کار',
  'update_request_type_info': 'ویرایش اطلاعات نوع درخواست',
  'complete_workflow_task': 'تکمیل کار کارتابل',
  'save_workflow_task_draft': 'ذخیره پیش‌نویس کار کارتابل',
  'upload_workflow_attachment': 'بارگذاری پیوست کارتابل',
  'mark_workflow_notification_read': 'خواندن اعلان گردش کار',
  'send_employee_invitation': 'ارسال دعوت‌نامه کارمند',
  'delete_employee_access': 'حذف دسترسی کارمند',
  'sync_employee_access': 'همگام‌سازی دسترسی کارمند',
};

/// The Persian name of a queued operation, falling back to the method name so an
/// unknown write is still identifiable.
String persianMutationLabel(LocalRecord row) {
  final operation = row.payload['operation']?.toString() ?? '';
  if (operation == 'create_resource' || operation == 'update_resource') {
    final doctype = row.entityType.split('/').first;
    return operation == 'create_resource'
        ? 'ایجاد $doctype'
        : 'ویرایش $doctype';
  }
  return _mutationLabels[row.entityType.split('.').last] ?? row.entityType;
}

/// Payload keys, most specific first, that hold what the user actually wrote
/// (a subject, a party/company name, an account or a document number).
const _recordNameKeys = <String>[
  'subject',
  'title',
  'display_name',
  'customer_name',
  'supplier_name',
  'full_name',
  'company_name',
  'company',
  'account_name',
  'party_name',
  'employee_name',
  'item_name',
  'group_name',
  'request_id',
  'name',
];

/// The document or request name of a queued row, so the queue shows what the
/// user wrote instead of only the technical operation; empty when the payload
/// carries no such value.
String outboxRecordName(LocalRecord row) {
  for (final key in _recordNameKeys) {
    final value = row.payload[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}
