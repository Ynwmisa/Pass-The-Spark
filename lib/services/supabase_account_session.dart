import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';
import 'account_session.dart';

class SupabaseAccountSession extends ChangeNotifier implements AccountSession {
  SupabaseAccountSession(this.client) {
    _subscription = client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) _recovering = true;
        notifyListeners();
      },
      onError: (Object _) {
        notifyListeners();
      },
    );
  }
  final SupabaseClient client;
  late final StreamSubscription<AuthState> _subscription;
  bool _recovering = false;
  @override
  bool get recovering => _recovering;
  @override
  SparkAccount? get account {
    final user = client.auth.currentUser;
    if (user == null || user.emailConfirmedAt == null) return null;
    return SparkAccount(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] is String
          ? user.userMetadata!['display_name'] as String
          : 'Student',
    );
  }

  Future<T> _perform<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthException catch (e) {
      final message = switch (e.code) {
        'invalid_credentials' => 'The email or password is incorrect.',
        'email_not_confirmed' => 'Confirm your email before signing in.',
        'weak_password' => 'Choose a password with at least 8 characters.',
        'email_address_not_authorized' =>
          'Email delivery is not available for this address yet. Contact the organiser.',
        'otp_expired' =>
          'This link is invalid or expired. Request another link.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'Too many attempts. Wait a little before trying again.',
        _ =>
          'The account request could not be completed. Check your details and try again.',
      };
      throw AccountException(message);
    } catch (_) {
      throw const AccountException(
        'Could not reach the account service. Check your connection and try again.',
      );
    }
  }

  @override
  Future<bool> register(String name, String email, String password) =>
      _perform(() async {
        final result = await client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {'display_name': name.trim()},
          emailRedirectTo: 'passthespark://auth-callback/',
        );
        return result.session == null;
      });
  @override
  Future<void> signIn(String email, String password) => _perform(() async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  });
  @override
  Future<void> resendConfirmation(String email) => _perform(() async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: 'passthespark://auth-callback/',
    );
  });
  @override
  Future<void> requestRecovery(String email) => _perform(() async {
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'passthespark://auth-callback/',
    );
  });
  @override
  Future<void> setPassword(String password) => _perform(() async {
    await client.auth.updateUser(UserAttributes(password: password));
    // Require ordinary sign-in after password recovery.
    await client.auth.signOut(scope: SignOutScope.local);
    _recovering = false;
    notifyListeners();
  });
  @override
  Future<void> signOut() => _perform(() async {
    await client.auth.signOut(scope: SignOutScope.local);
    _recovering = false;
    notifyListeners();
  });
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
