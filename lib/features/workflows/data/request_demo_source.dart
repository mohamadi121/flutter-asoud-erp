/// Extra demo data for the offline preview (no session), registered by
/// features that own request templates. The repository merges every
/// registered source in local mode (`GenericRequestRepository.isLocal`) and
/// never in an authenticated session.
///
/// Every request map a source returns must carry `is_sample: true`; rows
/// without it are treated as the user's own data (and could be transferred to
/// a server by the demo transfer).
library;

abstract class RequestDemoSource {
  /// Request types in the `request_options` shape (§4.1): `name`,
  /// `workflow_title`, `template_key`, `fields`, ...
  List<Map> requestTypes();

  /// Requests in the `get_request` shape (§4.7). `summary`, `status_key`,
  /// `status_group` etc. are used by list cards; `values` and `attachments`
  /// by the detail page.
  List<Map> requests();

  /// Comments of request [name] in the `list_request_comments` shape.
  List<Map> comments(String name);

  /// Master data for `request_field_options`, keyed by the `field_type`
  /// (`Item`, `Cost Center`, `Project`, `Warehouse`, `Branch`, `Supplier`,
  /// `Leave Type`, `Delivery Location`, ...). A key present here replaces the
  /// repository's built-in samples for that field type.
  Map<String, List<Map>> fieldOptions();
}

class RequestDemoRegistry {
  RequestDemoRegistry._();

  static final List<RequestDemoSource> _sources = [];

  /// Adds [source]; registering the same instance twice is a no-op.
  static void register(RequestDemoSource source) {
    if (!_sources.contains(source)) _sources.add(source);
  }

  static void unregister(RequestDemoSource source) => _sources.remove(source);

  /// Removes every source (tests).
  static void clear() => _sources.clear();

  static List<RequestDemoSource> get sources => List.unmodifiable(_sources);

  static List<Map<String, dynamic>> _all(Iterable<Iterable<Map>> lists) => [
        for (final list in lists)
          for (final row in list) Map<String, dynamic>.from(row)
      ];

  static List<Map<String, dynamic>> requestTypes() =>
      _all(_sources.map((source) => source.requestTypes()));

  static List<Map<String, dynamic>> requests() =>
      _all(_sources.map((source) => source.requests()));

  static List<Map<String, dynamic>> comments(String name) =>
      _all(_sources.map((source) => source.comments(name)));

  /// Rows registered for [fieldType], or null when no source has any.
  static List<Map<String, dynamic>>? fieldOptions(String fieldType) {
    final lists = [
      for (final source in _sources)
        if (source.fieldOptions().containsKey(fieldType))
          source.fieldOptions()[fieldType]!
    ];
    return lists.isEmpty ? null : _all(lists);
  }
}
