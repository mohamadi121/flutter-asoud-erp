import 'package:flutter/foundation.dart';

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

  /// Production builds only talk to HTTPS servers. The server this build was
  /// compiled for (`ERPNEXT_BASE_URL`) and the hosts listed in
  /// `ALLOWED_CLEARTEXT_HOSTS` (comma separated) are the only HTTP exceptions.
  static const requireHttps = bool.fromEnvironment(
    'REQUIRE_HTTPS',
    defaultValue: kReleaseMode,
  );
  static const allowedCleartextHosts =
      String.fromEnvironment('ALLOWED_CLEARTEXT_HOSTS');

  /// Optional allow-list of server hosts (comma separated, `*.example.com`
  /// allowed). Empty means any valid server may be entered; the build server
  /// is always allowed.
  static const allowedServerHosts =
      String.fromEnvironment('ALLOWED_SERVER_HOSTS');
}
