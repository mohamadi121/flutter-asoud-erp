import 'package:flutter/material.dart';

import '../../../../core/widgets/asoud_form.dart';
import '../../../workflows/data/generic_request_repository.dart';
import '../../../workflows/presentation/pages/request_flow_pages.dart';
import '../../../workflows/presentation/widgets/request_attachments.dart';
import '../../../workflows/presentation/widgets/request_field_widgets.dart';
import '../../../workflows/presentation/widgets/request_form_controller.dart';
import '../widgets/template_form_session.dart';

/// The field [key] of the template as a form widget, or nothing when the type
/// has no such field (a server that changed the template).
Widget templateField(TemplateFormSession session, String key) {
  final field = session.form.field(key);
  if (field == null) return const SizedBox.shrink();
  return RequestFieldWidget(
      controller: session.form, field: field, enabled: !session.saving);
}

/// The «عنوان درخواست» input of templates whose subject is typed by the user.
Widget templateSubjectField(TemplateFormSession session) {
  final form = session.form;
  if (form.subjectMode != 'input') return const SizedBox.shrink();
  return ListenableBuilder(
    listenable: form,
    builder: (context, _) => AsoudFormField(
      key: const ValueKey('template-subject'),
      controller: form.subject,
      label: '${form.subjectLabel} *',
      enabled: !session.saving,
      errorText: form.subjectError,
    ),
  );
}

/// «پیوست‌ها» card with the drop zone.
Widget templateAttachmentsCard(TemplateFormSession session,
        {String title = 'پیوست‌ها'}) =>
    ListenableBuilder(
      listenable: session,
      builder: (context, _) => RequestFormCard(
          title: title,
          icon: Icons.attach_file_rounded,
          children: [
            RequestAttachmentsPicker(
                controller: session.form, enabled: !session.saving),
          ]),
    );

/// Leaves the form after [outcome]: the «ثبت شد» page for a new request, or
/// back to the detail after an edit. Both complete the form route with true so
/// the callers reload.
void finishTemplateSubmit(BuildContext context, TemplateFormSession session,
    TemplateSubmitOutcome outcome) {
  if (outcome.edited) {
    if (outcome.queuedMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(outcome.queuedMessage!)));
    }
    Navigator.pop(context, true);
    return;
  }
  Navigator.pushReplacement(
      context,
      MaterialPageRoute<bool>(
          builder: (_) => RequestSubmittedPage(
              request: outcome.request ??
                  {
                    ...outcome.payload,
                    'name': '',
                    'pending_sync': true,
                  },
              repository: session.repository,
              typeTitle: session.typeTitle)),
      result: true);
}

typedef TemplateFormLayout = List<Widget> Function(
    BuildContext context, TemplateFormSession session);

/// A template form made of the sections [layout] returns. It owns the
/// [TemplateFormSession] and the submit flow.
class TemplateRequestFormPage extends StatefulWidget {
  const TemplateRequestFormPage({
    required this.repository,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.layout,
    this.existing,
    this.rules = const [],
    this.filePicker,
    super.key,
  });

  final GenericRequestRepository repository;
  final Map<String, dynamic> type;
  final Map<String, dynamic>? existing;
  final String title, subtitle;
  final TemplateFormLayout layout;
  final List<TemplateFormRule> rules;
  final RequestFilePicker? filePicker;

  @override
  State<TemplateRequestFormPage> createState() =>
      _TemplateRequestFormPageState();
}

class _TemplateRequestFormPageState extends State<TemplateRequestFormPage> {
  late final session = TemplateFormSession(
      repository: widget.repository,
      type: widget.type,
      existing: widget.existing,
      filePicker: widget.filePicker,
      rules: widget.rules);

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await session.submit();
    if (outcome != null && mounted) {
      finishTemplateSubmit(context, session, outcome);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) => AsoudFormPage(
          title: widget.title,
          subtitle: widget.subtitle,
          formKey: session.formKey,
          saving: session.saving,
          error: session.error,
          onSave: _submit,
          saveLabel: session.editing ? 'ذخیره تغییرات' : 'ثبت درخواست',
          children: widget.layout(context, session),
        ),
      );
}

/// «درخواست خرید»: header card, items card, attachments card (mockup 1).
class PurchaseRequestFormPage extends StatelessWidget {
  const PurchaseRequestFormPage({
    required this.repository,
    required this.type,
    this.existing,
    this.filePicker,
    super.key,
  });
  final GenericRequestRepository repository;
  final Map<String, dynamic> type;
  final Map<String, dynamic>? existing;
  final RequestFilePicker? filePicker;

