import 'dart:async';

import 'package:asoud_erp/features/auth/data/account_repository.dart';
import 'package:asoud_erp/features/auth/domain/entities/login_state.dart';

class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository(
      {LoginState? state,
      AccountProfile? profile,
      this.saveError,
      this.saveGate,
      this.recoveryAvailable = false})
      : state = state ?? const LoginState(userId: 'admin@example.com'),
        profile = profile ?? const AccountProfile(username: 'admin@example.com');

  LoginState state;
  AccountProfile profile;
  Object? saveError;
  Completer<void>? saveGate;
  bool recoveryAvailable;
  int saveCalls = 0;
  int resetCalls = 0;
  int confirmCalls = 0;
  int activateCalls = 0;
  int changeCalls = 0;
  Object? changeError;
  Map<String, Object?> lastSave = {};
  Map<String, Object?> lastChange = {};
  Map<String, Object?> lastConfirm = {};
  String? lastReset;
  String? selected;

  @override
  Future<LoginState> loginState() async => state;

  @override
  Future<LoginState> selectOffice(String company) async {
    selected = company;
    return state;
  }

  @override
  Future<AccountProfile> adminProfile() async => profile;

  @override
  Future<AccountProfile> saveAdminProfile({
    required String firstName,
    required String lastName,
    required String mobile,
    String nationalId = '',
    String email = '',
  }) async {
    saveCalls++;
    lastSave = {
      'first': firstName,
      'last': lastName,
      'mobile': mobile,
      'national': nationalId,
      'email': email,
    };
    await saveGate?.future;
    if (saveError != null) throw saveError!;
    return profile;
  }

  @override
  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String repeatPassword,
  }) async {
    changeCalls++;
    lastChange = {
      'current': currentPassword,
      'new': newPassword,
      'repeat': repeatPassword,
    };
    if (changeError != null) throw changeError!;
    return const PasswordChangeResult();
  }

  @override
  Future<bool> recoveryStatus() async => recoveryAvailable;

  @override
  Future<int> requestPasswordReset(String identifier) async {
    resetCalls++;
    lastReset = identifier;
    return 30;
  }

  @override
  Future<void> confirmPasswordReset({
    required String identifier,
    required String code,
    required String newPassword,
    required String repeatPassword,
  }) async {
    confirmCalls++;
    lastConfirm = {'identifier': identifier, 'code': code};
  }

  @override
  Future<void> activateAccount({
    required String identifier,
    required String code,
    required String newPassword,
    required String repeatPassword,
  }) async {
    activateCalls++;
    lastConfirm = {'identifier': identifier, 'code': code};
  }
}
