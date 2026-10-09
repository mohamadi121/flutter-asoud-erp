import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../request_types/domain/request_type_catalog.dart';
import '../../data/generic_request_repository.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../widgets/request_detail_scaffold.dart';
import '../widgets/request_print.dart';
import '../request_screen_registry.dart';
import '../widgets/request_status.dart';

export '../widgets/request_detail_scaffold.dart' show RequestPrintPage;
export '../widgets/request_status.dart'
    show requestStatus, RequestStatusChip, RequestNativeChip;

/// «انتخاب نوع درخواست»: a sheet listing the request types the user may submit.
Future<Map<String, dynamic>?> pickRequestType(
        BuildContext context, GenericRequestRepository repository) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .75),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: repository.options(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('دریافت انواع درخواست ممکن نشد.',
                        textAlign: TextAlign.center));
              }
              if (!snapshot.hasData) {
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()));
              }
              // The system templates (`template_key`) come first.
              final rows = [
                ...snapshot.data!
                    .where((row) => '${row['template_key'] ?? ''}'.isNotEmpty),
                ...snapshot.data!
                    .where((row) => '${row['template_key'] ?? ''}'.isEmpty),
              ];
              return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    const Text('نوع درخواست را انتخاب کنید',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      const Text('نوع درخواستی برای این دفتر تعریف نشده است.',
                          textAlign: TextAlign.center),
                    for (final row in rows)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: AsoudIconBox(
                              icon: requestIconFor('${row['icon_key']}').icon,
                              color: requestIconFor('${row['icon_key']}').color,
                              size: 42),
                          title: Text('${row['workflow_title']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                              '${row['short_title'] ?? row['process_description'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_left_rounded),
                          onTap: () => Navigator.pop(context, row),
                        ),
                      ),
                  ]);
            },
          ),
        ),
      ),
    );

/// «درخواست شما با موفقیت ثبت شد» with the request summary.
class RequestSubmittedPage extends StatelessWidget {
  const RequestSubmittedPage({
    required this.request,
    required this.repository,
    required this.typeTitle,
    super.key,
  });

  /// The server's request, or the local payload while it waits to sync.
  final Map<String, dynamic> request;
  final GenericRequestRepository repository;
  final String typeTitle;

  bool get pending => request['pending_sync'] == true;

  /// Saved in the offline preview: kept on this device, never sent.
  bool get local => request['local_preview'] == true;

  @override
  Widget build(BuildContext context) {
    final values = Map<String, dynamic>.from(request['values'] as Map? ?? {});
    final number = local
        ? '${request['local_number'] ?? ''}'
        : pending
            ? '—'
            : '${request['name']}';
    final rows = {
      'شماره درخواست': number,
      'عنوان': '${request['subject'] ?? ''}',
      'نوع درخواست': typeTitle,
      'تعداد اقلام': '${toPersianDigits(requestItemRows(values).length)} قلم',
      'تاریخ ثبت': formatJalaliDateTimeIso(
          '${request['creation'] ?? DateTime.now().toIso8601String()}'),
    };
    void details() {
      final detail =
          RequestScreenRegistry.of('${request['template_key'] ?? ''}')?.detail;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
              builder: (context) => detail != null
                  ? detail(context, repository, '${request['name']}')
                  : RequestDetailPage(
                      name: '${request['name']}', repository: repository)));
    }

    return Scaffold(
      appBar: AsoudHeader(title: typeTitle),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                    color: AsoudColors.success.withValues(alpha: .12),
                    shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: AsoudColors.success, size: 52),
              ),
              const SizedBox(height: 16),
              Text(
                  pending
                      ? 'درخواست شما روی گوشی ذخیره شد'
                      : 'درخواست شما با موفقیت ثبت شد',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                  local
                      ? 'این درخواست با شماره $number فقط روی گوشی (پیش‌نمایش آفلاین) ذخیره شد و به سرور ارسال نمی‌شود.'
                      : pending
                          ? 'پس از اتصال به سرور ارسال و برای بررسی به مدیر مرتبط فرستاده می‌شود.'
                          : '$typeTitle با شماره $number ثبت و برای بررسی به مدیر مرتبط ارسال شد.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, height: 1.7, color: AsoudColors.muted)),
              const SizedBox(height: 18),
              if (!pending || local)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: details,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('مشاهده جزئیات درخواست'),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.home_outlined),
                label: const Text('بازگشت به صفحه اصلی'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              const Row(children: [
                Expanded(
                    child: Text('خلاصه درخواست',
                        style: TextStyle(fontWeight: FontWeight.w900))),
                Icon(Icons.receipt_long_outlined, color: AsoudColors.primary),
              ]),
              const SizedBox(height: 8),
              for (final entry in rows.entries)
                _InfoRow(entry.key, entry.value),
              _InfoRowWidget('وضعیت', RequestStatusChip(request)),
              if (!pending || local)
                TextButton.icon(
                    onPressed: details,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('مشاهده جزئیات کامل')),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => _InfoRowWidget(
      label,
      Text(value.isEmpty ? '—' : value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)));
}

class _InfoRowWidget extends StatelessWidget {
  const _InfoRowWidget(this.label, this.value);
  final String label;
  final Widget value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 104,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: AsoudColors.muted))),
          Expanded(
              child: Align(
                  alignment: AlignmentDirectional.centerEnd, child: value)),
        ]),
      );
}

/// «جزئیات درخواست» of a custom request type; templates register their own
/// page in `RequestScreenRegistry`. Built on [RequestDetailScaffold].
class RequestDetailPage extends StatelessWidget {
  const RequestDetailPage(
      {required this.name, required this.repository, this.tasks, super.key});
  final String name;
  final GenericRequestRepository repository;
  final WorkflowTaskRepository? tasks;

  @override
  Widget build(BuildContext context) =>
      RequestDetailScaffold(repository: repository, name: name, tasks: tasks);
}
