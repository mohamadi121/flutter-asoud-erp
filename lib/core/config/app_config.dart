abstract final class AppConfig {
  static const erpNextBaseUrl = String.fromEnvironment(
    'ERPNEXT_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  static const erpNextApiKey = String.fromEnvironment('ERPNEXT_API_KEY');
  static const erpNextApiSecret = String.fromEnvironment('ERPNEXT_API_SECRET');
  static const offlineDemoMode = bool.fromEnvironment(
    'OFFLINE_DEMO_MODE',
    defaultValue: true,
  );
}
