import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFileRepo extends Fake implements PersonnelFileRepository {
  PersonnelFile? fileResult;
  Object? fileError;

  @override
  Future<PersonnelFile> file(String profileId) async {
    if (fileError != null) throw fileError!;
    return fileResult ?? PersonnelFile.fromJson(sampleFileJson);
  }
}

class _FakePeopleRepo extends Fake implements PersonnelRepository {
  @override
  void dispose() {}

  Map<String, dynamic>? customDetail;
  bool isLocalDemo = false;

  @override
  bool get localDemo => isLocalDemo;

  @override
  Future<Map<String, dynamic>> detail(String id) async {
    if (customDetail != null) return customDetail!;
    return {
      'profile': {
        'id': id,
        'display_name': 'امیر موفق',
        'job_title': 'کارشناس فروش',
        'department': 'فروش',
        'employee_code': 'HR-EMP-0042',
        'date_of_joining': '2024-01-01',
      },
      'records': <Map<String, dynamic>>[],
      'revision': 'rev-1',
      'can_edit': true,
    };
  }
}

const sampleFileJson = <String, dynamic>{
  'profile_id': 'PARTY-42',
  'can_edit': true,
  'revision': '2026-10-01',
  'header': {
    'name': 'امیر موفق',
    'employee_code': 'HR-EMP-0042',
    'designation': 'کارشناس فروش',
    'department': 'فروش',
    'department_name': 'فروش',
    'company': 'شرکت نمونه',
    'status': 'Active',
    'employment_type': 'Full-time',
    'date_of_joining': '2024-01-01',
    'service_length': {'years': 2, 'months': 1, 'days': 15},
  },
  'personal': {
    'national_id': '0012345678',
    'mobile': '09121234567',
  },
  'organization': {
    'company': 'شرکت نمونه',
    'department': 'فروش',
    'department_name': 'فروش',
    'designation': 'کارشناس فروش',
    'branch': 'تهران',
    'reports_to': {
      'employee': 'HR-EMP-0007',
      'name': 'سهراب سپهری',
      'designation': 'مدیر فروش',
      'department_name': 'فروش',
    },
  },
  'employment': {
    'employment_type': 'Full-time',
    'date_of_joining': '2024-01-01',
    'status': 'Active',
    'service_length': {'years': 2, 'months': 1, 'days': 15},
  },
  'contracts': [
    {
      'name': 'CONT-ACTIVE',
      'start_date': '2026-01-01',
      'end_date': '2026-12-31',
      'status': 'Active',
      'state': 'active',
      'days_remaining': 80,
      'terms': 'شرایط قرارداد جاری',
    },
    {
      'name': 'CONT-UPCOMING',
      'start_date': '2027-01-01',
      'end_date': '2027-12-31',
      'status': 'Draft',
      'state': 'upcoming',
      'days_remaining': 445,
      'terms': 'قرارداد دوره آتی',
    },
    {
      'name': 'CONT-EXPIRED',
      'start_date': '2025-01-01',
      'end_date': '2025-12-31',
      'status': 'Expired',
      'state': 'expired',
      'terms': 'قرارداد سال گذشته',
    },
    {
      'name': 'CONT-UNSIGNED',
      'start_date': '2028-01-01',
      'end_date': '2028-12-31',
      'status': 'Draft',
      'state': 'unsigned',
      'terms': 'پیش‌نویس بدون امضا',
    },
  ],
  'documents': [
    {
      'id': 'DOC-1',
      'title': 'کارت ملی هوشمند',
      'category': 'identity',
      'document_number': '0012345678',
      'issue_date': '2020-01-01',
      'expiry_date': '2030-01-01',
      'status': 'valid',
      'filename': 'meli.pdf',
    },
    {
      'id': 'DOC-2',
      'title': 'گواهی‌نامه رانندگی',
      'category': 'certificate',
      'document_number': 'CERT-99',
      'issue_date': '2021-01-01',
      'expiry_date': '2026-10-15',
      'status': 'expiring',
      'filename': 'cert.pdf',
    },
    {
      'id': 'DOC-3',
      'title': 'گذرنامه بین‌المللی',
      'category': 'identity',
      'document_number': 'PASS-77',
      'issue_date': '2019-01-01',
      'expiry_date': '2024-01-01',
      'status': 'expired',
      'filename': 'pass.pdf',
    },
    {
      'id': 'DOC-4',
      'title': 'دانشنامه کارشناسی',
      'category': 'education',
      'document_number': 'DEG-44',
      'issue_date': '2015-06-01',
      'expiry_date': '',
      'status': 'no_expiry',
      'filename': 'degree.pdf',
    },
  ],
  'activity': [
    {
      'kind': 'contract',
      'title': 'تمدید قرارداد سالانه',
      'date': '2026-09-20T10:30:00',
      'by': 'سارا حسینی',
      'details': 'Designation: کارشناس',
    },
  ],
};

