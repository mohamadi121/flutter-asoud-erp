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
    await _client.login(username: username, password: password);
    return getCurrentUser();
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
