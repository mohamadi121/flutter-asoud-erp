import 'dart:async';

import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/auth/domain/entities/login_state.dart';
import 'package:asoud_erp/features/auth/presentation/pages/admin_profile_page.dart';
import 'package:asoud_erp/features/auth/presentation/pages/change_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_account_repository.dart';

Widget _wrap(Widget page) => MaterialApp(
      locale: const Locale('fa'),
      theme: AsoudTheme.light,
      home: Directionality(textDirection: TextDirection.rtl, child: page),
    );

Future<void> _type(WidgetTester t, String key, String text) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.enterText(find.byKey(Key(key)), text);
  await t.pump();
}

const _profile = AccountProfile(
    username: 'owner@acme.ir', roleLabel: 'مدیر کل سیستم', active: true);

FilledButton _submit(WidgetTester t) =>
    t.widget<FilledButton>(find.byKey(const Key('profile_submit')));

void main() {
  testWidgets('shows the real account, no step bar, no bottom navigation',
      (tester) async {
    await tester.pumpWidget(_wrap(AdminProfilePage(
        repository: FakeAccountRepository(),
        profile: _profile,
        onCompleted: (_, __) {})));
    expect(find.text('آسود ERP'), findsOneWidget);
    expect(find.text('مشخصات اولیه مدیر کل سیستم'), findsOneWidget);
    expect(find.text('owner@acme.ir'), findsOneWidget);
    expect(find.textContaining('مدیر کل سیستم'), findsWidgets);
    expect(find.textContaining('Administrator'), findsNothing);
    expect(find.text('اطلاعات ضروری'), findsOneWidget);
    expect(find.text('تأیید مشخصات و ورود به خانه'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(Stepper), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('مرحله'), findsNothing);
    expect(find.textContaining('پیش‌نمایش'), findsNothing);
  });

  testWidgets('button is enabled only with valid data', (tester) async {
    await tester.pumpWidget(_wrap(AdminProfilePage(
        repository: FakeAccountRepository(),
        profile: _profile,
        onCompleted: (_, __) {})));
    expect(_submit(tester).onPressed, isNull);
    await _type(tester, 'first_name', 'علی');
    await _type(tester, 'last_name', 'رضایی');
    expect(_submit(tester).onPressed, isNull);
    await _type(tester, 'mobile', '0812');
    expect(_submit(tester).onPressed, isNull);
    await _type(tester, 'mobile', '۰۹۱۲۳۴۵۶۷۸۹');
    expect(_submit(tester).onPressed, isNotNull);
    // optional fields: invalid value blocks, empty is fine
    await tester.tap(find.byKey(const Key('optional_toggle')));
    await tester.pump();
    await _type(tester, 'national_id', '0499370890');
    expect(_submit(tester).onPressed, isNull);
    await _type(tester, 'national_id', '0499370899');
    await _type(tester, 'email', 'bad');
    expect(_submit(tester).onPressed, isNull);
    await _type(tester, 'email', 'a@b.com');
    expect(_submit(tester).onPressed, isNotNull);
  });

  testWidgets('optional card keeps values when collapsed; email keyboard',
      (tester) async {
    await tester.pumpWidget(_wrap(AdminProfilePage(
        repository: FakeAccountRepository(),
        profile: _profile,
        onCompleted: (_, __) {})));
    expect(find.textContaining('اطلاعات تکمیلی', findRichText: true),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('optional_toggle')));
    await tester.pump();
    await _type(tester, 'email', 'a@b.com');
    await _type(tester, 'national_id', '0499370899');
    expect(
        tester.widget<TextField>(find.byKey(const Key('email'))).keyboardType,
        TextInputType.emailAddress);
    await tester.tap(find.byKey(const Key('optional_toggle')));
    await tester.pump();
    expect(find.byKey(const Key('email'), skipOffstage: true), findsNothing);
    await tester.tap(find.byKey(const Key('optional_toggle')));
    await tester.pump();
    expect(
        tester.widget<TextField>(find.byKey(const Key('email'))).controller!.text,
        'a@b.com');
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('national_id')))
            .controller!
            .text,
        '0499370899');
  });

  testWidgets('saves for real, guards double submit, then calls back',
      (tester) async {
    final gate = Completer<void>();
    final repo = FakeAccountRepository(saveGate: gate);
    LoginState? done;
    await tester.pumpWidget(_wrap(AdminProfilePage(
        repository: repo,
        profile: _profile,
        onCompleted: (_, s) => done = s)));
    await _type(tester, 'first_name', 'علی');
    await _type(tester, 'last_name', 'رضایی');
    await _type(tester, 'mobile', '۰۹۱۲۳۴۵۶۷۸۹');
    await tester.tap(find.byKey(const Key('profile_submit')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_submit(tester).onPressed, isNull);
    await tester.tap(find.byKey(const Key('profile_submit')),
        warnIfMissed: false);
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();
    expect(repo.saveCalls, 1);
    expect(repo.lastSave['mobile'], '09123456789');
    expect(repo.lastSave['first'], 'علی');
    expect(done, isNotNull);
  });

  testWidgets('a real error is shown and every value is kept', (tester) async {
    final repo = FakeAccountRepository(
        saveError: const ApiException(
            kind: ApiFailureKind.validation, message: 'این موبایل قبلاً ثبت شده است.'));
    var completed = false;
    await tester.pumpWidget(_wrap(AdminProfilePage(
        repository: repo,
        profile: _profile,
        onCompleted: (_, __) => completed = true)));
    await _type(tester, 'first_name', 'علی');
    await _type(tester, 'last_name', 'رضایی');
    await _type(tester, 'mobile', '09123456789');
    await tester.tap(find.byKey(const Key('profile_submit')));
    await tester.pumpAndSettle();
    expect(find.text('این موبایل قبلاً ثبت شده است.'), findsOneWidget);
    expect(completed, isFalse);
    expect(
        tester.widget<TextField>(find.byKey(const Key('first_name'))).controller!.text,
        'علی');
    expect(_submit(tester).onPressed, isNotNull);
  });

  testWidgets('change password opens the shared screen and keeps the form',
      (tester) async {
    final repo = FakeAccountRepository();
    await tester.pumpWidget(_wrap(AdminProfilePage(
        repository: repo, profile: _profile, onCompleted: (_, __) {})));
    await _type(tester, 'first_name', 'علی');
    await tester.tap(find.byKey(const Key('change_password_button')));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    await tester.tap(find.text('بازگشت بدون تغییر'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminProfilePage), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byKey(const Key('first_name'))).controller!.text,
        'علی');
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('profile form fits at $width without overflow',
        (tester) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(AdminProfilePage(
          repository: FakeAccountRepository(),
          profile: const AccountProfile(
              username: 'a.very.long.username@some-long-company-domain.ir',
              firstName: 'محمدحسین',
              lastName: 'عبدالرحمانی‌زاده',
              mobile: '09123456789'),
          onCompleted: (_, __) {})));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      await tester.tap(find.byKey(const Key('optional_toggle')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_submit(tester).onPressed, isNotNull);
    });
  }

  group('change password screen', () {
    Future<void> open(WidgetTester t, FakeAccountRepository repo,
        {bool forced = false, VoidCallback? onChanged}) async {
      await t.pumpWidget(_wrap(ChangePasswordPage(
          repository: repo, forced: forced, onChanged: onChanged)));
    }

    testWidgets('validates length, equality and sameness', (tester) async {
      final repo = FakeAccountRepository();
      await open(tester, repo);
      await tester.enterText(find.byKey(const Key('current_password')), 'old-password-1');
      await tester.enterText(find.byKey(const Key('new_password')), 'short');
      await tester.enterText(find.byKey(const Key('repeat_password')), 'other');
      await tester.tap(find.text('ثبت رمز جدید'));
      await tester.pump();
      expect(find.textContaining('دست‌کم ۱۲ نویسه'), findsWidgets);
      expect(repo.changeCalls, 0);
      await tester.enterText(find.byKey(const Key('new_password')), 'old-password-1');
      await tester.enterText(find.byKey(const Key('repeat_password')), 'old-password-1');
      await tester.tap(find.text('ثبت رمز جدید'));
      await tester.pump();
      expect(find.textContaining('یکسان نباشد'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('new_password')), 'brand-new-password');
      await tester.enterText(find.byKey(const Key('repeat_password')), 'brand-new-passwore');
      await tester.tap(find.text('ثبت رمز جدید'));
      await tester.pump();
      expect(find.textContaining('تکرار رمز عبور'), findsWidgets);
      expect(repo.changeCalls, 0);
    });

    testWidgets('submits to the service and show/hide works', (tester) async {
      final repo = FakeAccountRepository();
      var changed = false;
      await open(tester, repo, forced: true, onChanged: () => changed = true);
      await tester.enterText(find.byKey(const Key('current_password')), 'temp-password-0');
      await tester.enterText(find.byKey(const Key('new_password')), 'brand-new-password');
      await tester.enterText(find.byKey(const Key('repeat_password')), 'brand-new-password');
      TextField f() => tester.widget<TextField>(find.byKey(const Key('new_password')));
      expect(f().obscureText, isTrue);
      await tester.tap(find.byTooltip('نمایش رمز عبور').at(1));
      await tester.pump();
      expect(f().obscureText, isFalse);
      expect(find.text('بازگشت بدون تغییر'), findsNothing); // forced: no way back
      await tester.tap(find.text('ثبت رمز جدید'));
      await tester.pumpAndSettle();
      expect(repo.changeCalls, 1);
      expect(changed, isTrue);
    });

    testWidgets('server refusal is shown in Persian', (tester) async {
      final repo = FakeAccountRepository()
        ..changeError = const ApiException(
            kind: ApiFailureKind.validation, message: 'رمز فعلی درست نیست.');
      await open(tester, repo);
      await tester.enterText(find.byKey(const Key('current_password')), 'wrong-password-0');
      await tester.enterText(find.byKey(const Key('new_password')), 'brand-new-password');
      await tester.enterText(find.byKey(const Key('repeat_password')), 'brand-new-password');
      await tester.tap(find.text('ثبت رمز جدید'));
      await tester.pumpAndSettle();
      expect(find.text('رمز فعلی درست نیست.'), findsOneWidget);
    });
  });
}
