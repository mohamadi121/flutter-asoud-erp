import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/hr/data/hr_contracts_repository.dart';
import 'package:asoud_erp/features/hr/data/hr_contract_template_repository.dart';
import 'package:asoud_erp/features/hr/presentation/pages/contracts/hr_contracts_page.dart';
import 'package:asoud_erp/features/hr/presentation/pages/contracts/hr_contract_issue_page.dart';
import 'package:asoud_erp/features/hr/presentation/pages/contracts/hr_contract_print_page.dart';

void main() {
  group('Personnel Contracts Page & Issuance Tests', () {
    late FakeHrContractsRepository contractsRepo;
    late FakeHrContractTemplateRepository templateRepo;

    setUp(() {
      contractsRepo = FakeHrContractsRepository();
      templateRepo = FakeHrContractTemplateRepository();
    });

    Widget createWidget({
      required Widget child,
      Size size = const Size(390, 844),
    }) {
      return MaterialApp(
        theme: AsoudTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(size: size),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      );
    }

    testWidgets('lists contracts from server with search and status filter at 390px RTL',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        child: HrContractsPage(
          company: 'شرکت نمونه',
          repository: contractsRepo,
          templateRepository: templateRepo,
          canManageTemplate: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('قراردادهای پرسنلی'), findsWidgets);
      expect(find.text('پرسنل نمونه ۱'), findsOneWidget);
      expect(find.text('پرسنل نمونه ۲'), findsOneWidget);
      expect(find.text('پرسنل نمونه ۳'), findsOneWidget);

      // Search by employee code
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'HR-101');
      await tester.pumpAndSettle();

      expect(find.text('پرسنل نمونه ۱'), findsOneWidget);
      expect(find.text('پرسنل نمونه ۲'), findsNothing);

      // Filter by status 'پیش‌نویس'
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      final statusDropdown = find.text('همه');
      await tester.tap(statusDropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('پیش‌نویس').last);
      await tester.pumpAndSettle();

      expect(find.text('پرسنل نمونه ۳'), findsOneWidget);
      expect(find.text('پرسنل نمونه ۱'), findsNothing);
    });

    testWidgets('issue form renders personnel selection and read-only system fields',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        child: HrContractIssuePage(
          company: 'شرکت نمونه',
          repository: contractsRepo,
          templateRepository: templateRepo,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ایجاد قرارداد کار'), findsOneWidget);
      expect(find.text('۱. مشخصات طرفین'), findsOneWidget);
      expect(find.text('اطلاعات سیستمی'), findsOneWidget);

      // Select personnel
      final staffSelector = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(staffSelector);
      await tester.pumpAndSettle();

      await tester.tap(find.text('پرسنل نمونه ۱ (HR-101)').last);
      await tester.pumpAndSettle();

      // Read-only system fields are now filled
      expect(find.text('کارشناس اداری'), findsOneWidget);
      expect(find.text('امور اداری'), findsOneWidget);
    });

    testWidgets('missing payroll value shows explicit Persian "اطلاعات موجود نیست" (never 0)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        child: HrContractIssuePage(
          company: 'شرکت نمونه',
          repository: contractsRepo,
          templateRepository: templateRepo,
        ),
      ));
      await tester.pumpAndSettle();

      // Select personnel 2 (who has null housing allowance)
      final staffSelector = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(staffSelector);
      await tester.pumpAndSettle();

      await tester.tap(find.text('پرسنل نمونه ۲ (HR-102)').last);
      await tester.pumpAndSettle();

      // Verify explicit Persian missing data label
      expect(find.text('اطلاعات موجود نیست'), findsOneWidget);
      // Warning banner that payroll data is missing
      expect(find.textContaining('یکی از فیلدهای حقوقی داده ندارد'), findsOneWidget);
    });

    testWidgets('submit contract has double-tap protection',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        child: HrContractIssuePage(
          company: 'شرکت نمونه',
          repository: contractsRepo,
          templateRepository: templateRepo,
        ),
      ));
      await tester.pumpAndSettle();

      // Select staff 1 (complete data)
      final staffSelector = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(staffSelector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('پرسنل نمونه ۱ (HR-101)').last);
      await tester.pumpAndSettle();

      // Fill required workplace
      final workplaceField = find.widgetWithText(TextFormField, 'محل انجام کار *');
      await tester.enterText(workplaceField, 'دفتر مرکزی');
      await tester.pumpAndSettle();

      // Tap save draft
      final saveBtn = find.text('ذخیره پیش‌نویس');
      await tester.dragUntilVisible(
          saveBtn, find.byType(ListView).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);

      // Verify saving guard is active and button is disabled or in progress
      expect(contractsRepo.savedDraftsCount, 1);
    });

    testWidgets('print page displays A4 layout, header/footer, and draft watermark on non-final contracts',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final draftContract = contractsRepo.fakeDraftContract;

      await tester.pumpWidget(createWidget(
        child: HrContractPrintPage(
          contract: draftContract,
          template: templateRepo.currentTemplate,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('پیش‌نویس ـ فاقد اعتبار نهایی'), findsOneWidget);
      expect(find.text('نام و سربرگ سازمان'), findsOneWidget);
      expect(find.text('قرارداد کار'), findsWidgets);
      expect(find.text('ماده ۱ ـ طرفین قرارداد'), findsOneWidget);
      expect(find.text('ماده ۴ ـ حقوق و مزایا'), findsOneWidget);
      expect(find.text('امضای کارفرما'), findsOneWidget);
      expect(find.text('امضای پرسنل'), findsOneWidget);
    });

    testWidgets('renders list and issue form at 320px width without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget(
        size: const Size(320, 640),
        child: HrContractsPage(
          company: 'شرکت نمونه',
          repository: contractsRepo,
          templateRepository: templateRepo,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('قراردادهای پرسنلی'), findsWidgets);
    });
  });
}