void main() {
  group('Shared Helpers with Concrete Values', () {
    test('capText masks empty and LOCAL- IDs to ثبت نشده', () {
      expect(capText('علی رضایی'), 'علی رضایی');
      expect(capText(''), capEmpty);
      expect(capText(null), capEmpty);
      expect(capText('   '), capEmpty);
      expect(capText('LOCAL-EMP-001'), capEmpty);
      expect(capText('LOCAL-کارمند'), capEmpty);
    });

    test('capIsLtr detects Latin/ASCII and numbers vs Persian script', () {
      expect(capIsLtr('EMP-42'), isTrue);
      expect(capIsLtr('person@example.com'), isTrue);
      expect(capIsLtr('09121234567'), isTrue);
      expect(capIsLtr('علی رضایی'), isFalse);
      expect(capIsLtr('فروشگاه مرکزی'), isFalse);
    });

    test('capDate formats ISO dates to Jalali and empty to ثبت نشده', () {
      expect(capDate('2024-03-21'), '۱۴۰۳/۰۱/۰۲');
      expect(capDate(''), capEmpty);
      expect(capDate('  '), capEmpty);
    });

    test('contract status helpers return concrete labels and colors', () {
      final file = PersonnelFile.fromJson(sampleFileJson);
      final active = file.contracts.firstWhere((c) => c.state == 'active');
      final upcoming = file.contracts.firstWhere((c) => c.state == 'upcoming');
      final expired = file.contracts.firstWhere((c) => c.state == 'expired');
      final unsigned = file.contracts.firstWhere((c) => c.state == 'unsigned');

      expect(contractStateLabel(active), 'در جریان');
      expect(contractStateColor(active), AsoudColors.success);
      expect(daysRemainingLabel(active), '۸۰ روز مانده');

      expect(contractStateLabel(upcoming), 'آینده');
      expect(contractStateColor(upcoming), AsoudColors.warning);
      expect(daysRemainingLabel(upcoming), '۴۴۵ روز مانده');

      expect(contractStateLabel(expired), 'منقضی');
      expect(contractStateColor(expired), AsoudColors.danger);
      expect(daysRemainingLabel(expired), capEmpty);

      expect(contractStateLabel(unsigned), 'امضا نشده');
      expect(contractStateColor(unsigned), AsoudColors.warning);

      expect(currentContract(file)?.name, 'CONT-ACTIVE');
      expect(serviceLengthLabel(file), '۲ سال و ۱ ماه');
    });

    test('document status helpers return concrete colors', () {
      final file = PersonnelFile.fromJson(sampleFileJson);
      final valid = file.documents.firstWhere((d) => d.status == 'valid');
      final expiring = file.documents.firstWhere((d) => d.status == 'expiring');
      final expired = file.documents.firstWhere((d) => d.status == 'expired');
      final noExpiry =
          file.documents.firstWhere((d) => d.status == 'no_expiry');

      expect(valid.statusLabel, 'معتبر');
      expect(documentStatusColor(valid), AsoudColors.success);

      expect(expiring.statusLabel, 'رو به انقضا');
      expect(documentStatusColor(expiring), AsoudColors.warning);

      expect(expired.statusLabel, 'منقضی');
      expect(documentStatusColor(expired), AsoudColors.danger);

      expect(noExpiry.statusLabel, 'بدون تاریخ انقضا');
      expect(documentStatusColor(noExpiry), AsoudColors.muted);
    });

    test('capDetails translates organizational field names to Persian', () {
      const input =
          'Designation: مدیر | Department: مالی | Branch: مرکز | Reports To: مدیرعامل | Salary Structure: قانون کار';
      final translated = capDetails(input);
      expect(translated.contains('سمت: مدیر'), isTrue);
      expect(translated.contains('واحد: مالی'), isTrue);
      expect(translated.contains('شعبه: مرکز'), isTrue);
      expect(translated.contains('مدیر مستقیم: مدیرعامل'), isTrue);
      expect(translated.contains('ساختار حقوقی: قانون کار'), isTrue);
    });

    test('capEventIcon and capEventColor resolve distinct events', () {
      expect(capEventIcon('joining', ''), Icons.person_add);
      expect(capEventColor('joining'), AsoudColors.success);

      expect(capEventIcon('promotion', ''), Icons.trending_up);
      expect(capEventColor('promotion'), AsoudColors.purple);

      expect(capEventIcon('salary', ''), Icons.payments);
      expect(capEventColor('salary'), AsoudColors.warning);

      expect(capEventIcon('transfer', ''), Icons.compare_arrows);
      expect(capEventColor('transfer'), AsoudColors.cyan);

      expect(capEventIcon('relieving', ''), Icons.logout);
      expect(capEventColor('relieving'), AsoudColors.danger);

      expect(capEventIcon('other', 'تمدید قرارداد'), Icons.description);
    });
  });

  group('Shared Data Loader (loadPersonnelFile)', () {
    test('loads PersonnelFile directly from repository when available',
        () async {
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo();

      final file = await loadPersonnelFile(
        id: 'PARTY-42',
        repository: people,
        fileRepository: fileRepo,
      );

      expect(file, isNotNull);
      expect(file!.profileId, 'PARTY-42');
      expect(file.header.name, 'امیر موفق');
    });

    test('falls back to personnelFileFromLegacy when fileRepository is null',
        () async {
      final people = _FakePeopleRepo();

      final file = await loadPersonnelFile(
        id: 'PARTY-42',
        repository: people,
        fileRepository: null,
      );

      expect(file, isNotNull);
      expect(file!.profileId, 'PARTY-42');
      expect(file.header.name, 'امیر موفق');
      expect(file.header.department, 'فروش');
    });

    test(
        'falls back to personnelFileFromLegacy on offline failure or 404 ApiException',
        () async {
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo()
        ..fileError = const ApiException(
          message: 'یافت نشد',
          kind: ApiFailureKind.server,
          statusCode: 404,
        );

      final file = await loadPersonnelFile(
        id: 'PARTY-42',
        repository: people,
        fileRepository: fileRepo,
      );

      expect(file, isNotNull);
      expect(file!.header.name, 'امیر موفق');
    });

    test('falls back to personnelFileFromLegacy for local IDs and local demo',
        () async {
      final people = _FakePeopleRepo()..isLocalDemo = true;
      final fileRepo = _FakeFileRepo()..fileError = Exception('هر خطایی');

      final file = await loadPersonnelFile(
        id: 'LOCAL-P1',
        repository: people,
        fileRepository: fileRepo,
      );

      expect(file, isNotNull);
      expect(file!.header.name, 'امیر موفق');
    });
  });

  group('Capability Slots Integration in PersonnelDetailPage', () {
    for (final width in [320.0, 390.0]) {
      testWidgets('renders slot hooks cleanly at width $width', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final people = _FakePeopleRepo();
        final fileRepo = _FakeFileRepo();

        await tester.pumpWidget(MaterialApp(
          theme: AsoudTheme.light,
          home: PersonnelDetailPage(
            id: 'PARTY-42',
            repository: people,
            fileRepository: fileRepo,
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(PersonnelManagerAndTenureSlot), findsOneWidget);
        expect(find.byType(PersonnelActivityFeedSlot), findsOneWidget);

        // Switch to tab 3 (مدارک)
        final docsTab = find.text('مدارک');
        await tester.tap(docsTab);
        await tester.pumpAndSettle();

        expect(find.byType(PersonnelDocumentsSlot), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('slot widgets can be instantiated and pumped without errors',
        (tester) async {
      final file = PersonnelFile.fromJson(sampleFileJson);
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo();

      await tester.pumpWidget(MaterialApp(
        theme: AsoudTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              PersonnelContractsSlot(
                file: file,
                profileId: 'PARTY-42',
                canEdit: true,
                repository: fileRepo,
              ),
              PersonnelPromotionSlot(
                profileId: 'PARTY-42',
                canEdit: true,
                personnel: people,
                repository: fileRepo,
              ),
              PersonnelManagerAndTenureSlot(
                file: file,
                repository: people,
                fileRepository: fileRepo,
              ),
              PersonnelDocumentsSlot(
                file: file,
                personnel: people,
              ),
              PersonnelActivityFeedSlot(
                file: file,
                records: const [],
                onRecord: (_) {},
                onRecords: (_) {},
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PersonnelContractsSlot), findsOneWidget);
      expect(find.byType(PersonnelPromotionSlot), findsOneWidget);
      expect(find.byType(PersonnelManagerAndTenureSlot), findsOneWidget);
      expect(find.byType(PersonnelDocumentsSlot), findsOneWidget);
      expect(find.byType(PersonnelActivityFeedSlot), findsOneWidget);
    });
  });
}
