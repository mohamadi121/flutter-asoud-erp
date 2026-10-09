import '../../workflows/data/request_demo_source.dart';
import 'demo_requests.dart';
import 'system_templates.dart';

/// The offline-preview rows of the three system templates (CONTRACT §6.6):
/// their request types with the exact §3 field definitions and the demo
/// requests that reproduce the mockups. The sample masters (items, leave
/// types, delivery locations, ...) come from the repository's built-in
/// samples, so [fieldOptions] adds nothing.
class TemplatesDemoSource implements RequestDemoSource {
  TemplatesDemoSource({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;

  @override
  List<Map> requestTypes() => [
        for (final key in SystemTemplateKeys.all) systemRequestType(key),
      ];

  @override
  List<Map> requests() => demoTemplateRequests(_clock());

  @override
  List<Map> comments(String name) => demoTemplateComments(name, _clock());

  @override
  Map<String, List<Map>> fieldOptions() => const {};
}
