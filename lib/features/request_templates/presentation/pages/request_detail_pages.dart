import 'package:flutter/material.dart';

import '../../../../core/utils/jalali_date.dart';
import '../../../workflows/data/generic_request_repository.dart';
import '../../../workflows/domain/entities/request_models.dart';
import '../../../workflows/domain/repositories/workflow_task_repository.dart';
import '../../../workflows/presentation/widgets/request_detail_scaffold.dart';
import '../widgets/detail_info_card.dart';

String _date(Object? value) =>
    value is String && value.isNotEmpty ? formatJalaliIso(value) : '';

String _clock(Object? value) =>
    value is String && value.isNotEmpty ? toPersianDigits(value) : '';

String _text(Object? value) => value is String ? value : '';

/// Info rows of the purchase detail (mockup «اطلاعات اصلی»).
List<InfoRowData> purchaseInfoRows(
    RequestDetailView view, Map<String, String> labels) {
  final detail = view.detail, values = detail.values;
  String label(String key) => labels[key] ?? _text(values[key]);
  return [
    InfoRowData(
        Icons.person_outline_rounded, 'درخواست‌کننده', detail.requesterName),
    InfoRowData(Icons.apartment_rounded, 'واحد سازمانی', label('org_unit')),
    InfoRowData(Icons.inventory_2_outlined, 'مرکز هزینه', label('cost_center')),
    InfoRowData(Icons.folder_outlined, 'پروژه', label('project')),
    InfoRowData(Icons.calendar_today_outlined, 'تاریخ مورد نیاز',
        _date(values['needed_date'])),
    InfoRowData(Icons.flag_outlined, 'اولویت', '',
        widget: PriorityChip(_text(values['priority']))),
    InfoRowData(Icons.notes_rounded, 'دلیل درخواست', _text(values['reason'])),
  ];
}

/// Info rows of the supply detail.
List<InfoRowData> supplyInfoRows(
    RequestDetailView view, Map<String, String> labels) {
  final detail = view.detail, values = detail.values;
  String label(String key) => labels[key] ?? _text(values[key]);
  return [
    InfoRowData(
        Icons.person_outline_rounded, 'درخواست‌کننده', detail.requesterName),
    InfoRowData(Icons.apartment_rounded, 'واحد سازمانی', label('org_unit')),
    InfoRowData(
        Icons.location_on_outlined, 'محل تحویل', label('delivery_location')),
    InfoRowData(Icons.flag_outlined, 'روش تأمین پیشنهادی',
        view.format('supply_method', values['supply_method'])),
    InfoRowData(Icons.groups_outlined, 'تأمین‌کننده پیشنهادی',
        label('suggested_supplier')),
    InfoRowData(Icons.calendar_today_outlined, 'تاریخ مورد نیاز',
        _date(values['needed_date'])),
    InfoRowData(Icons.flag_outlined, 'اولویت', '',
        widget: PriorityChip(_text(values['priority']))),
    InfoRowData(Icons.notes_rounded, 'توضیحات', _text(values['reason'])),
  ];
}

/// Info rows of the leave detail: the daily variant shows the date range, the
/// hourly one the date and the times.
List<InfoRowData> leaveInfoRows(
    RequestDetailView view, Map<String, String> labels) {
  final detail = view.detail, values = detail.values;
  String label(String key) => labels[key] ?? _text(values[key]);
  final hourly = values['request_kind'] == 'Hourly';
  final duration = LeaveDuration.fromMap(values['duration']).label;
  return [
    InfoRowData(
        Icons.person_outline_rounded, 'درخواست‌کننده', detail.requesterName),
    InfoRowData(Icons.apartment_rounded, 'واحد سازمانی', label('org_unit')),
    InfoRowData(Icons.inventory_2_outlined, 'نوع مرخصی', label('leave_type')),
    InfoRowData(Icons.swap_horiz_rounded, 'نوع درخواست',
        view.format('request_kind', values['request_kind'])),
    if (hourly) ...[
      InfoRowData(Icons.calendar_today_outlined, 'تاریخ مرخصی',
          _date(values['leave_date'])),
      InfoRowData(
          Icons.schedule_rounded, 'ساعت شروع', _clock(values['start_time'])),
      InfoRowData(
          Icons.schedule_rounded, 'ساعت پایان', _clock(values['end_time'])),
    ] else ...[
      InfoRowData(Icons.calendar_today_outlined, 'تاریخ شروع',
          _date(values['start_date'])),
      InfoRowData(Icons.calendar_today_outlined, 'تاریخ پایان',
          _date(values['end_date'])),
    ],
    InfoRowData(Icons.timelapse_rounded, 'مدت مرخصی', duration),
    InfoRowData(Icons.location_on_outlined, 'محل خدمت', label('location')),
    InfoRowData(Icons.notes_rounded, 'دلیل مرخصی', _text(values['reason'])),
  ];
}

