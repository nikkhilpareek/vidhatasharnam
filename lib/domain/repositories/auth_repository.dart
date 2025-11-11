abstract class AuthRepository {
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> refreshUser();
  Future<void> registerUser({
    required String name,
    required String email,
    required String phone,
    required String password,
  });
}

