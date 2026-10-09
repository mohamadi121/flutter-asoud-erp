import 'dart:typed_data';

import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/core/offline/local_record.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/request_templates/data/demo_requests.dart';
import 'package:asoud_erp/features/request_templates/data/system_templates.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/data/offline_preview_data.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_local_record_store.dart';

class MockClient extends Mock implements FrappeApiClient {}

/// A signed-out client: the repository is in local (preview) mode.
FrappeApiClient previewClient() {
  final client = MockClient();
  when(() => client.isAuthenticated).thenReturn(false);
  when(() => client.authenticationChanges)
      .thenAnswer((_) => const Stream.empty());
  return client;
}

GenericRequestRepository previewRepository() =>
    GenericRequestRepository(previewClient(), 'شرکت نمونه آسود',
        store: FakeLocalRecordStore());

/// Wraps a page like the app does: Material theme and the API client in
/// the widget tree.
Widget wrapPage(Widget page, {FrappeApiClient? client}) =>
    RepositoryProvider<FrappeApiClient>.value(
        value: client ?? previewClient(),
        child: MaterialApp(
            theme: AsoudTheme.light,
            home:
                Directionality(textDirection: TextDirection.rtl, child: page)));

/// A repository double with canned masters and answers. Everything the
/// template pages call is overridden; the calls are recorded.
class FakeRequestRepository extends Fake implements GenericRequestRepository {
  FakeRequestRepository({
    DateTime? now,
    this.costCenterRequired = true,
    LeaveBalance? balance,
  })  : now = now ?? DateTime(2026, 10, 6),
        balance = balance ?? LeaveBalance.fromMap(offlineLeaveBalance());

  final DateTime now;
  final bool costCenterRequired;
  final LeaveBalance balance;

  final created = <({Map<String, dynamic> data, String requestId})>[];
  final updated = <Map<String, dynamic>>[];
  final cancelled = <String>[];
  final previewCalls = <Map<String, dynamic>>[];
  Map<String, dynamic>? createResult;
  Object? createError;

  /// Answers `previewLeave`; the default accepts every request.
  Future<LeavePreview> Function(Map<String, dynamic> args)? previewHandler;

  @override
  String get company => 'ASOUD Demo';

  @override
  bool get isLocal => false;

  @override
  bool offline(Object error) => false;

  @override
  void dispose() {}

  @override
  Future<void> sync({bool retry = false}) async {}

  @override
  Future<List<LocalRecord>> pending() async => const [];

  @override
  Future<List<Map<String, dynamic>>> options() async => [
        for (final key in SystemTemplateKeys.all)
          systemRequestType(key, costCenterRequired: costCenterRequired),
      ];

  @override
  Future<List<Map<String, dynamic>>> fieldOptions(String fieldType,
          {String txt = '', String? itemCode, String? scope}) async =>
      offlineFieldOptions(fieldType,
          txt: txt, itemCode: itemCode, scope: scope);

  @override
  Future<Map<String, dynamic>?> create(
      Map<String, dynamic> data, String requestId) async {
    created.add((data: data, requestId: requestId));
    if (createError != null) throw createError!;
    return createResult;
  }

  @override
  Future<Map<String, dynamic>> update(
      String name, String subject, Map<String, dynamic> values,
      {List<Map<String, String>>? attachments,
      List<String>? removeAttachments}) async {
    updated.add({
      'name': name,
      'subject': subject,
      'values': values,
      'attachments': attachments,
      'remove': removeAttachments,
    });
    return {'name': name};
  }

  @override
  Future<Map<String, dynamic>> cancel(String name, {String reason = ''}) async {
    cancelled.add(name);
    return {'name': name, 'status_key': 'cancelled'};
  }

  List<Map<String, dynamic>> get rows => demoTemplateRequests(now);

  @override
  Future<RequestListPage> listPage({
    String? templateKey,
    String statusGroup = 'all',
    String search = '',
    int offset = 0,
    int limit = 20,
    String? priority,
    String? dateFrom,
    String? dateTo,
  }) async {
    final all = [
      for (final row in rows)
        if (templateKey == null || row['template_key'] == templateKey)
          RequestSummary.fromMap(row)
    ];
    bool text(RequestSummary row) =>
        search.isEmpty ||
        row.subject.contains(search) ||
        row.number.contains(search);
    final searched = all.where(text).toList();
    final shown = [
      for (final row in searched)
        if (statusGroup == 'all' || row.statusGroup == statusGroup) row
    ];
    return RequestListPage(
      items: shown.skip(offset).take(limit).toList(),
      total: shown.length,
      offset: offset,
      counts: {
        'all': searched.length,
        for (final group in const ['pending', 'approved', 'rejected'])
          group: searched.where((row) => row.statusGroup == group).length,
      },
    );
  }

  @override
  Future<Map<String, dynamic>> detail(String name) async {
    final row = rows.firstWhere((row) => row['name'] == name);
    return {...row};
  }

  @override
  Future<List<RequestComment>> comments(String name) async => [
        for (final row in demoTemplateComments(name, now))
          RequestComment.fromMap(row)
      ];

  @override
  Future<RequestComment> addComment(String name, String text) async =>
      RequestComment(name: 'c', content: text, isMine: true);

  @override
  Future<LeaveBalance> leaveBalance() async => balance;

  @override
  Future<LeavePreview> previewLeave(Map<String, dynamic> args) async {
    previewCalls.add(args);
    return previewHandler != null
        ? previewHandler!(args)
        : LeavePreview.fromMap(offlinePreviewLeave(args));
  }

  @override
  Future<({String filename, String contentType, Uint8List bytes})> attachment(
          String name,
          {bool thumbnail = false}) async =>
      (filename: 'f.png', contentType: 'image/png', bytes: Uint8List(0));
}

/// The first `request_options` row of [templateKey].
Map<String, dynamic> typeOf(String templateKey,
        {bool costCenterRequired = true}) =>
    systemRequestType(templateKey, costCenterRequired: costCenterRequired);

/// Enters [text] into the text field with [key].
Future<void> enterText(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pump();
}
