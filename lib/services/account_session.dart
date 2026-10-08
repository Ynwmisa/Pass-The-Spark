import 'package:flutter/foundation.dart';
import '../models/account.dart';

abstract interface class AccountSession implements Listenable {
  SparkAccount? get account;
  bool get recovering;
  Future<bool> register(String name, String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> resendConfirmation(String email);
  Future<void> requestRecovery(String email);
  Future<void> setPassword(String password);
  Future<void> signOut();
}
