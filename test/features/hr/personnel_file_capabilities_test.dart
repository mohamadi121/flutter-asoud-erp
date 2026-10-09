import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/personnel_file_repository.dart';
import 'package:asoud_erp/features/hr/data/personnel_repository.dart';
import 'package:asoud_erp/features/hr/domain/personnel_file.dart';
import 'package:asoud_erp/core/widgets/asoud_form.dart';
import 'package:asoud_erp/features/hr/presentation/pages/personnel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFileRepo extends Fake implements PersonnelFileRepository {
  PersonnelFile? fileResult;
  Object? fileError;
  bool savedContractCalled = false;
  Map<String, dynamic>? lastSavedContract;
  bool addedPromotionCalled = false;
  Map<String, dynamic>? lastAddedPromotion;
  bool contractFileCalled = false;

  @override
  Future<PersonnelFile> file(String profileId) async {
    if (fileError != null) throw fileError!;
    return fileResult ?? PersonnelFile.fromJson(fullFileJson);
  }

  @override
  Future<({String contentBase64, String filename})> contractFile(
      String contract) async {
    contractFileCalled = true;
    return (filename: 'test_contract.pdf', contentBase64: 'dGVzdA==');
  }

  @override
  Future<List<ContractSummary>> saveContract({
    required String profileId,
    required String startDate,
    required String terms,
    String? endDate,
    String? contract,
    bool isSigned = false,
    String? fileBase64,
    String? filename,
    bool submit = false,
  }) async {
    savedContractCalled = true;
    lastSavedContract = {
      'profileId': profileId,
      'startDate': startDate,
      'endDate': endDate,
      'terms': terms,
      'isSigned': isSigned,
      'submit': submit,
      'filename': filename,
      'fileBase64': fileBase64,
    };
    return [];
  }

  @override
  Future<void> addPromotion({
    required String profileId,
    required String promotionDate,
    String? designation,
    String? department,
    String? branch,
    String? remarks,
  }) async {
    addedPromotionCalled = true;
    lastAddedPromotion = {
      'profileId': profileId,
      'promotionDate': promotionDate,
      'designation': designation,
      'department': department,
      'branch': branch,
      'remarks': remarks,
    };
  }
}

class _FakePeopleRepo extends Fake implements PersonnelRepository {
  @override
  void dispose() {}

  Map<String, dynamic>? customDetail;
  bool canEdit = true;
  bool isLocalDemo = false;
  String? recordFetched;

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
      'can_edit': canEdit,
    };
  }

  @override
  Future<Map<String, dynamic>> profileOptions(String id) async => {
        'job_title': ['سرپرست فروش', 'مدیر فروش'],
        'department': ['فروش', 'بازاریابی'],
        'branch': ['مرکزی', 'غرب'],
      };

  @override
  Future<Map<String, dynamic>> record(String id) async {
    recordFetched = id;
    return {
      'filename': 'doc_file.pdf',
      'file': 'dGVzdA==',
    };
  }
}

class _Observer extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);
}

const fullFileJson = <String, dynamic>{
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
      'file': {'id': 'F1', 'filename': 'contract.pdf'},
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
      'details': 'قرارداد یکساله تمام‌وقت',
    },
    {
      'kind': 'promotion',
      'title': 'ارتقای سمت به کارشناس ارشد',
      'date': '2026-08-15T09:00:00',
      'by': 'مدیر منابع انسانی',
      'details': 'Designation: کارشناس ارشد فروش',
    },
    {
      'kind': 'document',
      'title': 'بارگذاری مدرک تحصیلی',
      'date': '2026-07-10T14:20:00',
      'by': 'کاربر',
      'details': '',
    },
    {
      'kind': 'transfer',
      'title': 'انتقال به شعبه مرکزی',
      'date': '2026-06-01T11:00:00',
      'by': 'امیر محمدی',
      'details': 'Branch: شعبه مرکزی',
    },
    {
      'kind': 'joining',
      'title': 'شروع همکاری در شرکت',
      'date': '2024-01-01T08:00:00',
      'by': 'سیستم',
      'details': '',
    },
    {
      'kind': 'attendance',
      'title': 'ثبت کارکرد ماهانه',
      'date': '2023-12-01T08:00:00',
      'by': 'سیستم',
      'details': '',
    },
  ],
};

