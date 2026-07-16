import 'package:asoud_erp/features/base_setup/domain/entities/setup_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('اولین مرحله ناقص راه‌اندازی انتخاب می‌شود', () {
    expect(const SetupStatus().nextStep, SetupStep.office);
    expect(const SetupStatus(officeSaved: true).nextStep, SetupStep.accounting);
    expect(
      const SetupStatus(officeSaved: true, accountingSaved: true).nextStep,
      SetupStep.roles,
    );
    expect(
      const SetupStatus(officeSaved: true, accountingSaved: true, rolesSaved: true).nextStep,
      SetupStep.complete,
    );
  });
}
