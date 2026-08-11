import '../entities/authenticated_user.dart';

abstract interface class AuthRepository {
  bool get isAuthenticated;

  Future<AuthenticatedUser> signIn({
    required String username,
    required String password,
  });

  Future<AuthenticatedUser> getCurrentUser();

  Future<void> signOut();
}