const sparseFileJson = <String, dynamic>{
  'profile_id': 'PARTY-SPARSE',
  'can_edit': false,
  'revision': '2026-10-01',
  'header': {
    'name': 'کارمند ساده',
    'employee_code': 'HR-EMP-0099',
    'designation': 'کارمند',
    'department': 'فروش',
    'department_name': 'فروش',
    'company': 'شرکت نمونه',
    'status': 'Active',
    'employment_type': 'Full-time',
    'date_of_joining': '2024-01-01',
    'service_length': null,
  },
  'personal': {},
  'organization': {
    'company': 'شرکت نمونه',
    'department': 'فروش',
    'department_name': 'فروش',
    'designation': 'کارمند',
    'branch': 'تهران',
    'reports_to': null,
  },
  'employment': {
    'employment_type': 'Full-time',
    'date_of_joining': '2024-01-01',
    'status': 'Active',
    'service_length': null,
  },
  'contracts': <Map<String, dynamic>>[],
  'documents': <Map<String, dynamic>>[],
  'activity': <Map<String, dynamic>>[],
};

Future<void> _pumpDetail(
  WidgetTester tester, {
  required _FakePeopleRepo people,
  required _FakeFileRepo fileRepo,
  _Observer? observer,
  double width = 390.0,
  double height = 1800.0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: AsoudTheme.light,
    navigatorObservers: observer != null ? [observer] : [],
    home: PersonnelDetailPage(
      id: 'PARTY-42',
      repository: people,
      fileRepository: fileRepo,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text,
    {bool settle = true}) async {
  final target = find.text(text);
  await tester.scrollUntilVisible(target.last, 200,
      scrollable: find.byType(Scrollable).last);
  await tester.ensureVisible(target.last);
  await tester.tap(target.last);
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('Capability 4: Direct Manager & Service Length', () {
    testWidgets('full fixture shows manager name and service length',
        (tester) async {
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo();
      final observer = _Observer();

      await _pumpDetail(tester,
          people: people, fileRepo: fileRepo, observer: observer);

      expect(find.text('مدیر مستقیم'), findsOneWidget);
      expect(find.text('سهراب سپهری'), findsOneWidget);

      expect(find.text('سابقه خدمت'), findsOneWidget);
      expect(find.text('۲ سال و ۱ ماه'), findsOneWidget);

      // Direct manager is tappable and opens PersonnelDetailPage for HR-EMP-0007
      observer.routes.clear();
      await tester.tap(find.text('سهراب سپهری'));
      await tester.pumpAndSettle();

      expect(observer.routes, hasLength(1));
      final pushedDetail = find.byType(PersonnelDetailPage);
      expect(pushedDetail, findsOneWidget);
      expect(
          tester.widget<PersonnelDetailPage>(pushedDetail).id, 'HR-EMP-0007');
    });

    testWidgets(
        'sparse fixture shows ثبت نشده and manager tile is not tappable',
        (tester) async {
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo()
        ..fileResult = PersonnelFile.fromJson(sparseFileJson);
      final observer = _Observer();

      await _pumpDetail(tester,
          people: people, fileRepo: fileRepo, observer: observer);

      expect(find.text('مدیر مستقیم'), findsOneWidget);
      expect(find.text('سابقه خدمت'), findsOneWidget);
      // Both tiles show «ثبت نشده»
      expect(find.text('ثبت نشده'), findsAtLeast(2));
      expect(
          find.widgetWithText(PersonnelManagerAndTenureSlot, '—'), findsNothing);
      expect(
          find.widgetWithText(PersonnelManagerAndTenureSlot, '-'), findsNothing);

      // Tapping manager tile when employee ID is empty does NOT push route
      observer.routes.clear();
      await tester.tap(find.text('مدیر مستقیم'));
      await tester.pumpAndSettle();
      expect(observer.routes, isEmpty);
    });

    testWidgets('LOCAL- manager name is masked to ثبت نشده', (tester) async {
      final people = _FakePeopleRepo();
      final maskedJson = Map<String, dynamic>.from(fullFileJson);
      maskedJson['organization'] = {
        'company': 'شرکت نمونه',
        'department': 'فروش',
        'department_name': 'فروش',
        'designation': 'کارشناس',
        'branch': 'تهران',
        'reports_to': {
          'employee': 'LOCAL-MGR',
          'name': 'LOCAL-مدیر موقت',
        },
      };
      final fileRepo = _FakeFileRepo()
        ..fileResult = PersonnelFile.fromJson(maskedJson);

      await _pumpDetail(tester, people: people, fileRepo: fileRepo);

      expect(find.text('LOCAL-مدیر موقت'), findsNothing);
      expect(find.text('ثبت نشده'), findsAtLeast(1));
    });
  });

  group('Capability 5: Activity Feed', () {
    testWidgets('full fixture renders max 5 activities and opens full feed',
        (tester) async {
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo();
      final observer = _Observer();

      await _pumpDetail(tester,
          people: people, fileRepo: fileRepo, observer: observer);

      expect(find.text('آخرین فعالیت‌ها'), findsOneWidget);
      expect(find.text('مشاهده همه'), findsOneWidget);

      // 5 top items are shown on overview
      expect(find.text('تمدید قرارداد سالانه'), findsOneWidget);
      expect(find.textContaining('توسط سارا حسینی'), findsOneWidget);
      expect(find.text('ارتقای سمت به کارشناس ارشد'), findsOneWidget);
      expect(find.text('بارگذاری مدرک تحصیلی'), findsOneWidget);
      expect(find.text('انتقال به شعبه مرکزی'), findsOneWidget);
      expect(find.text('شروع همکاری در شرکت'), findsOneWidget);

      // 6th activity is NOT shown on overview (take 5)
      expect(find.text('ثبت کارکرد ماهانه'), findsNothing);

      // Tapping «مشاهده همه» opens full feed page where all 6 are listed
      observer.routes.clear();
      await tester.tap(find.text('مشاهده همه'));
      await tester.pumpAndSettle();

      expect(observer.routes, hasLength(1));
      expect(find.text('ثبت کارکرد ماهانه'), findsOneWidget);
    });

    testWidgets('sparse fixture shows empty activity message', (tester) async {
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo()
        ..fileResult = PersonnelFile.fromJson(sparseFileJson);

      await _pumpDetail(tester, people: people, fileRepo: fileRepo);

      expect(find.text('هنوز فعالیتی ثبت نشده است.'), findsOneWidget);
    });

    testWidgets('offline legacy fallback converts legacy records to activity',
        (tester) async {
      final people = _FakePeopleRepo()
        ..customDetail = {
          'profile': {
            'id': 'PARTY-42',
            'display_name': 'امیر موفق',
            'job_title': 'فروش',
            'department': 'فروش',
            'date_of_joining': '2024-01-01',
          },
          'records': [
            {
              'name': 'REC-1',
              'kind': 'history',
              'title': 'سابقه ارتقای دستی',
              'record_date': '2026-09-01',
            }
          ],
          'revision': 'r1',
          'offline': true,
        };
      final fileRepo = _FakeFileRepo()
        ..fileError = const ApiException(
          message: 'شبکه در دسترس نیست',
          kind: ApiFailureKind.network,
          statusCode: 404,
        );

      await _pumpDetail(tester, people: people, fileRepo: fileRepo);

      expect(find.text('سابقه ارتقای دستی'), findsOneWidget);
    });
  });

  group('Capability 3: Documents', () {
    testWidgets(
        'full fixture renders document statuses, categories and details',
        (tester) async {
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo();
      final observer = _Observer();

      await _pumpDetail(tester,
          people: people, fileRepo: fileRepo, observer: observer);

      // Switch to tab 3 (مدارک)
      await _tapText(tester, 'مدارک');

      expect(find.text('مدارک پرونده'), findsOneWidget);

      // Check document titles
      expect(find.text('کارت ملی هوشمند'), findsOneWidget);
      expect(find.text('گواهی‌نامه رانندگی'), findsOneWidget);
      expect(find.text('گذرنامه بین‌المللی'), findsOneWidget);
      expect(find.text('دانشنامه کارشناسی'), findsOneWidget);

      // Check status chip labels
      expect(find.text('معتبر'), findsOneWidget);
      expect(find.text('رو به انقضا'), findsOneWidget);
      expect(find.text('منقضی'), findsOneWidget);
      expect(find.text('بدون تاریخ انقضا'), findsOneWidget);

      // Category choice chips
      expect(find.text('همه'), findsOneWidget);

      // Tap on document opens document details page
      observer.routes.clear();
      await tester.tap(find.text('کارت ملی هوشمند'));
      await tester.pumpAndSettle();

      expect(observer.routes, hasLength(1));
      expect(find.text('جزئیات مدرک'), findsOneWidget);
      expect(find.text('مشاهده/دانلود فایل'), findsOneWidget);

      // Tap download file
      await tester.tap(find.text('مشاهده/دانلود فایل'));
      await tester.pumpAndSettle();
      expect(people.recordFetched, 'DOC-1');
    });

    testWidgets('category choice chip filters documents', (tester) async {
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo();

      await _pumpDetail(tester, people: people, fileRepo: fileRepo);
      await _tapText(tester, 'مدارک');

      expect(find.text('دانشنامه کارشناسی'), findsOneWidget);
      expect(find.text('تحصیلی'), findsOneWidget);

      // Filter by education
      await _tapText(tester, 'تحصیلی');
      await tester.pumpAndSettle();

      expect(find.text('دانشنامه کارشناسی'), findsOneWidget);
      expect(find.text('کارت ملی هوشمند'), findsNothing);
    });

    testWidgets('sparse documents show empty notice', (tester) async {
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo()
        ..fileResult = PersonnelFile.fromJson(sparseFileJson);

      await _pumpDetail(tester, people: people, fileRepo: fileRepo);
      await _tapText(tester, 'مدارک');

      expect(find.text('مدرکی ثبت نشده است.'), findsOneWidget);
    });
  });

  group('Capability 1: Contracts', () {
    testWidgets(
        'full fixture renders contracts with chips, dates and remaining days',
        (tester) async {
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo();

      await _pumpDetail(tester, people: people, fileRepo: fileRepo);

      // Navigate to 'اطلاعات پرسنلی' -> 'قراردادها'
      await _tapText(tester, 'اطلاعات پرسنلی');
      await _tapText(tester, 'قراردادها');

      expect(find.text('قرارداد فعلی'), findsOneWidget);
      expect(find.text('سوابق قراردادها'), findsOneWidget);

      // State chips
      expect(find.text('در جریان'), findsOneWidget);
      expect(find.text('آینده'), findsOneWidget);
      expect(find.text('منقضی'), findsOneWidget);
      expect(find.text('امضا نشده'), findsOneWidget);

      // Remaining days in Persian digits
      expect(find.text('۸۰ روز مانده'), findsOneWidget);
      expect(find.text('۴۴۵ روز مانده'), findsOneWidget);

      // Download file button on active contract
      expect(find.text('مشاهده فایل'), findsOneWidget);
      await tester.tap(find.text('مشاهده فایل'));
      await tester.pumpAndSettle();
      expect(fileRepo.contractFileCalled, isTrue);
    });

    testWidgets('sparse contracts show ثبت نشده and never dashes',
        (tester) async {
      final people = _FakePeopleRepo();
      final fileRepo = _FakeFileRepo()
        ..fileResult = PersonnelFile.fromJson(sparseFileJson);

      await _pumpDetail(tester, people: people, fileRepo: fileRepo);

      await _tapText(tester, 'اطلاعات پرسنلی');
      await _tapText(tester, 'قراردادها');

      expect(find.text('ثبت نشده'), findsAtLeast(2));
      expect(find.widgetWithText(PersonnelContractsSlot, '—'), findsNothing);
      expect(find.widgetWithText(PersonnelContractsSlot, '-'), findsNothing);
    });

    testWidgets('HR manager sees افزودن قرارداد and can save a new contract',
        (tester) async {
      final people = _FakePeopleRepo()..canEdit = true;
      final fileRepo = _FakeFileRepo();

      await _pumpDetail(tester, people: people, fileRepo: fileRepo);

      await _tapText(tester, 'اطلاعات پرسنلی');
      await _tapText(tester, 'قراردادها');

      await _tapText(tester, 'افزودن قرارداد');
      expect(find.text('اطلاعات قرارداد'), findsOneWidget);

      // Expand form section
      await _tapText(tester, 'اطلاعات قرارداد');

      // Fill form fields
      tester
          .widgetList<AsoudFormDateField>(find.byType(AsoudFormDateField))
          .first
          .controller
          .text = '2025-03-21';
      tester
          .widgetList<AsoudFormDateField>(find.byType(AsoudFormDateField))
          .last
          .controller
          .text = '2026-03-20';
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'شرح قرارداد *'),
          'قرارداد آزمایشی جدید');

      // Toggle signed switch
      await _tapText(tester, 'امضا شده');

      // Save contract
      await _tapText(tester, 'ذخیره');

      expect(fileRepo.savedContractCalled, isTrue);
      expect(fileRepo.lastSavedContract!['terms'], 'قرارداد آزمایشی جدید');
      expect(fileRepo.lastSavedContract!['isSigned'], isTrue);
    });

    testWidgets('non-HR manager does NOT see افزودن قرارداد', (tester) async {
      final people = _FakePeopleRepo()..canEdit = false;
      final fileRepo = _FakeFileRepo();

      await _pumpDetail(tester, people: people, fileRepo: fileRepo);

      await _tapText(tester, 'اطلاعات پرسنلی');
      await _tapText(tester, 'قراردادها');

      expect(find.text('افزودن قرارداد'), findsNothing);
    });
  });

  group('Capability 2: Promotion', () {
    testWidgets('HR manager sees ثبت ارتقا یا تغییر سمت and can save promotion',
        (tester) async {
      final people = _FakePeopleRepo()..canEdit = true;
      final fileRepo = _FakeFileRepo();

      await _pumpDetail(tester, people: people, fileRepo: fileRepo);

      // Navigate to 'اطلاعات پرسنلی' -> 'اطلاعات استخدامی'
      await _tapText(tester, 'اطلاعات پرسنلی');
      await _tapText(tester, 'اطلاعات استخدامی');

      await _tapText(tester, 'ثبت ارتقا یا تغییر سمت');
      expect(find.text('اطلاعات تغییر سمت'), findsOneWidget);

      // Expand form section
      await _tapText(tester, 'اطلاعات تغییر سمت');

      // Enter date
      tester
          .widget<AsoudFormDateField>(find.byType(AsoudFormDateField))
          .controller
          .text = '2026-01-01';
      await tester.pumpAndSettle();

      // Select job title dropdown
      await _tapText(tester, 'سمت جدید');
      await _tapText(tester, 'سرپرست فروش');

      // Enter remarks
      await tester.enterText(find.widgetWithText(TextFormField, 'توضیحات'),
          'ارتقا بر اساس ارزیابی عملکرد');

      // Save promotion
      await _tapText(tester, 'ذخیره');
      await tester.pumpAndSettle();

      expect(fileRepo.addedPromotionCalled, isTrue);
      expect(fileRepo.lastAddedPromotion!['designation'], 'سرپرست فروش');
      expect(fileRepo.lastAddedPromotion!['remarks'],
          'ارتقا بر اساس ارزیابی عملکرد');
    });

    testWidgets('non-HR manager does NOT see ثبت ارتقا یا تغییر سمت',
        (tester) async {
      final people = _FakePeopleRepo()..canEdit = false;
      final fileRepo = _FakeFileRepo();

      await _pumpDetail(tester, people: people, fileRepo: fileRepo);

      await _tapText(tester, 'اطلاعات پرسنلی');
      await _tapText(tester, 'اطلاعات استخدامی');

      expect(find.text('ثبت ارتقا یا تغییر سمت'), findsNothing);
    });
  });

  group('Responsive Layout (320px & 390px)', () {
    for (final width in [320.0, 390.0]) {
      testWidgets('renders all overview and subpages cleanly at width $width',
          (tester) async {
        final people = _FakePeopleRepo();
        final fileRepo = _FakeFileRepo();

        await _pumpDetail(tester,
            people: people, fileRepo: fileRepo, width: width);

        expect(tester.takeException(), isNull);
        expect(find.text('مدیر مستقیم'), findsOneWidget);
        expect(find.text('سابقه خدمت'), findsOneWidget);
        expect(find.text('آخرین فعالیت‌ها'), findsOneWidget);

        // Switch to documents tab
        await _tapText(tester, 'مدارک');
        expect(tester.takeException(), isNull);
        expect(find.text('مدارک پرونده'), findsOneWidget);

        // Switch to personal info page
        await _tapText(tester, 'اطلاعات پرسنلی');
        expect(tester.takeException(), isNull);

        // Open contracts
        await _tapText(tester, 'قراردادها');
        expect(tester.takeException(), isNull);
        expect(find.text('قرارداد فعلی'), findsOneWidget);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();

        // Open employment
        await _tapText(tester, 'اطلاعات استخدامی');
        expect(tester.takeException(), isNull);
        expect(find.text('ثبت ارتقا یا تغییر سمت'), findsOneWidget);
      });
    }
  });

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
      final file = PersonnelFile.fromJson(fullFileJson);
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
      final file = PersonnelFile.fromJson(fullFileJson);
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

    test('returns null when fileRepository is null (skipping file-only capabilities)',
        () async {
      final people = _FakePeopleRepo();

      final file = await loadPersonnelFile(
        id: 'PARTY-42',
        repository: people,
        fileRepository: null,
      );

      expect(file, isNull);
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
}
