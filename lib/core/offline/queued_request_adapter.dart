import 'dart:convert';

import 'local_record.dart';

/// The outbox entity type `GenericRequestRepository` stores offline requests
/// in. Such a row has no `operation`; its scope and subject live in a nested
/// payload, so the shared queue needs these helpers to list and label it.
const genericRequestOutboxEntity = 'generic_request_outbox';

/// The Persian name of the operation a queued generic request represents.
const genericRequestOperationLabel = 'ثبت درخواست';

/// The owner and server a queued row belongs to.
typedef QueueScope = ({String owner, String server});

/// Whether [record] is an offline request waiting in the outbox, as opposed to
/// a raw queued mutation (which carries an `operation`).
bool isQueuedRequest(LocalRecord record) =>
    record.entityType == genericRequestOutboxEntity;

/// The `[server, owner, company]` list a generic-request outbox row was saved
/// under (`GenericRequestRepository._scope`); null when it is missing or
/// malformed, so a corrupt row is never attributed to the wrong user.
List<String>? requestScopeParts(LocalRecord record) {
  final raw = record.payload['scope'];
  if (raw is! String) return null;
  try {
    final parsed = jsonDecode(raw);
    if (parsed is List && parsed.length >= 3) {
      return [for (final part in parsed) '$part'];
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Whether [record] belongs to the signed-in user on the current [scope].
bool isRequestOwnedBy(LocalRecord record, QueueScope scope) {
  final parts = requestScopeParts(record);
  return parts != null && parts[0] == scope.server && parts[1] == scope.owner;
}

/// The company a queued request was created for, so its replay can be scoped
/// to the same `GenericRequestRepository`. Null when the row carries none.
String? requestCompanyOf(LocalRecord record) {
  final data = record.payload['data'];
  final value = data is Map ? '${data['company'] ?? ''}'.trim() : '';
  return value.isEmpty ? null : value;
}

/// What the user wrote as the request subject, so the queue card names the
/// request itself; falls back to the request type title then its definition.
String requestSubjectOf(LocalRecord record) {
  final ui = record.payload['ui'];
  final data = record.payload['data'];
  String read(Object? source, String key) =>
      source is Map ? '${source[key] ?? ''}'.trim() : '';
  for (final candidate in [
    read(data, 'subject'),
    read(ui, 'subject'),
    read(ui, 'request_type_title'),
    read(data, 'workflow_definition'),
  ]) {
    if (candidate.isNotEmpty) return candidate;
  }
  return '';
}
