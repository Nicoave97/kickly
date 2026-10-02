import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  SupabaseClient get _db => Supabase.instance.client;

  User? get currentUser => _db.auth.currentUser;

  Future<AuthResponse> signIn({
    required String identifier,
    required String password,
  }) async {
    final value = identifier.trim();
    if (value.contains('@')) {
      return _db.auth.signInWithPassword(email: value, password: password);
    }

    final response = await _db.functions.invoke(
      'login-with-identifier',
      body: {'identifier': value.toLowerCase(), 'password': password},
    );

    final data = response.data;
    if (response.status < 200 || response.status >= 300 || data is! Map) {
      throw AuthException('Username o password non corretti.');
    }

    final refreshToken = data['refresh_token'] as String?;
    final accessToken = data['access_token'] as String?;
    if (refreshToken == null || accessToken == null) {
      throw AuthException('Username o password non corretti.');
    }

    return _db.auth.setSession(refreshToken, accessToken: accessToken);
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) {
    return _db.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'username': username.trim().toLowerCase(),
      },
    );
  }

  Future<void> requestPasswordReset(String email) async {
    final redirectTo =
    kIsWeb ? Uri.base.resolve('#/reset-password').toString() : null;
    await _db.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }

  Future<void> setRecoveredPassword(String newPassword) async {
    await _db.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() => _db.auth.signOut();

  Future<void> updateEmail(String email) async {
    await _db.auth.updateUser(UserAttributes(email: email.trim()));
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _db.auth.updateUser(
      UserAttributes(
        password: newPassword,
        currentPassword: currentPassword,
      ),
    );
  }
}
