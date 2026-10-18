import 'dart:typed_data';

/// UI/domain types. Wire names are deliberately confined to the repository
/// adapter.
class DirectivePerson {
  const DirectivePerson(
      {required this.id,
      required this.name,
      this.department = '',
      this.position = ''});
  final String id, name, department, position;
  String get description =>
      [department, position].where((s) => s.isNotEmpty).join(' · ');
}

class DirectiveChoice {
  const DirectiveChoice(this.value, this.label);
  final String value, label;
}

class DirectiveAttachment {
  const DirectiveAttachment(
      {required this.id,
      required this.filename,
      required this.size,
      this.contentType = ''});
  final String id, filename, contentType;
  final int size;
}

class DirectiveFilePolicy {
  const DirectiveFilePolicy(
      {required this.maxBytes,
      required this.maxCount,
      required this.extensions});
  final int maxBytes;
  final int? maxCount;
  final List<String> extensions;
  String? validate(String name, int bytes, int count) {
    if (maxCount != null && count >= maxCount!) {
      return 'تعداد پیوست‌ها بیش از حد مجاز سرور است.';
    }
    if (bytes > maxBytes) return 'حجم فایل بیش از حد مجاز سرور است.';
    final extension =
        name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (extensions.isNotEmpty &&
        !extensions
            .map((e) => e.replaceFirst('.', '').toLowerCase())
            .contains(extension)) {
      return 'نوع فایل در سیاست سرور مجاز نیست.';
    }
    return null;
  }
}

class DirectiveOptions {
  const DirectiveOptions(
      {required this.people,
      required this.priorities,
      required this.allowedActions,
      required this.today,
      this.filePolicy});
  final List<DirectivePerson> people;
  final List<DirectiveChoice> priorities;
  final Set<String> allowedActions;

  /// Authoritative company-local date, not a device clock assumption.
  final DateTime today;
  final DirectiveFilePolicy? filePolicy;
}

class DirectiveDraft {
  const DirectiveDraft(
      {this.id,
      required this.subject,
      required this.body,
      required this.priority,
      this.dueDate,
      required this.executorIds,
      this.primaryId,
      required this.allowTransfer,
      required this.attachments});
  final String? id, primaryId;
  final String subject, body, priority;
  final DateTime? dueDate;
  final List<String> executorIds;
  final bool allowTransfer;
  final List<DirectiveAttachment> attachments;
}

class DirectiveExecutor {
  const DirectiveExecutor(
      {required this.person,
      required this.status,
      required this.isPrimary,
      required this.overdue});
  final DirectivePerson person;
  final String status;
  final bool isPrimary, overdue;
}

class DirectiveReport {
  const DirectiveReport(
      {required this.id,
      required this.author,
      required this.body,
      required this.doneDate,
      required this.createdAt,
      required this.status,
      required this.allowedActions,
      required this.attachments,
      required this.version,
      this.reviewNote = ''});
  final String id, body, status, createdAt, reviewNote;
  final DirectivePerson author;
  final DateTime doneDate;
  final int version;
  final Set<String> allowedActions;
  final List<DirectiveAttachment> attachments;
}

class DirectiveHistory {
  const DirectiveHistory(
      {required this.action,
      required this.actor,
      required this.createdAt,
      required this.description,
      required this.reference});
  final String action, actor, createdAt, description, reference;
}

class DirectiveDetail {
  const DirectiveDetail(
      {required this.id,
      this.company = '',
      required this.number,
      required this.subject,
      required this.body,
      required this.priority,
      required this.priorityLabel,
      required this.status,
      required this.isDraft,
      required this.issuer,
      required this.currentUserId,
      required this.today,
      required this.allowedActions,
      required this.executors,
      required this.attachments,
      required this.allowTransfer,
      required this.allReportsApproved,
      required this.transferChoices,
      this.issueDate,
      this.dueDate,
      this.filePolicy});
  final String id,
      company,
      number,
      subject,
      body,
      priority,
      priorityLabel,
      status,
      currentUserId;
  final bool isDraft, allowTransfer, allReportsApproved;
  final DirectivePerson issuer;
  final DateTime today;
  final DateTime? issueDate, dueDate;
  final Set<String> allowedActions;
  final List<DirectiveExecutor> executors;
  final List<DirectiveAttachment> attachments;
  final List<DirectivePerson> transferChoices;
  final DirectiveFilePolicy? filePolicy;
  bool can(String action) => allowedActions.contains(action);
}

class DirectivePage<T> {
  const DirectivePage({required this.items, this.nextCursor});
  final List<T> items;
  final String? nextCursor;
}

class DirectiveDownloadedFile {
  const DirectiveDownloadedFile(this.filename, this.bytes);
  final String filename;
  final Uint8List bytes;
}
