import 'package:asoud_erp/core/network/api_exception.dart';
import 'package:asoud_erp/core/network/frappe_client.dart';
import 'package:asoud_erp/features/auth/data/account_repository.dart';
import 'package:asoud_erp/features/auth/data/repositories/frappe_auth_repository.dart';
import 'package:asoud_erp/features/auth/domain/entities/login_state.dart';
import 'package:asoud_erp/features/auth/domain/login_router.dart';
import 'package:asoud_erp/features/hr/data/hr_onboarding_repository.dart';
import 'package:asoud_erp/features/office_setup/data/repositories/frappe_office_repository.dart';
import 'package:asoud_erp/features/office_setup/domain/entities/office.dart';
import 'package:asoud_erp/features/roles/domain/role_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Shapes copied from CONTRACT.md / docs/api/login-onboarding.md of the
/// backend (session.py, onboarding.py, account_security.py, role_*.py).
Map<String, dynamic> _envelope(Object? data) => {
      'message': {
        'ok': true,
        'data': data,
        'meta': {'api_version': 'v1'}
      }
    };

Map<String, dynamic> _loginState({
  Map<String, dynamic>? next,
  bool admin = true,
  bool mustChange = false,
  List<Map<String, dynamic>> offices = const [],
}) =>
    {
      'user': {
        'id': 'owner@acme.ir',
        'full_name': 'علی رضایی',
        'first_name': 'علی',
        'last_name': 'رضایی',
        'mobile': '09123456789',
        'email': 'owner@acme.ir',
      },
      'account': {
        'active': true,
        'must_change_password': mustChange,
        'temporary_password_expired': false,
      },
      'roles': ['System Manager'],
      'is_system_admin': admin,
      'role_title': admin ? 'مدیر کل سیستم' : '',
      'scope': admin ? 'global' : 'office',
      'capabilities': {
        'create_office': admin,
        'manage_roles': admin,
        'delegate_roles': admin,
        'register_personnel': admin,
      },
      'offices': offices,
      'selected_office': null,
      'first_office_exists': offices.isNotEmpty,
      'admin_profile_complete': true,
      'verification': {'mobile_verified': false, 'email_verified': false},
      'next': next ?? {'route': 'home', 'office': 'شرکت آسود', 'message': null},
    };

const _office = {
  'id': 'شرکت آسود',
  'title': 'شرکت آسود',
  'office_type': 'Legal',
  'roles': ['System Manager'],
  'office_roles': <String>[],
};

class _Client extends Mock implements FrappeApiClient {}

