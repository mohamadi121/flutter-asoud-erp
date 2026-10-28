import 'dart:async';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/features/hr/data/employment_certificate_repository.dart';
import 'package:asoud_erp/features/hr/data/personnel_introduction_letter_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/employment_certificate_form_page.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_introduction_letter_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'employment_certificate_test.dart' show FakeEmploymentCertificateRepository;

class _Repository extends FakeEmploymentCertificateRepository {
  final people = Completer<List<Map<String, dynamic>>>();

  @override
  Future<EmploymentCertificateTemplate> getTemplate({required String company}) async {
    throw const ApiException(kind: ApiFailureKind.forbidden, message: 'اجازه ندارید');
  }

  @override
  Future<List<Map<String, dynamic>>> getEmployeeOptions({required String company}) => people.future;
}

class _IntroductionRepository extends FakePersonnelIntroductionLetterRepository {
  final people = Completer<List<Map<String, dynamic>>>();

  @override
  Future<PersonnelIntroductionTemplate> getTemplate({required String company}) async {
    throw const ApiException(kind: ApiFailureKind.forbidden, message: 'اجازه ندارید');
  }

  @override
  Future<List<Map<String, dynamic>>> getEmployeeOptions({required String company}) => people.future;
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('introduction observes both load failures at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _IntroductionRepository();
      await tester.pumpWidget(RepositoryProvider<PersonnelIntroductionLetterRepository>.value(
        value: repository,
        child: MaterialApp(
          builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const PersonnelIntroductionLetterFormPage(company: 'شرکت'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('اجازه دسترسی به این بخش را ندارید'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsNothing);
      repository.people.completeError(const ApiException(kind: ApiFailureKind.network, message: 'شبکه'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('parallel employee failure is observed after template fails at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository();
      await tester.pumpWidget(RepositoryProvider<EmploymentCertificateRepository>.value(
        value: repository,
        child: MaterialApp(
          builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const EmploymentCertificateFormPage(company: 'شرکت'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('اجازه دسترسی به این بخش را ندارید'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repository.people.completeError(const ApiException(kind: ApiFailureKind.network, message: 'شبکه'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
