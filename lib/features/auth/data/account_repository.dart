import '../../../core/network/api_exception.dart';
import '../../../core/network/asoud_api_response.dart';
import '../../../core/network/frappe_client.dart';
import '../domain/entities/login_state.dart';

/// What `account_security.change_password` reports.
class PasswordChangeResult {
  const PasswordChangeResult({
    this.changed = true,
    this.otherSessionsRevoked = true,
    this.reauthenticationRequired = true,
  });

  factory PasswordChangeResult.fromJson(Map<String, dynamic> json) =>
      PasswordChangeResult(
        changed: json['changed'] == true,
        otherSessionsRevoked: json['other_sessions_revoked'] == true,
        reauthenticationRequired:
            json['reauthentication_required_for_saved_credentials'] == true,
      );

  final bool changed;
  final bool otherSessionsRevoked;

  /// A password saved on this device is now stale and must be replaced.
  final bool reauthenticationRequired;
}

/// Server calls of the sign-in and onboarding path (namespace
/// `asoud_erp.api.v1`: `session`, `onboarding`, `account_security`).
///
/// These calls deliberately use [FrappeApiClient.callMethod] and never
/// `callAsoudMethod`: that path stores every write payload in the offline
/// queue, and a password or a half-finished onboarding must never be queued
/// on the device.
abstract interface class AccountRepository {
  /// `session.login_state`.
  Future<LoginState> loginState();

  /// `session.select_office`. Returns the refreshed state.
  Future<LoginState> selectOffice(String company);

  /// `onboarding.get_admin_profile`.
  Future<AccountProfile> adminProfile();

  /// `onboarding.save_admin_profile`. Returns the saved identity.
  Future<AccountProfile> saveAdminProfile({
    required String firstName,
    required String lastName,
    required String mobile,
    String nationalId = '',
    String email = '',
  });

  /// `account_security.change_password`. A wrong current password is an
  /// HTTP 417 `ValidationError` (never 401), so the session survives.
  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String repeatPassword,
  });

  /// (guest) `account_security.recovery_status.available`.
  Future<bool> recoveryStatus();

  /// (guest) `account_security.request_password_reset`. Returns the minutes
  /// the one-time code stays valid.
  Future<int> requestPasswordReset(String identifier);

  /// (guest) `account_security.confirm_password_reset`.
  Future<void> confirmPasswordReset({
    required String identifier,
    required String code,
    required String newPassword,
    required String repeatPassword,
  });

  /// (guest) `account_security.activate_account` (invitation code).
  Future<void> activateAccount({
    required String identifier,
    required String code,
    required String newPassword,
    required String repeatPassword,
  });
}

class FrappeAccountRepository implements AccountRepository {
  FrappeAccountRepository(this._client);

  final FrappeApiClient _client;

  static const _base = 'asoud_erp.api.v1';

  Future<dynamic> _call(String method, [Map<String, dynamic>? data]) async {
    final body = await _client.callMethod('$_base.$method', data: data);
    final envelope = body['message'];
    if (envelope is! Map) throw const ApiException.protocol();
    return AsoudApiResponse<dynamic>.parse(
        Map<String, dynamic>.from(envelope), (value) => value).data;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) throw const ApiException.protocol();
    return Map<String, dynamic>.from(value);
  }

  @override
  Future<LoginState> loginState() async =>
      LoginState.fromJson(_map(await _call('session.login_state')));

  @override
  Future<LoginState> selectOffice(String company) async => LoginState.fromJson(
      _map(await _call('session.select_office', {'company': company})));

  @override
  Future<AccountProfile> adminProfile() async => AccountProfile.fromAdminProfile(
      _map(await _call('onboarding.get_admin_profile')));

  @override
  Future<AccountProfile> saveAdminProfile({
    required String firstName,
    required String lastName,
    required String mobile,
    String nationalId = '',
    String email = '',
  }) async {
    final data = <String, dynamic>{
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'mobile': mobile,
    };
    if (nationalId.trim().isNotEmpty) data['national_id'] = nationalId.trim();
    if (email.trim().isNotEmpty) data['email'] = email.trim();
    return AccountProfile.fromAdminProfile(
        _map(await _call('onboarding.save_admin_profile', data)));
  }

  @override
  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String repeatPassword,
  }) async =>
      PasswordChangeResult.fromJson(
          _map(await _call('account_security.change_password', {
        'current_password': currentPassword,
        'new_password': newPassword,
        'repeat_password': repeatPassword,
      })));

  @override
  Future<bool> recoveryStatus() async =>
      _map(await _call('account_security.recovery_status'))['available'] ==
      true;

  @override
  Future<int> requestPasswordReset(String identifier) async {
    final data = _map(await _call('account_security.request_password_reset',
        {'identifier': identifier.trim()}));
    final minutes = data['expires_in_minutes'];
    return minutes is num ? minutes.toInt() : 30;
  }

  @override
  Future<void> confirmPasswordReset({
    required String identifier,
    required String code,
    required String newPassword,
    required String repeatPassword,
  }) async {
    await _call('account_security.confirm_password_reset', {
      'identifier': identifier.trim(),
      'code': code.trim(),
      'new_password': newPassword,
      'repeat_password': repeatPassword,
    });
  }

  @override
  Future<void> activateAccount({
    required String identifier,
    required String code,
    required String newPassword,
    required String repeatPassword,
  }) async {
    await _call('account_security.activate_account', {
      'identifier': identifier.trim(),
      'code': code.trim(),
      'new_password': newPassword,
      'repeat_password': repeatPassword,
    });
  }
}