  static List<Widget> layout(BuildContext context, TemplateFormSession s) => [
        RequestFormCard(
            title: 'اطلاعات اصلی',
            icon: Icons.description_outlined,
            children: [
              templateSubjectField(s),
              for (final key in const [
                'requester',
                'org_unit',
                'cost_center',
                'project',
                'needed_date',
                'priority',
                'reason',
              ])
                templateField(s, key),
            ]),
        RequestFormCard(
            title: 'اقلام درخواست',
            icon: Icons.inventory_2_outlined,
            children: [templateField(s, 'items')]),
        templateAttachmentsCard(s),
      ];

  @override
  Widget build(BuildContext context) => TemplateRequestFormPage(
        repository: repository,
        type: type,
        existing: existing,
        filePicker: filePicker,
        title: existing == null ? 'درخواست خرید' : 'ویرایش درخواست خرید',
        subtitle: 'ثبت درخواست خرید کالا',
        layout: layout,
      );
}

const supplyTransferNeedsWarehouse =
    'برای انتقال از انبار، محل تحویل باید یک انبار باشد.';

/// Supply rule (CONTRACT §3.5 `DELIVERY_NOT_WAREHOUSE`): a `Transfer` needs a
/// warehouse as the delivery location.
Map<String, String> supplyTransferRule(RequestFormController form) {
  final location = form.value('delivery_location');
  if (form.value('supply_method') == 'Transfer' &&
      location is String &&
      location.isNotEmpty &&
      !location.startsWith('warehouse:')) {
    return {'delivery_location': supplyTransferNeedsWarehouse};
  }
  return const {};
}

const supplyNonStockItemMessage =
    'اقلام خدماتی را نمی‌توان از انبار تأمین یا منتقل کرد.';

/// Supply rule (CONTRACT §3.5 `ITEM_NOT_STOCKABLE`): `Warehouse` and `Transfer`
/// reject a non-stock item. The rows picked in this form carry the option's
/// `is_stock_item`; rows without the flag (an edit of a stored request) are
/// left to the server, which enforces the same rule.
Map<String, String> supplyStockRule(RequestFormController form) {
  final method = form.value('supply_method');
  if (method != 'Warehouse' && method != 'Transfer') return const {};
  final rows = form.value('items');
  if (rows is! List) return const {};
  final bad = rows.any((row) {
    if (row is! Map || !row.containsKey('is_stock_item')) return false;
    final flag = row['is_stock_item'];
    return flag == 0 || flag == false || flag == '0';
  });
  return bad ? {'items': supplyNonStockItemMessage} : const {};
}

/// «درخواست تأمین کالا / خدمت»: header card, items, supplier, notes,
/// attachments (mockup 2).
class SupplyRequestFormPage extends StatelessWidget {
  const SupplyRequestFormPage({
    required this.repository,
    required this.type,
    this.existing,
    this.filePicker,
    super.key,
  });
  final GenericRequestRepository repository;
  final Map<String, dynamic> type;
  final Map<String, dynamic>? existing;
  final RequestFilePicker? filePicker;

  static List<Widget> layout(BuildContext context, TemplateFormSession s) => [
        RequestFormCard(
            title: 'اطلاعات اصلی',
            icon: Icons.description_outlined,
            children: [
              templateSubjectField(s),
              for (final key in const [
                'requester',
                'org_unit',
                'delivery_location',
                'needed_date',
                'supply_method',
                'priority',
              ])
                templateField(s, key),
            ]),
        RequestFormCard(
            title: 'اقلام / خدمات',
            icon: Icons.inventory_2_outlined,
            children: [templateField(s, 'items')]),
        RequestFormCard(
            title: 'تأمین‌کننده پیشنهادی',
            icon: Icons.groups_outlined,
            children: [templateField(s, 'suggested_supplier')]),
        RequestFormCard(
            title: 'شرایط و توضیحات',
            icon: Icons.notes_rounded,
            children: [templateField(s, 'reason')]),
        templateAttachmentsCard(s),
      ];

  @override
  Widget build(BuildContext context) => TemplateRequestFormPage(
        repository: repository,
        type: type,
        existing: existing,
        filePicker: filePicker,
        rules: const [supplyTransferRule, supplyStockRule],
        title: existing == null
            ? 'درخواست تأمین کالا / خدمت'
            : 'ویرایش درخواست تأمین',
        subtitle: 'ثبت درخواست تأمین کالا / خدمت مورد نیاز سازمان',
        layout: layout,
      );
}
