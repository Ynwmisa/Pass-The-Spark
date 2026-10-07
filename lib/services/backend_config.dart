class BackendConfig {
  const BackendConfig({required this.url, required this.publishableKey});
  const BackendConfig.environment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      publishableKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final String url;
  final String publishableKey;
  bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  String? get validationError {
    if (!isConfigured) {
      return 'Add the project URL and publishable key to your local configuration.';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority || uri.userInfo.isNotEmpty) {
      return 'The project URL is invalid.';
    }
    final local = ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host);
    if (uri.scheme != 'https' && !(local && uri.scheme == 'http')) {
      return 'Hosted projects require an HTTPS URL.';
    }
    if (publishableKey.startsWith('sb_secret_')) {
      return 'Use a publishable key, not a secret key.';
    }
    return null;
  }
}