const _purchaseLinks = {
  'org_unit': 'Department',
  'cost_center': 'Cost Center',
  'project': 'Project',
};
const _supplyLinks = {
  'org_unit': 'Department',
  'delivery_location': 'Delivery Location',
  'suggested_supplier': 'Supplier',
};
const _leaveLinks = {
  'org_unit': 'Department',
  'leave_type': 'Leave Type',
  'location': 'Branch',
};

class _TemplateDetailPage extends StatelessWidget {
  const _TemplateDetailPage({
    required this.repository,
    required this.name,
    required this.title,
    required this.cardTitle,
    required this.links,
    required this.rows,
    this.tasks,
  });

  final GenericRequestRepository repository;
  final String name, title, cardTitle;
  final WorkflowTaskRepository? tasks;
  final Map<String, String> links;
  final List<InfoRowData> Function(
      RequestDetailView view, Map<String, String> labels) rows;

  @override
  Widget build(BuildContext context) => RequestDetailScaffold(
        repository: repository,
        name: name,
        title: title,
        tasks: tasks,
        infoBuilder: (context, view) => ResolvedInfoCard(
          key: ValueKey('info-${view.detail.name}'),
          repository: repository,
          view: view,
          title: cardTitle,
          fieldTypes: links,
          rows: (labels) => rows(view, labels),
        ),
      );
}

/// «جزئیات درخواست خرید»: the shared detail scaffold with the purchase info
/// card (mockup 1).
class PurchaseRequestDetailPage extends StatelessWidget {
  const PurchaseRequestDetailPage(
      {required this.repository, required this.name, this.tasks, super.key});
  final GenericRequestRepository repository;
  final String name;
  final WorkflowTaskRepository? tasks;

  @override
  Widget build(BuildContext context) => _TemplateDetailPage(
      repository: repository,
      name: name,
      tasks: tasks,
      title: 'جزئیات درخواست خرید',
      cardTitle: 'اطلاعات اصلی',
      links: _purchaseLinks,
      rows: purchaseInfoRows);
}

/// «جزئیات درخواست تأمین»: like the purchase detail; the shared bar shows the
/// visible «انصراف درخواست» button while the request can be cancelled.
class SupplyRequestDetailPage extends StatelessWidget {
  const SupplyRequestDetailPage(
      {required this.repository, required this.name, this.tasks, super.key});
  final GenericRequestRepository repository;
  final String name;
  final WorkflowTaskRepository? tasks;

  @override
  Widget build(BuildContext context) => _TemplateDetailPage(
      repository: repository,
      name: name,
      tasks: tasks,
      title: 'جزئیات درخواست تأمین',
      cardTitle: 'اطلاعات اصلی',
      links: _supplyLinks,
      rows: supplyInfoRows);
}

/// «جزئیات درخواست مرخصی» (daily and hourly variants).
class LeaveRequestDetailPage extends StatelessWidget {
  const LeaveRequestDetailPage(
      {required this.repository, required this.name, this.tasks, super.key});
  final GenericRequestRepository repository;
  final String name;
  final WorkflowTaskRepository? tasks;

  @override
  Widget build(BuildContext context) => _TemplateDetailPage(
      repository: repository,
      name: name,
      tasks: tasks,
      title: 'جزئیات درخواست مرخصی',
      cardTitle: 'اطلاعات درخواست',
      links: _leaveLinks,
      rows: leaveInfoRows);
}
