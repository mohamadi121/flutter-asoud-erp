import 'package:flutter/widgets.dart';

import '../../../../core/offline/queued_offline_exception.dart';
import '../../../workflows/data/generic_request_repository.dart';
import '../../../workflows/presentation/widgets/request_form_controller.dart';
import '../../../workflows/presentation/widgets/request_status.dart';

/// Extra form rules of a template: maps a field key to the error to show.
typedef TemplateFormRule = Map<String, String> Function(
    RequestFormController form);

/// What a successful [TemplateFormSession.submit] produced.
class TemplateSubmitOutcome {
  const TemplateSubmitOutcome(
      {required this.edited,
      this.payload = const {},
      this.request,
      this.queuedMessage});

  /// True after an edit, false after a create.
  final bool edited;

  /// The `create_request` arguments that were sent (create only).
  final Map<String, dynamic> payload;

  /// The server's request (or the local preview row), null while the create
  /// waits in the outbox and after an edit.
  final Map<String, dynamic>? request;

  /// Set when an edit was queued offline («ذخیره شد؛ پس از اتصال ارسال می‌شود»).
  final String? queuedMessage;
}

/// Everything a template form page shares: the [form] controller, the request
/// id, saving/error state and the create or update call. The pages only lay the
/// fields out.
class TemplateFormSession extends ChangeNotifier {
  TemplateFormSession({
    required this.repository,
    required this.type,
    this.existing,
    RequestFilePicker? filePicker,
    this.rules = const [],
  }) : form = RequestFormController.fromType(type,
            existing: existing,
            loadOptions: RequestFormController.loaderFor(repository),
            filePicker: filePicker,
            showRequiredMarks: true) {
    form.addListener(_applyRules);
    _applyRules();
  }

  final GenericRequestRepository repository;
  final Map<String, dynamic> type;
  final Map<String, dynamic>? existing;
  final RequestFormController form;
  final List<TemplateFormRule> rules;
  final String requestId = GenericRequestRepository.requestId();

  /// Key of the `Form` that [AsoudFormPage] wraps the sections in. The
  /// sections validate through [form], so nothing reads this state.
  final formKey = GlobalKey<FormState>();
  bool saving = false;
  String? error;
  final Set<String> _ruleKeys = {};
  bool _applying = false;

  bool get editing => existing != null;
  String get templateKey => '${type['template_key'] ?? ''}';
  String get typeTitle => '${type['workflow_title'] ?? ''}';

  void _applyRules() {
    if (_applying) return;
    _applying = true;
    try {
      final next = <String, String>{};
      for (final rule in rules) {
        next.addAll(rule(form));
      }
      for (final key in {..._ruleKeys}) {
        if (!next.containsKey(key)) {
          form.setExternalError(key, null);
          _ruleKeys.remove(key);
        }
      }
      for (final entry in next.entries) {
        if (form.errorFor(entry.key) != entry.value) {
          form.setExternalError(entry.key, entry.value);
        }
        _ruleKeys.add(entry.key);
      }
    } finally {
      _applying = false;
    }
  }

  /// The exact `create_request` arguments (CONTRACT §4.3): `template_key`,
  /// `subject` only when the user types it, `values` and `attachments`.
  Map<String, dynamic> buildPayload() => {
        'template_key': templateKey,
        if (form.subjectMode == 'input') 'subject': form.subject.text.trim(),
        'values': form.payloadValues(),
        'attachments': form.attachmentUploads(),
      };

  void setError(String? message) {
    error = message;
    notifyListeners();
  }

  /// Validates, then creates (or updates) the request. Returns null when the
  /// form is invalid or the call failed (then [error] says why).
  Future<TemplateSubmitOutcome?> submit() async {
    if (saving) return null;
    _applyRules();
    if (!form.validate() || form.hasExternalErrors) {
      error = 'لطفاً خطاهای فرم را برطرف کنید.';
      notifyListeners();
      return null;
    }
    saving = true;
    error = null;
    notifyListeners();
    try {
      if (editing) {
        final uploads = form.attachmentUploads();
        final removed = form.removedAttachmentNames;
        final text =
            form.subjectMode == 'input' ? form.subject.text.trim() : '';
        await repository.update(
            '${existing!['name']}', text, form.payloadValues(),
            attachments: uploads.isEmpty ? null : uploads,
            removeAttachments: removed.isEmpty ? null : removed);
        return const TemplateSubmitOutcome(edited: true);
      }
      final payload = buildPayload();
      final result = await repository.create(payload, requestId);
      return TemplateSubmitOutcome(
          edited: false, payload: payload, request: result);
    } on QueuedOfflineException catch (e) {
      return TemplateSubmitOutcome(edited: editing, queuedMessage: e.message);
    } catch (e) {
      error = requestErrorMessage(
          e,
          editing
              ? 'ذخیره تغییرات انجام نشد.'
              : 'ثبت انجام نشد؛ اطلاعات فرم حفظ شده است. اتصال و نشست را بررسی کنید.');
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    form.removeListener(_applyRules);
    form.dispose();
    super.dispose();
  }
}
