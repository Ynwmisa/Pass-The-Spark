class SparkAccount {
  const SparkAccount({
    required this.id,
    required this.email,
    required this.displayName,
  });
  final String id;
  final String email;
  final String displayName;
}

class AccountException implements Exception {
  const AccountException(this.message);
  final String message;
}
