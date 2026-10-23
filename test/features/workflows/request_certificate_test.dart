import 'dart:convert';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/workflows/data/generic_request_repository.dart';
import 'package:asoud_erp/features/workflows/domain/entities/request_models.dart';
import 'package:asoud_erp/features/workflows/presentation/request_screen_registry.dart';
import 'package:asoud_erp/features/workflows/presentation/widgets/request_detail_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'request_fixtures.dart';

// The keys are those of `get_request.certificate` and `get_certificate`
// (backend docs/api/form-execution.md, «Download»).
const _summary = {
  'number': 'CERT-2026-00001',
  'filename': 'CERT-2026-00001.pdf',
  'issued_on': '2026-10-23 09:30:00.123456',
};

class _Repo extends Fake implements GenericRequestRepository {
  _Repo(this.detailMap, {this.failure});
  final Map<String, dynamic> detailMap;
  final Object? failure;
  final requested = <String>[];
  @override
  Future<Map<String, dynamic>> detail(String name) async =>
      Map<String, dynamic>.from(detailMap);
  @override
  Future<List<Map<String, dynamic>>> options() async => requestOptionFixtures();
  @override
  Future<List<RequestComment>> comments(String name) async => const [];
  @override
  Future<({String filename, String contentType, Uint8List bytes})> attachment(
      String name,
      {bool thumbnail = false}) async {
    final data = requestData('get_attachment') as Map;
    return (
      filename: '${data['filename']}',
      contentType: '${data['content_type']}',
      bytes: base64Decode('${data['content_base64']}')
    );
  }

  @override
  Future<({String filename, String contentType, Uint8List bytes})> certificate(
      String request) async {
    requested.add(request);
    if (failure != null) throw failure!;
    final data = requestData('get_certificate') as Map;
    return (
      filename: '${data['filename']}',
      contentType: '${data['content_type']}',
      bytes: base64Decode('${data['content_base64']}')
    );
  }
}

Map<String, dynamic> _approved({Map<String, dynamic>? certificate}) => {
      ...Map<String, dynamic>.from(requestData('get_request_purchase') as Map),
      'status_key': 'approved',
      'status_label': 'تأیید شده',
      'status': 'Completed',
      'can_edit': false,
      'can_cancel': false,
      'certificate': certificate,
    };

Future<void> _open(WidgetTester tester, _Repo repo,
    {double width = 390, List<(String, Uint8List)>? saved}) async {
  await tester.binding.setSurfaceSize(Size(width, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: RequestDetailScaffold(
        repository: repo,
        name: '${repo.detailMap['name']}',
        fileSaver: (name, bytes) async => saved?.add((name, bytes)),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(RequestScreenRegistry.clear);

  test('detail parses the certificate summary and defaults to none', () {
    final withCertificate = RequestDetail.fromMap(_approved(certificate: {..._summary}));
    expect(withCertificate.certificate?.number, 'CERT-2026-00001');
    expect(withCertificate.certificate?.filename, 'CERT-2026-00001.pdf');
    expect(withCertificate.certificate?.issuedOn, '2026-10-23 09:30:00.123456');
    expect(RequestDetail.fromMap(_approved()).certificate, isNull);
    expect(RequestDetail.fromMap({'name': 'X'}).certificate, isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('«دانلود گواهی» is shown when the certificate exists at $width',
        (tester) async {
      await _open(tester, _Repo(_approved(certificate: {..._summary})), width: width);
      expect(find.text('دانلود گواهی'), findsOneWidget);
      expect(find.textContaining('CERT-2026-00001'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no certificate, no download button', (tester) async {
    await _open(tester, _Repo(_approved()));
    expect(find.text('دانلود گواهی'), findsNothing);
  });

  testWidgets('tapping downloads through get_certificate and saves the PDF',
      (tester) async {
    final repo = _Repo(_approved(certificate: {..._summary}));
    final saved = <(String, Uint8List)>[];
    await _open(tester, repo, saved: saved);
    await tester.tap(find.text('دانلود گواهی'));
    await tester.pumpAndSettle();
    expect(repo.requested, ['${repo.detailMap['name']}']);
    expect(saved.single.$1, 'CERT-2026-00001.pdf');
    expect(utf8.decode(saved.single.$2), startsWith('%PDF'));
  });

  testWidgets('a refusal shows the Persian permission message, not an outage',
      (tester) async {
    final repo = _Repo(_approved(certificate: {..._summary}),
        failure: const ApiException(
            kind: ApiFailureKind.forbidden,
            message: 'شما اجازهٔ دریافت این گواهی را ندارید.',
            statusCode: 403));
    await _open(tester, repo);
    await tester.tap(find.text('دانلود گواهی'));
    await tester.pumpAndSettle();
    expect(find.textContaining('اجازه'), findsWidgets);
    expect(find.textContaining('ارتباط با سرور برقرار نشد'), findsNothing);
  });
}
