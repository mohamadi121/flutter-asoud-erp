import 'dart:typed_data';
import 'dart:convert';

import '../../../core/network/frappe_client.dart';
import '../domain/directive_models.dart';

/// Only server-authorized choices/actions may be returned by implementations.
/// Action vocabulary used by the UI: save_draft, issue, report, transfer, close;
/// report-level: approve, request_changes. The wire adapter must map the actual
/// backend vocabulary without manufacturing permissions.
abstract interface class DirectiveRepository {
  Future<DirectiveOptions> options(String company);
  Future<DirectiveDetail> getDirective(String company, String id);
  Future<DirectivePage<DirectiveReport>> reports(String company, String id,
      {String? cursor});
  Future<DirectivePage<DirectiveHistory>> history(String company, String id,
      {String? cursor});
  Future<String> saveDraft(String company, DirectiveDraft draft,
      {required String requestKey});
  Future<String> issue(String company, DirectiveDraft draft,
      {required String requestKey, void Function(String)? onDraftSaved});
  Future<void> report(String company, String id,
      {required DateTime doneDate,
      required String body,
      required List<DirectiveAttachment> attachments,
      required String requestKey});
  Future<void> review(String company, String id, String reportId,
      {required bool approve,
      required String reason,
      required String requestKey});
  Future<void> transfer(String company, String id,
      {required String recipientId,
      required String reason,
      required String requestKey,
      String? executorId});
  Future<void> close(String company, String id, {required String requestKey});
  Future<DirectiveAttachment> uploadAttachment(String company,
      {String? directiveId,
      required String filename,
      required Uint8List bytes,
      required String requestKey});
  Future<DirectiveDownloadedFile> downloadAttachment(
      String company, String attachmentId);
}

/// Real API transport, with no demo fallback and no double-unwrapping of the
/// standard success envelope (FrappeApiClient already does that).
/// Maps the dedicated directives API contract.
class DirectiveApiTransport {
  const DirectiveApiTransport(this.client);
  final FrappeApiClient client;
  static const _methods = {
    'options',
    'list_directives',
    'get_directive',
    'save_draft',
    'issue',
    'report',
    'review',
    'transfer',
    'close',
    'upload_attachment',
    'reports',
    'history',
    'download_attachment'
  };
  Future<dynamic> call(String action, Map<String, dynamic> payload) {
    if (!_methods.contains(action)) throw ArgumentError.value(action, 'action');
    return client.callAsoudMethod('asoud_erp.api.v1.directives.$action',
        data: payload);
  }
}

Map<String, dynamic> directiveMap(dynamic value) =>
    Map<String, dynamic>.from(value as Map);
List<Map<String, dynamic>> directiveRows(dynamic value) =>
    (value as List? ?? []).map(directiveMap).toList();

class ApiDirectiveRepository implements DirectiveRepository {
  ApiDirectiveRepository(this.client);
  final FrappeApiClient client;
  final Map<String, int> _versions = {};
  Future<String> resolveCompany(String company) async {
    if (!client.isAuthenticated) {
      throw StateError('برای دستورات سازمانی به سرور وارد شوید.');
    }
    if (company.isNotEmpty) return company;
    final value = (await client.getCurrentUser()).company;
    if (value == null || value.isEmpty) {
      throw StateError('سازمان فعال مشخص نیست.');
    }
    return value;
  }

  Future<Map<String, dynamic>> _call(String method, String company,
          [Map<String, dynamic> data = const {}]) async =>
      directiveMap(await DirectiveApiTransport(client).call(method, {
        'company': ['options', 'list_directives', 'save_draft'].contains(method)
            ? await resolveCompany(company)
            : company,
        ...data
      }));
  DirectivePerson _person(dynamic raw) {
    final r = directiveMap(raw);
    return DirectivePerson(
        id: r['id'] as String,
        name: r['name'] as String? ?? '',
        department: r['department'] as String? ?? '',
        position: r['position'] as String? ?? '');
  }

  DirectiveAttachment _file(dynamic raw) {
    final r = directiveMap(raw);
    return DirectiveAttachment(
        id: r['id'] as String,
        filename: r['filename'] as String,
        size: (r['size'] as num? ?? 0).toInt(),
        contentType: r['content_type'] as String? ?? '');
  }