void main() {
  group('session.login_state parsing', () {
    test('every documented field is read', () {
      final s = LoginState.fromJson(_loginState(offices: [_office]));
      expect(s.userId, 'owner@acme.ir');
      expect(s.fullName, 'علی رضایی');
      expect(s.profile.firstName, 'علی');
      expect(s.profile.mobile, '09123456789');
      expect(s.accountActive, isTrue);
      expect(s.mustChangePassword, isFalse);
      expect(s.isSystemAdmin, isTrue);
      expect(s.roleTitle, 'مدیر کل سیستم');
      expect(s.scope, 'global');
      expect(s.canCreateOffice, isTrue);
      expect(s.canManageRoles, isTrue);
      expect(s.canDelegateRoles, isTrue);
      expect(s.canRegisterPersonnel, isTrue);
      expect(s.offices.single.name, 'شرکت آسود');
      expect(s.offices.single.officeType, 'Legal');
      expect(s.offices.single.roles, ['System Manager']);
      expect(s.mobileVerified, isFalse);
      expect(s.next!.route, 'home');
      expect(s.next!.office, 'شرکت آسود');
    });

    test('next.route decides the step, exactly as the server says', () {
      LoginRoute route(String r, {String? office, String? message}) =>
          decideLoginRoute(LoginState.fromJson(_loginState(
              offices: [_office],
              next: {'route': r, 'office': office, 'message': message})));
      expect(route('account-disabled', message: 'حساب کاربری شما غیرفعال است.'),
          const LoginRoute(LoginStep.accountDisabled,
              message: 'حساب کاربری شما غیرفعال است.'));
      expect(route('change-password').step, LoginStep.changePassword);
      expect(route('create-first-office').step, LoginStep.createFirstOffice);
      expect(
          route('complete-admin-profile').step, LoginStep.completeAdminProfile);
      expect(route('office-select').step, LoginStep.selectOffice);
      expect(route('home', office: 'شرکت آسود'),
          const LoginRoute(LoginStep.home, office: 'شرکت آسود'));
      expect(
          route('no-office',
                  message: 'هنوز دسترسی به دفتر کاری برای شما تعیین نشده است.')
              .message,
          'هنوز دسترسی به دفتر کاری برای شما تعیین نشده است.');
      // an unknown route fails closed
      expect(route('something-new').step, LoginStep.noOfficeAccess);
    });
  });

  group('AccountRepository calls the real methods', () {
    late _Client client;
    late FrappeAccountRepository repo;
    setUp(() {
      client = _Client();
      repo = FrappeAccountRepository(client);
    });

    void answer(Object? data) =>
        when(() => client.callMethod(any(), data: any(named: 'data')))
            .thenAnswer((_) async => _envelope(data));

    test('login_state and select_office', () async {
      answer(_loginState(offices: [_office]));
      final s = await repo.loginState();
      expect(s.userId, 'owner@acme.ir');
      verify(() => client.callMethod('asoud_erp.api.v1.session.login_state',
          data: null)).called(1);
      await repo.selectOffice('شرکت آسود');
      verify(() => client.callMethod('asoud_erp.api.v1.session.select_office',
          data: {'company': 'شرکت آسود'})).called(1);
    });

    test('get/save admin profile use onboarding.* with the real keys',
        () async {
      answer({
        'username': 'owner@acme.ir',
        'role': 'مدیر کل سیستم',
        'active': true,
        'first_name': 'علی',
        'last_name': 'رضایی',
        'mobile': '09123456789',
        'national_id': '0499370899',
        'email': 'owner@acme.ir',
        'mobile_verified': false,
        'email_verified': false,
        'completed': true,
        'person': 'PER-1',
      });
      final p = await repo.adminProfile();
      expect(p.roleLabel, 'مدیر کل سیستم');
      expect(p.nationalId, '0499370899');
      expect(p.active, isTrue);
      verify(() => client.callMethod(
          'asoud_erp.api.v1.onboarding.get_admin_profile',
          data: null)).called(1);
      await repo.saveAdminProfile(
          firstName: ' علی ',
          lastName: 'رضایی',
          mobile: '09123456789',
          nationalId: '',
          email: 'o@acme.ir');
      verify(() => client.callMethod(
              'asoud_erp.api.v1.onboarding.save_admin_profile',
              data: {
                'first_name': 'علی',
                'last_name': 'رضایی',
                'mobile': '09123456789',
                'email': 'o@acme.ir',
              }))
          .called(1);
    });

    test('change_password sends all three fields and parses the result',
        () async {
      answer({
        'changed': true,
        'must_change_password': false,
        'other_sessions_revoked': true,
        'reauthentication_required_for_saved_credentials': true,
      });
      final r = await repo.changePassword(
          currentPassword: 'old', newPassword: 'n' * 12, repeatPassword: 'n' * 12);
      expect(r.changed, isTrue);
      expect(r.otherSessionsRevoked, isTrue);
      expect(r.reauthenticationRequired, isTrue);
      verify(() => client.callMethod(
              'asoud_erp.api.v1.account_security.change_password',
              data: {
                'current_password': 'old',
                'new_password': 'n' * 12,
                'repeat_password': 'n' * 12,
              }))
          .called(1);
    });

    test('recovery_status, request/confirm reset and activation', () async {
      answer({'available': true, 'code_valid_minutes': 30});
      expect(await repo.recoveryStatus(), isTrue);
      answer({'available': false});
      expect(await repo.recoveryStatus(), isFalse);
      answer({'requested': true, 'expires_in_minutes': 30});
      expect(await repo.requestPasswordReset(' a@b.ir '), 30);
      verify(() => client.callMethod(
              'asoud_erp.api.v1.account_security.request_password_reset',
              data: {'identifier': 'a@b.ir'}))
          .called(1);
      answer({'changed': true, 'login_required': true});
      await repo.confirmPasswordReset(
          identifier: 'a@b.ir',
          code: ' 123 ',
          newPassword: 'x' * 12,
          repeatPassword: 'x' * 12);
      verify(() => client.callMethod(
              'asoud_erp.api.v1.account_security.confirm_password_reset',
              data: {
                'identifier': 'a@b.ir',
                'code': '123',
                'new_password': 'x' * 12,
                'repeat_password': 'x' * 12,
              }))
          .called(1);
      await repo.activateAccount(
          identifier: 'a@b.ir',
          code: 'C',
          newPassword: 'x' * 12,
          repeatPassword: 'x' * 12);
      verify(() => client.callMethod(
              'asoud_erp.api.v1.account_security.activate_account',
              data: any(named: 'data')))
          .called(1);
    });

    test('a failure envelope or a bad shape is not swallowed', () async {
      when(() => client.callMethod(any(), data: any(named: 'data')))
          .thenAnswer((_) async => {'message': 'plain'});
      expect(repo.loginState(), throwsA(isA<ApiException>()));
    });
  });

  group('sign-in with a temporary password', () {
    test('a 403 from current_user does not abort the sign-in', () async {
      final client = _Client();
      when(() => client.login(
              username: any(named: 'username'), password: any(named: 'password')))
          .thenAnswer((_) async =>
              const FrappeSession(userId: 'temp@acme.ir', fullName: 'تست'));
      when(() => client.getCurrentUser()).thenThrow(const ApiException(
          kind: ApiFailureKind.forbidden, message: 'اجازه انجام این عملیات را ندارید.'));
      final user = await FrappeAuthRepository(client)
          .signIn(username: 'temp@acme.ir', password: 'temp');
      expect(user.id, 'temp@acme.ir');
      expect(user.roles, isEmpty);
    });

    test('any other failure still fails the sign-in', () async {
      final client = _Client();
      when(() => client.login(
              username: any(named: 'username'), password: any(named: 'password')))
          .thenAnswer((_) async =>
              const FrappeSession(userId: 'u', fullName: 'u'));
      when(() => client.getCurrentUser()).thenThrow(const ApiException(
          kind: ApiFailureKind.network, message: 'قطع'));
      expect(
          FrappeAuthRepository(client).signIn(username: 'u', password: 'p'),
          throwsA(isA<ApiException>()));
    });
  });

  group('FrappeClient status handling', () {
    FrappeClient clientWith(
        void Function(RequestOptions, RequestInterceptorHandler) onRequest) {
      final dio = Dio(BaseOptions(baseUrl: 'https://erp.example.test'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: onRequest));
      return FrappeClient(baseUrl: 'https://erp.example.test', dio: dio);
    }

    Response<dynamic> reply(RequestOptions o, int status, Object? body) =>
        Response(requestOptions: o, statusCode: status, data: body);

    test('a wrong current password is a 417 sentence, not a session loss',
        () async {
      final client = clientWith((o, h) => h.reject(
          DioException(
              requestOptions: o,
              type: DioExceptionType.badResponse,
              response: reply(o, 417, {
                'exc_type': 'ValidationError',
                '_server_messages':
                    '["{\\"message\\": \\"رمز عبور فعلی نادرست است.\\"}"]'
              })),
          true));
      addTearDown(client.close);
      final repo = FrappeAccountRepository(client);
      try {
        await repo.changePassword(
            currentPassword: 'x',
            newPassword: 'y' * 12,
            repeatPassword: 'y' * 12);
        fail('expected a failure');
      } on ApiException catch (e) {
        expect(e.kind, ApiFailureKind.validation);
        expect(e.statusCode, 417);
        expect(e.message, 'رمز عبور فعلی نادرست است.');
      }
    });

    test('logout calls session.logout and reads revoked', () async {
      String? path;
      final client = clientWith((o, h) {
        path = o.path;
        h.resolve(reply(o, 200, _envelope({'revoked': true})));
      });
      addTearDown(client.close);
      await client.logout();
      expect(path, '/api/method/asoud_erp.api.v1.session.logout');
    });

    test('a logout the server did not revoke is reported', () async {
      final client = clientWith(
          (o, h) => h.resolve(reply(o, 200, _envelope({'revoked': false}))));
      addTearDown(client.close);
      expect(client.logout(), throwsA(isA<ApiException>()));
    });

    test('a Persian 401 sentence at login is kept (expired temporary password)',
        () async {
      final client = clientWith((o, h) => h.reject(
          DioException(
              requestOptions: o,
              type: DioExceptionType.badResponse,
              response: reply(o, 401, {
                'exc_type': 'AuthenticationError',
                '_server_messages':
                    '["{\\"message\\": \\"رمز موقت منقضی شده است.\\"}"]'
              })),
          true));
      addTearDown(client.close);
      try {
        await client.login(username: 'a', password: 'b');
        fail('expected a failure');
      } on ApiException catch (e) {
        expect(e.kind, ApiFailureKind.invalidCredentials);
        expect(e.message, 'رمز موقت منقضی شده است.');
      }
    });

    test('Frappe\'s English «Invalid login credentials» stays the generic text',
        () async {
      final client = clientWith((o, h) => h.reject(
          DioException(
              requestOptions: o,
              type: DioExceptionType.badResponse,
              response: reply(o, 401, {
                'message': 'Invalid login credentials',
                '_server_messages':
                    '["{\\"message\\": \\"Invalid login credentials\\"}"]'
              })),
          true));
      addTearDown(client.close);
      try {
        await client.login(username: 'a', password: 'b');
        fail('expected a failure');
      } on ApiException catch (e) {
        expect(e.message, 'نام کاربری یا رمز عبور نادرست است.');
      }
    });
  });

  group('onboarding.create_first_office', () {
    test('posts to the real method and parses {created, office}', () async {
      final client = _Client();
      when(() => client.callMethod(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _envelope({
                'created': true,
                'already_exists': false,
                'office': {
                  'company': 'شرکت آسود',
                  'office_type': 'Legal',
                  'office_saved': true,
                  'accounting_saved': false,
                  'roles_saved': false,
                  'complete': false,
                },
              }));
      final saved = await FrappeOfficeRepository(client).createFirstOffice(
          Office(
              name: 'شرکت آسود',
              type: OfficeType.legal,
              fiscalYearStart: DateTime(2026, 3, 21),
              nationalId: '10101010101'));
      expect(saved.name, 'شرکت آسود');
      expect(saved.setupComplete, isFalse);
      final call = verify(() => client.callMethod(
              'asoud_erp.api.v1.onboarding.create_first_office',
              data: captureAny(named: 'data')))
          .captured
          .single as Map;
      expect(call['office_type'], 'Legal');
      expect(call['company_name'], 'شرکت آسود');
    });
  });

  group('hr_onboarding shapes', () {
    test('temporary password activation', () {
      final a = PersonnelActivation.fromJson({
        'method': 'temporary_password',
        'temporary_password': 'Ab3-xyz-9988',
        'expires_in_hours': 72,
        'must_change_on_first_login': true,
        'note': 'یک‌بار نمایش'
      });
      expect(a.isTemporaryPassword, isTrue);
      expect(a.temporaryPassword, 'Ab3-xyz-9988');
      expect(a.expiresInHours, 72);
      expect(a.mustChangeOnFirstLogin, isTrue);
    });

    test('register_personnel answer', () {
      final r = PersonnelRegistration.fromJson({
        'person': 'PER-1',
        'employee': 'HR-EMP-1',
        'user': 'p@acme.ir',
        'company': 'شرکت آسود',
        'reused_person': false,
        'account_created': true,
        'roles': ['HR_MANAGER'],
        'activation': {
          'method': 'invite',
          'expires_in_hours': 72,
          'sent_to': 'p@acme.ir'
        },
        'hr_lead': false,
      });
      expect(r.accountCreated, isTrue);
      expect(r.activation!.method, 'invite');
      expect(r.activation!.sentTo, 'p@acme.ir');
      expect(r.roles, ['HR_MANAGER']);
    });

    test('issue_temporary_password posts party_profile', () async {
      final client = _Client();
      when(() => client.callMethod(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _envelope({
                'method': 'temporary_password',
                'temporary_password': 'Zz9-abc-1234',
                'expires_in_hours': 72,
                'must_change_on_first_login': true,
              }));
      final a = await HrOnboardingRepository(client)
          .issueTemporaryPassword('PPR-1');
      expect(a.temporaryPassword, 'Zz9-abc-1234');
      verify(() => client.callMethod(
          'asoud_erp.api.v1.hr_onboarding.issue_temporary_password',
          data: {'party_profile': 'PPR-1'})).called(1);
    });
  });

  group('role_management shapes', () {
    test('catalog.system_roles and scope', () {
      final c = RoleCatalog.fromJson({
        'system_roles': [
          {
            'code': 'SYSTEM_ADMIN',
            'native_role': 'System Manager',
            'title': 'مدیر کل سیستم',
            'scope': 'global',
            'scope_title': 'سراسری',
            'system': true,
            'editable': false,
            'description': 'نقش سیستمی',
            'holders': ['owner@acme.ir'],
          }
        ],
        'roles': [
          {
            'code': 'HR_MANAGER',
            'title': 'مدیر منابع انسانی',
            'category': 'HR',
            'parent': '',
            'description': '',
            'enabled': true,
            'base_roles': ['HR Manager'],
            'assigned_users': 2,
            'scope': 'office',
            'system': false,
          }
        ],
      });
      final admin = c.systemRoles.single;
      expect(admin.isSystemAdmin, isTrue);
      expect(admin.scopeLabel, 'سراسری');
      expect(admin.baseRoles, ['System Manager']);
      expect(admin.holders, ['owner@acme.ir']);
      expect(c.roles.single.scope, 'office');
      expect(c.roles.single.scopeLabel, 'مخصوص دفتر');
      expect(c.roles.single.toJson()['scope'], 'office');
    });

    test('system_admin_permissions', () {
      final p = SystemAdminPermissions.fromJson({
        'code': 'SYSTEM_ADMIN',
        'native_role': 'System Manager',
        'title': 'مدیر کل سیستم',
        'scope': 'global',
        'scope_title': 'سراسری',
        'system': true,
        'capabilities': [
          {
            'key': 'offices.create',
            'module': 'دفترهای کار',
            'title': 'ایجاد دفتر',
            'gate': 'setup.save_office (new)',
            'granted': true
          }
        ],
        'document_permissions': [
          {
            'doctype': 'Employee',
            'actions': ['read', 'write', 'create']
          }
        ],
        'document_permission_count': 1,
      });
      expect(p.role.scopeLabel, 'سراسری');
      expect(p.capabilities.single.key, 'offices.create');
      expect(p.capabilities.single.granted, isTrue);
      expect(p.documents.single.doctype, 'Employee');
    });

    test('role_access.assign_role answer', () {
      final r = RoleAssignmentResult.fromJson({
        'user': 'u@acme.ir',
        'role': 'HR_MANAGER',
        'scope': 'office',
        'company': 'شرکت آسود',
        'assigned': true,
        'already_assigned': false,
      });
      expect(r.assigned, isTrue);
      expect(r.company, 'شرکت آسود');
      final removed = RoleAssignmentResult.fromJson({
        'user': 'u@acme.ir',
        'role': 'HR_MANAGER',
        'scope': 'global',
        'company': null,
        'removed': true,
      });
      expect(removed.removed, isTrue);
      expect(removed.company, isNull);
    });
  });
}
