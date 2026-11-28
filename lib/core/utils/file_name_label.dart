/// Turns a stored file reference into a human-readable file name for display.
///
/// A stored value may be a bare name (`report.pdf`), a local preview label
/// (`پیش‌نمایش محلی: قرارداد.pdf`), or a server path, possibly with a query
/// string or fragment (`/private/files/report.pdf?token=abc`) and a
/// percent-encoded (e.g. Persian) name. Only the final segment is shown, with
/// the query/fragment stripped and the name decoded, so a token or a raw path
/// never reaches the screen.
String fileNameLabel(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  // Drop a query string or fragment: a token must never appear in the label.
  var path = text;
  for (final marker in ['?', '#']) {
    final cut = path.indexOf(marker);
    if (cut >= 0) path = path.substring(0, cut);
  }
  // A trailing separator would otherwise yield an empty final segment.
  while (path.endsWith('/') || path.endsWith('\\')) {
    path = path.substring(0, path.length - 1);
  }
  final slash = path.lastIndexOf('/');
  final backslash = path.lastIndexOf('\\');
  final separator = slash > backslash ? slash : backslash;
  final name = separator >= 0 ? path.substring(separator + 1) : path;
  return _decode(name);
}

/// The display names of a file field value: a single reference or a list of
/// them, joined with «، ». Returns '' for an empty value.
String fileNamesLabel(dynamic value) {
  if (value == null || value == '') return '';
  final names = value is List ? value : [value];
  return names.map((name) => fileNameLabel('$name')).join('، ');
}

/// Percent-decode a file name, falling back to the raw text when it is not a
/// valid percent-encoded string (e.g. a literal `100% done.pdf`).
String _decode(String name) {
  try {
    return Uri.decodeFull(name);
  } on ArgumentError {
    return name;
  }
}
