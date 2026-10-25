import '../../../core/config/app_config.dart';

/// Result of checking a server address typed on the login screen.
class ServerUrlCheck {
  const ServerUrlCheck.valid(String this.url) : error = null;
  const ServerUrlCheck.invalid(String this.error) : url = null;

  final String? url;
  final String? error;
  bool get isValid => url != null;
}

/// Validates and normalizes the server address, and decides which servers the
/// app may talk to. Pure and injectable so tests can cover production rules.
class ServerUrlPolicy {
  const ServerUrlPolicy({
    this.requireHttps = AppConfig.requireHttps,
    this.cleartextHosts = AppConfig.allowedCleartextHosts,
    this.allowedHosts = AppConfig.allowedServerHosts,
    this.buildServer = AppConfig.erpNextBaseUrl,
  });

  final bool requireHttps;
  final String cleartextHosts;
  final String allowedHosts;
  final String buildServer;

  static Set<String> _hosts(String csv) => csv
      .split(',')
      .map((h) => h.trim().toLowerCase())
      .where((h) => h.isNotEmpty)
      .toSet();

  static String? _hostOf(String url) {
    try {
      final host = Uri.parse(url).host.toLowerCase();
      return host.isEmpty ? null : host;
    } catch (_) {
      return null;
    }
  }

  bool _matches(Set<String> patterns, String host) => patterns.any((p) =>
      p == host || (p.startsWith('*.') && host.endsWith(p.substring(1))));

  ServerUrlCheck check(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return const ServerUrlCheck.invalid('نشانی سرور را وارد کنید.');
    }
    if (raw.contains(RegExp(r'\s'))) {
      return const ServerUrlCheck.invalid('نشانی سرور نباید فاصله داشته باشد.');
    }
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(raw);
    final withScheme = hasScheme ? raw : '${requireHttps ? 'https' : 'http'}://$raw';
    final Uri uri;
    try {
      uri = Uri.parse(withScheme);
    } on FormatException {
      return const ServerUrlCheck.invalid('نشانی سرور معتبر نیست.');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return const ServerUrlCheck.invalid(
          'نشانی سرور باید با http یا https شروع شود.');
    }
    if (uri.host.isEmpty) {
      return const ServerUrlCheck.invalid('نشانی سرور معتبر نیست.');
    }
    if (uri.userInfo.isNotEmpty) {
      return const ServerUrlCheck.invalid(
          'نام کاربری و رمز عبور را داخل نشانی سرور وارد نکنید.');
    }
    if (uri.hasQuery || uri.hasFragment) {
      return const ServerUrlCheck.invalid(
          'نشانی سرور نباید پارامتر یا بخش اضافه داشته باشد.');
    }
    final host = uri.host.toLowerCase();
    final build = _hostOf(buildServer);
    final isBuildServer = build != null && build == host;
    final allowed = _hosts(allowedHosts);
    if (allowed.isNotEmpty && !isBuildServer && !_matches(allowed, host)) {
      return const ServerUrlCheck.invalid(
          'اتصال به این سرور مجاز نیست؛ نشانی سرور سازمان را وارد کنید.');
    }
    if (requireHttps &&
        uri.scheme == 'http' &&
        !isBuildServer &&
        !_matches(_hosts(cleartextHosts), host)) {
      return const ServerUrlCheck.invalid(
          'برای اتصال امن، نشانی سرور باید با https شروع شود.');
    }
    var normalized = uri.replace(path: uri.path == '/' ? '' : uri.path).toString();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return ServerUrlCheck.valid(normalized);
  }
}
