import 'package:asoud_erp/core/widgets/template_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TemplateTextController.loadSource', () {
    test('a fresh body is not decoded through the previous body\'s token map', () {
      final controller = TemplateTextController({
        '{{employee.employee_name}}': 'نام و نام خانوادگی',
      });
      addTearDown(controller.dispose);

      // Clause A allocates U+E000 -> {{employee.employee_name}}.
      controller.loadSource('سلام {{employee.employee_name}}');
      expect(controller.source, 'سلام {{employee.employee_name}}');

      // Clause B literally contains the private-use char U+E000. Before the fix
      // the stale _tokens entry decoded it back into clause A's token, silently
      // rewriting the stored text. It must stay a literal character.
      const literal = 'متن \u{e000} واقعی';
      controller.loadSource(literal);
      expect(controller.source, literal);
    });

    test('reloading the same token reuses a fresh marker, not a stale one', () {
      final controller = TemplateTextController({
        '{{employee.employee_name}}': 'نام و نام خانوادگی',
      });
      addTearDown(controller.dispose);

      controller.loadSource('اول {{employee.employee_name}}');
      controller.loadSource('دوم {{employee.employee_name}}');
      // The token round-trips byte-for-byte after a reload.
      expect(controller.source, 'دوم {{employee.employee_name}}');
    });
  });
}
