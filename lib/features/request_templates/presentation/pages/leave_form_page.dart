import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../workflows/data/generic_request_repository.dart';
import '../../../workflows/data/offline_preview_data.dart'
    show offlinePreviewLeave;
import '../../../workflows/domain/entities/request_models.dart';
import '../../../workflows/presentation/widgets/request_field_widgets.dart';
import '../../../workflows/presentation/widgets/request_form_controller.dart';
import '../widgets/leave_widgets.dart';
import '../widgets/template_form_session.dart';
import 'request_form_pages.dart';

/// The `previewLeave` arguments of the current form values, or null while the
/// input is incomplete.
Map<String, dynamic>? leavePreviewArgs(RequestFormController form) {
  String? text(String key) {
    final value = form.value(key);
    return value is String && value.isNotEmpty ? value : null;
  }

  final type = text('leave_type');
  final kind = text('request_kind') ?? 'Daily';
  if (type == null) return null;
  if (kind == 'Hourly') {
    final date = text('leave_date'),
        start = text('start_time'),
        end = text('end_time');
    if (date == null || start == null || end == null) return null;
    return {
      'leave_type': type,
      'request_kind': kind,
      'leave_date': date,
      'start_time': start,
      'end_time': end,
    };
  }
  final start = text('start_date'), end = text('end_date');
  if (start == null || end == null) return null;
  return {
    'leave_type': type,
    'request_kind': 'Daily',
    'start_date': start,
    'end_date': end,
  };
}

/// «درخواست مرخصی»: the روزانه / ساعتی switch, the date block or the time
/// block, a live duration («۳ روز» / «۴ ساعت») from `previewLeave`
/// (debounced 400 ms, local rules offline), the leave type, reason,
/// attachments and the balance panel «اطلاعات باقی‌مانده مرخصی».
class LeaveRequestFormPage extends StatefulWidget {
  const LeaveRequestFormPage({
    required this.repository,
    required this.type,
    this.existing,
    this.filePicker,
    this.previewDebounce = const Duration(milliseconds: 400),
    super.key,
  });

  final GenericRequestRepository repository;
  final Map<String, dynamic> type;
  final Map<String, dynamic>? existing;
  final RequestFilePicker? filePicker;
  final Duration previewDebounce;

  @override
  State<LeaveRequestFormPage> createState() => _LeaveRequestFormPageState();
}

class _LeaveRequestFormPageState extends State<LeaveRequestFormPage> {
  late final session = TemplateFormSession(
      repository: widget.repository,
      type: widget.type,
      existing: widget.existing,
      filePicker: widget.filePicker);
  RequestFormController get form => session.form;

  LeaveBalance? balance;
  bool balanceLoading = true;
  LeavePreview? preview;
  bool previewLoading = false;
  Timer? _debounce;
  String? _lastArgs;
  int _token = 0;
  final Set<String> _previewKeys = {};

  @override
  void initState() {
    super.initState();
    form.addListener(_onForm);
    _loadBalance();
    _onForm();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    form.removeListener(_onForm);
    session.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final value = await widget.repository.leaveBalance();
      if (mounted) setState(() => balance = value);
    } catch (_) {
      // The panel shows «مانده مرخصی در دسترس نیست.».
    } finally {
      if (mounted) setState(() => balanceLoading = false);
    }
  }

  void _onForm() {
    final args = leavePreviewArgs(form);
    final key = args?.toString();
    if (key == _lastArgs) return;
    _lastArgs = key;
    _debounce?.cancel();
    _token++;
    if (args == null) {
      _applyPreview(null);
      return;
    }
    final token = _token;
    setState(() => previewLoading = true);
    _debounce = Timer(widget.previewDebounce, () => _runPreview(args, token));
  }

  Future<void> _runPreview(Map<String, dynamic> args, int token) async {
    LeavePreview? result;
    try {
      result = await widget.repository.previewLeave(args);
    } catch (error) {
      if (widget.repository.offline(error)) {
        // No connection and nothing cached: the local rules of the preview.
        final local = Map<String, dynamic>.from(offlinePreviewLeave(args))
          ..remove('balance');
        result = LeavePreview.fromMap(local);
      }
    }
    if (!mounted || token != _token) return;
    _applyPreview(result);
  }

  void _applyPreview(LeavePreview? value) {
    for (final key in _previewKeys) {
      form.setExternalError(key, null);
    }
    _previewKeys.clear();
    if (value != null) {
      for (final error in value.errors) {
        final key =
            form.field(error.field) != null && form.isVisible(error.field)
                ? error.field
                : 'leave_type';
        form.setExternalError(key, error.message);
        _previewKeys.add(key);
      }
    }
    form.setAutoText('duration', value?.duration.label);
    setState(() {
      preview = value;
      previewLoading = false;
    });
  }

  bool get canSubmit => !previewLoading && (preview == null || preview!.valid);

  Future<void> _submit() async {
    final outcome = await session.submit();
    if (outcome != null && mounted) {
      finishTemplateSubmit(context, session, outcome);
    }
  }

  Widget _durationRow() => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('مدت مرخصی',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          LeaveDurationBadge(
              duration:
                  preview?.duration.isEmpty == false ? preview!.duration : null,
              loading: previewLoading),
          if (preview != null && !preview!.valid)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(preview!.firstMessage ?? 'درخواست مرخصی معتبر نیست.',
                  key: const ValueKey('leave-preview-error'),
                  style: const TextStyle(
                      fontSize: 11, color: AsoudColors.danger, height: 1.6)),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final leaveTypeValue = form.value('leave_type');
          final category = leaveTypeValue is String
              ? balance?.leaveType(leaveTypeValue)?.category
              : null;
          final orgUnitMissing =
              !((form.value('org_unit') as String?)?.isNotEmpty ?? false);
          return AsoudFormPage(
            title: session.editing ? 'ویرایش درخواست مرخصی' : 'درخواست مرخصی',
            subtitle: 'ثبت درخواست مرخصی سالانه، استعلاجی و ...',
            formKey: session.formKey,
            saving: session.saving,
            error: session.error,
            canSave: canSubmit,
            onSave: _submit,
            saveLabel: session.editing ? 'ذخیره تغییرات' : 'ثبت درخواست',
            children: [
              RequestFormCard(
                  title: 'اطلاعات اصلی',
                  icon: Icons.description_outlined,
                  children: [
                    // The requester is the signed-in user; the unit is shown
                    // only when the profile has none to fill in.
                    if (orgUnitMissing)
                      templateField(session, 'org_unit', unified: true),
                    templateField(session, 'leave_type', unified: true),
                    templateField(session, 'request_kind', unified: true),
                    templateField(session, 'start_date', unified: true),
                    templateField(session, 'end_date', unified: true),
                    templateField(session, 'leave_date', unified: true),
                    templateField(session, 'start_time', unified: true),
                    templateField(session, 'end_time', unified: true),
                    _durationRow(),
                    templateField(session, 'location', unified: true),
                    templateField(session, 'reason', unified: true),
                  ]),
              templateAttachmentsCard(session, title: 'پیوست‌ها (اختیاری)'),
              LeaveBalancePanel(
                balance: balance,
                loading: balanceLoading,
                highlightCategory: category,
                remainingAfter: preview?.balance?.remainingAfter,
              ),
            ],
          );
        },
      );
}