  DirectiveFilePolicy? _policy(dynamic raw) {
    if (raw == null) return null;
    final r = directiveMap(raw);
    return DirectiveFilePolicy(
        maxBytes: (r['max_bytes'] as num).toInt(),
        maxCount: (r['max_count'] as num?)?.toInt(),
        extensions: List<String>.from(r['extensions'] as List));
  }

  Set<String> _actions(dynamic value) => Set<String>.from(value as List? ?? []);
  @override
  Future<DirectiveOptions> options(String company) async {
    final r = await _call('options', company);
    return DirectiveOptions(
        people: directiveRows(r['people']).map(_person).toList(),
        priorities: directiveRows(r['priorities'])
            .map((p) =>
                DirectiveChoice(p['value'] as String, p['label'] as String))
            .toList(),
        allowedActions: _actions(r['allowed_actions']),
        today: DateTime.parse(r['today'] as String),
        filePolicy: _policy(r['file_policy']));
  }

  Future<List<Map<String, dynamic>>> list(String company) async {
    final result = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final r =
          await _call('list_directives', company, {'start': cursor ?? '0'});
      result.addAll(directiveRows(r['items']));
      cursor = r['next_cursor'] as String?;
    } while (cursor != null);
    return result;
  }

  @override
  Future<DirectiveDetail> getDirective(String company, String id) async {
    final r = await _call('get_directive', company, {'directive': id});
    _versions[id] = (r['version'] as num? ?? 0).toInt();
    return DirectiveDetail(
        id: id,
        company: r['company'] as String,
        number: r['number'] as String,
        subject: r['subject'] as String,
        body: r['body'] as String,
        priority: r['priority'] as String,
        priorityLabel: directiveLabel(r['priority'] as String),
        status: directiveLabel(r['status'] as String),
        isDraft: r['is_draft'] == true,
        issuer: _person(r['issuer']),
        currentUserId: r['current_user_id'] as String,
        today: DateTime.parse(r['today'] as String),
        issueDate: DateTime.tryParse(r['issue_date'] as String? ?? ''),
        dueDate: DateTime.tryParse(r['due_date'] as String? ?? ''),
        allowedActions: _actions(r['allowed_actions']),
        executors: directiveRows(r['executors'])
            .map((e) => DirectiveExecutor(
                person: _person(e['person']),
                status: directiveLabel(e['status'] as String),
                isPrimary: e['is_primary'] == true,
                overdue: e['overdue'] == true))
            .toList(),
        attachments: directiveRows(r['attachments']).map(_file).toList(),
        allowTransfer: r['allow_transfer'] == true,
        allReportsApproved: r['all_reports_approved'] == true,
        transferChoices:
            directiveRows(r['transfer_choices']).map(_person).toList(),
        filePolicy: _policy(r['file_policy']));
  }

  @override
  Future<DirectivePage<DirectiveReport>> reports(String company, String id,
      {String? cursor}) async {
    final r = await _call(
        'reports', company, {'directive': id, 'start': cursor ?? '0'});
    return DirectivePage(
        items: directiveRows(r['items'])
            .map((p) => DirectiveReport(
                id: p['id'] as String,
                author: _person(p['author']),
                body: p['body'] as String,
                doneDate: DateTime.parse(p['done_date'] as String),
                createdAt: p['created_at'] as String,
                status: directiveLabel(p['status'] as String),
                allowedActions: _actions(p['allowed_actions']),
                attachments:
                    directiveRows(p['attachments']).map(_file).toList(),
                version: (p['version'] as num).toInt(),
                reviewNote: p['review_note'] as String? ?? ''))
            .toList(),
        nextCursor: r['next_cursor'] as String?);
  }

  @override
  Future<DirectivePage<DirectiveHistory>> history(String company, String id,
      {String? cursor}) async {
    final r = await _call(
        'history', company, {'directive': id, 'start': cursor ?? '0'});
    return DirectivePage(
        items: directiveRows(r['items'])
            .map((p) => DirectiveHistory(
                action: p['action'] as String,
                actor: p['actor'] as String,
                createdAt: p['created_at'] as String,
                description: p['description'] as String,
                reference: p['reference'] as String))
            .toList(),
        nextCursor: r['next_cursor'] as String?);
  }

  String _date(DateTime date) => date.toIso8601String().split('T').first;
  @override
  Future<String> saveDraft(String company, DirectiveDraft draft,
      {required String requestKey}) async {
    final r = await _call('save_draft', company, {
      'request_key': requestKey,
      'payload': {
        'id': draft.id,
        'version': _versions[draft.id] ?? 0,
        'subject': draft.subject,
        'body': draft.body,
        'priority': draft.priority,
        'due_date': draft.dueDate == null ? null : _date(draft.dueDate!),
        'executor_ids': draft.executorIds,
        'primary_id': draft.primaryId,
        'allow_transfer': draft.allowTransfer,
        'attachment_ids': draft.attachments.map((f) => f.id).toList()
      }
    });
    final id = r['id'] as String;
    _versions[id] = (r['version'] as num).toInt();
    return id;
  }

  final Map<String, String> _issuedDrafts = {};
  @override
  Future<String> issue(String company, DirectiveDraft draft,
      {required String requestKey, void Function(String)? onDraftSaved}) async {
    final id = _issuedDrafts[requestKey] ??
        await saveDraft(company, draft, requestKey: '${requestKey}_draft');
    _issuedDrafts[requestKey] = id;
    onDraftSaved?.call(id);
    final r = await _call(
        'issue', company, {'directive': id, 'request_key': requestKey});
    return r['id'] as String;
  }

  @override
  Future<void> report(String company, String id,
      {required DateTime doneDate,
      required String body,
      required List<DirectiveAttachment> attachments,
      required String requestKey}) async {
    await _call('report', company, {
      'directive': id,
      'request_key': requestKey,
      'payload': {
        'done_date': _date(doneDate),
        'body': body,
        'attachment_ids': attachments.map((f) => f.id).toList()
      }
    });
  }

  @override
  Future<void> review(String company, String id, String reportId,
      {required bool approve,
      required String reason,
      required String requestKey}) async {
    await _call('review', company, {
      'directive': id,
      'report_id': reportId,
      'approve': approve,
      'reason': reason,
      'request_key': requestKey
    });
  }

  @override
  Future<void> transfer(String company, String id,
      {required String recipientId,
      required String reason,
      required String requestKey,
      String? executorId}) async {
    await _call('transfer', company, {
      'directive': id,
      'recipient_id': recipientId,
      'executor_id': executorId,
      'reason': reason,
      'request_key': requestKey
    });
  }

  @override
  Future<void> close(String company, String id,
      {required String requestKey}) async {
    await _call('close', company, {'directive': id, 'request_key': requestKey});
  }

  @override
  Future<DirectiveAttachment> uploadAttachment(String company,
      {String? directiveId,
      required String filename,
      required Uint8List bytes,
      required String requestKey}) async {
    if (directiveId == null) throw StateError('ابتدا پیش‌نویس را ذخیره کنید.');
    return _file(await _call('upload_attachment', company, {
      'directive': directiveId,
      'filename': filename,
      'content_base64': base64Encode(bytes),
      'request_key': requestKey
    }));
  }

  @override
  Future<DirectiveDownloadedFile> downloadAttachment(
      String company, String attachmentId) async {
    final r = await _call(
        'download_attachment', company, {'attachment': attachmentId});
    return DirectiveDownloadedFile(
        r['filename'] as String, base64Decode(r['content_base64'] as String));
  }
}

String directiveLabel(String value) =>
    const {
      'Draft': 'پیش‌نویس',
      'Sent': 'ابلاغ‌شده',
      'Closed': 'مختومه',
      'Archived': 'بایگانی‌شده',
      'Pending': 'در انتظار انجام',
      'Awaiting Review': 'منتظر بررسی',
      'Returned': 'نیازمند اصلاح',
      'Approved': 'تأییدشده',
      'Transferred': 'منتقل‌شده',
      'In Progress': 'در حال انجام',
      'Medium': 'عادی',
      'High': 'مهم',
      'Urgent': 'فوری'
    }[value] ??
    value;
