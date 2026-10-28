import 'package:asoud_erp/features/auth/domain/entities/login_state.dart';
import 'package:asoud_erp/features/auth/domain/identity_validators.dart';
import 'package:asoud_erp/features/auth/domain/login_router.dart';
import 'package:asoud_erp/features/auth/domain/server_url_policy.dart';
import 'package:asoud_erp/features/dashboard/domain/home_action.dart';
import 'package:flutter_test/flutter_test.dart';

LoginState _state({
  bool active = true,
  bool temp = false,
  bool admin = false,
  bool canCreate = false,
  bool profileDone = false,
  List<String> offices = const [],
  String? selected,
  bool firstOffice = false,
}) =>
    LoginState(
      userId: 'u@example.com',
      accountActive: active,
      mustChangePassword: temp,
      isSystemAdmin: admin,
      canCreateOffice: canCreate,
      adminProfileComplete: profileDone,
      firstOfficeExists: firstOffice || offices.isNotEmpty,
      offices: [for (final o in offices) OfficeRef(name: o, title: o)],
      selectedOffice: selected,
    );

void main() {
  group('login routing from the server state', () {
    test('disabled account stops', () {
      expect(decideLoginRoute(_state(active: false, admin: true)).step,
          LoginStep.accountDisabled);
    });
    test('temporary password comes before everything', () {
      expect(decideLoginRoute(_state(temp: true, admin: true, canCreate: true)).step,
          LoginStep.changePassword);
    });
    test('admin without office creates the first office', () {
      expect(decideLoginRoute(_state(admin: true, canCreate: true, profileDone: true)).step,
          LoginStep.createFirstOffice);
    });
    test('admin with office but incomplete profile completes it', () {
      expect(
          decideLoginRoute(_state(admin: true, canCreate: true, offices: ['A']))
              .step,
          LoginStep.completeAdminProfile);
    });
    test('complete admin goes home', () {
      expect(
          decideLoginRoute(_state(
              admin: true, canCreate: true, profileDone: true, offices: ['A'])),
          const LoginRoute(LoginStep.home, office: 'A'));
    });
    test('regular user never sees first-office or admin-profile screens', () {
      final noOffice = decideLoginRoute(_state());
      expect(noOffice.step, LoginStep.noOfficeAccess);
      final withOffice = decideLoginRoute(_state(offices: ['A']));
      expect(withOffice.step, LoginStep.home);
      // even if the server would (wrongly) report an incomplete profile
      expect(decideLoginRoute(_state(offices: ['A'], profileDone: false)).step,
          LoginStep.home);
    });
    test('user with create-office permission but not admin is not onboarded',
        () {
      expect(decideLoginRoute(_state(canCreate: true)).step,
          LoginStep.noOfficeAccess);
    });
    test('several offices restore the valid previous one or ask', () {
      expect(
          decideLoginRoute(_state(offices: ['A', 'B'], selected: 'B')),
          const LoginRoute(LoginStep.home, office: 'B'));
      expect(decideLoginRoute(_state(offices: ['A', 'B'], selected: 'Z')).step,
          LoginStep.selectOffice);
      expect(decideLoginRoute(_state(offices: ['A', 'B'])).step,
          LoginStep.selectOffice);
    });
    test('parses the server json defensively', () {
      final s = LoginState.fromJson({
        'user': {'id': 'a@b.c', 'first_name': 'علی'},
        'is_system_admin': 1,
        'offices': [
          {'id': 'O1', 'title': 'دفتر ۱'},
          {'id': ''},
        ],
      });
      expect(s.isSystemAdmin, isTrue);
      expect(s.offices.single.title, 'دفتر ۱');
      expect(s.profile.firstName, 'علی');
      expect(s.adminProfileComplete, isFalse);
      expect(s.next, isNull);
    });
  });

  group('identity validators', () {
    test('mobile accepts Persian and Latin digits and prefixes', () {
      expect(IdentityValidators.normalizeMobile('۰۹۱۲۳۴۵۶۷۸۹'), '09123456789');
      expect(IdentityValidators.normalizeMobile('09123456789'), '09123456789');
      expect(IdentityValidators.normalizeMobile('+98 912 345 6789'),
          '09123456789');
      expect(IdentityValidators.normalizeMobile('00989123456789'),
          '09123456789');
      expect(IdentityValidators.mobile('0812345678'), isNotNull);
      expect(IdentityValidators.mobile(''), isNotNull);
      expect(IdentityValidators.mobile('0912345678'), isNotNull);
    });
    test('national id checksum', () {
      expect(IdentityValidators.nationalId(''), isNull);
      expect(IdentityValidators.nationalId('0499370899'), isNull);
      expect(IdentityValidators.nationalId('۰۴۹۹۳۷۰۸۹۹'), isNull);
      expect(IdentityValidators.nationalId('0499370890'), isNotNull);
      expect(IdentityValidators.nationalId('1111111111'), isNotNull);
      expect(IdentityValidators.nationalId('123'), isNotNull);
    });
    test('email', () {
      expect(IdentityValidators.email(''), isNull);
      expect(IdentityValidators.email('a@b.com'), isNull);
      expect(IdentityValidators.email('a@b'), isNotNull);
      expect(IdentityValidators.email('a b@c.com'), isNotNull);
    });
    test('password policy', () {
      expect(PasswordPolicy.newPassword('short'), isNotNull);
      expect(PasswordPolicy.newPassword('abcdefghijkl', current: 'abcdefghijkl'),
          isNotNull);
      expect(PasswordPolicy.newPassword('abcdefghijkl', current: 'old'), isNull);
      expect(PasswordPolicy.repeat('x', 'y'), isNotNull);
      expect(PasswordPolicy.repeat('y', 'y'), isNull);
    });
  });

  group('server url policy', () {
    const prod = ServerUrlPolicy(
        requireHttps: true,
        cleartextHosts: 'lan.local',
        allowedHosts: '',
        buildServer: 'http://build.example.com:8080');
    test('production demands https except configured hosts', () {
      expect(prod.check('http://evil.example.com').isValid, isFalse);
      expect(prod.check('https://erp.example.com').url,
          'https://erp.example.com');
      expect(prod.check('erp.example.com').url, 'https://erp.example.com');
      expect(prod.check('http://lan.local:8000').isValid, isTrue);
      expect(prod.check('http://build.example.com:8080').isValid, isTrue);
    });
    test('rejects junk', () {
      const dev = ServerUrlPolicy(
          requireHttps: false,
          cleartextHosts: '',
          allowedHosts: '',
          buildServer: '');
      expect(dev.check('').isValid, isFalse);
      expect(dev.check('ftp://x.com').isValid, isFalse);
      expect(dev.check('https://u:p@x.com').isValid, isFalse);
      expect(dev.check('https://x.com/?a=1').isValid, isFalse);
      expect(dev.check('a b').isValid, isFalse);
      expect(dev.check('http://x.com/').url, 'http://x.com');
    });
    test('allow-list limits servers', () {
      const limited = ServerUrlPolicy(
          requireHttps: true,
          cleartextHosts: '',
          allowedHosts: '*.asoud.ir,erp.corp.com',
          buildServer: '');
      expect(limited.check('https://a.asoud.ir').isValid, isTrue);
      expect(limited.check('https://erp.corp.com').isValid, isTrue);
      expect(limited.check('https://other.com').isValid, isFalse);
    });
  });

  group('home action rule (spec 28)', () {
    test('ready + permission opens', () {
      expect(resolveHomeAction(state: ModuleState.ready, canUse: true),
          HomeActionKind.open);
    });
    test('active but unconfigured opens setup', () {
      expect(resolveHomeAction(state: ModuleState.needsSetup, canUse: true),
          HomeActionKind.openSetup);
    });
    test('disabled module offers enable only with permission', () {
      expect(
          resolveHomeAction(
              state: ModuleState.disabled, canUse: false, canEnable: true),
          HomeActionKind.offerEnable);
      expect(resolveHomeAction(state: ModuleState.disabled, canUse: true),
          HomeActionKind.showDisabled);
    });
    test('no permission runs nothing', () {
      expect(resolveHomeAction(state: ModuleState.ready, canUse: false),
          HomeActionKind.denied);
      expect(resolveHomeAction(state: ModuleState.needsSetup, canUse: false),
          HomeActionKind.denied);
    });
  });
}
