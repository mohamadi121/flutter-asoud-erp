import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FrappeAuthRepository implements AuthRepository {
  FrappeAuthRepository(this._client);

  final FrappeApiClient _client;

  @override
  bool get isAuthenticated => _client.isAuthenticated;

  @override
  Future<AuthenticatedUser> signIn({
    required String username,
    required String password,
  }) async {
    final session = await _client.login(username: username, password: password);
    try {
      return await getCurrentUser();
    } on ApiException catch (error) {
      // While a temporary password is pending the server refuses every API
      // except `session.login_state`, `session.logout` and
      // `account_security.change_password` (HTTP 403). The sign-in is valid:
      // the post-login step reads `login_state` and forces the change.
      if (error.kind != ApiFailureKind.forbidden) rethrow;
      return AuthenticatedUser(
          id: session.userId, fullName: session.fullName, roles: const {});
    }
  }

  @override
  Future<AuthenticatedUser> getCurrentUser() async {
    final user = await _client.getCurrentUser();
    return AuthenticatedUser(
      id: user.userId,
      fullName: user.fullName,
      roles: user.roles.toSet(),
      employeeId: user.employeeId,
      employeeName: user.employeeName,
      company: user.company,
    );
  }

  @override
  Future<void> signOut() => _client.logout();
}
