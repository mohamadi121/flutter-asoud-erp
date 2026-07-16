abstract final class AppConfig {
  static const erpNextBaseUrl = String.fromEnvironment(
    'ERPNEXT_BASE_URL',
    defaultValue: 'https://erp.example.com',
  );

  static const apiKey = String.fromEnvironment('ERPNEXT_API_KEY');
  static const apiSecret = String.fromEnvironment('ERPNEXT_API_SECRET');

  static bool get hasApiCredentials => apiKey.isNotEmpty && apiSecret.isNotEmpty;
}

