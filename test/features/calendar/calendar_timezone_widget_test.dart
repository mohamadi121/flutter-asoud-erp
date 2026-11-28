import 'package:asoud_erp/core/theme/asoud_theme.dart';
import 'package:asoud_erp/features/calendar/calendar_page.dart';
import 'package:asoud_erp/features/calendar/calendar_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCalendarRepository extends Mock implements CalendarRepository {}

void main() {
  late _MockCalendarRepository repository;

  setUpAll(() {
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    repository = _MockCalendarRepository();
    when(() => repository.notificationScope()).thenAnswer((_) async => 'scope');
    when(() => repository.load(any(), any(), refreshRemote: any(named: 'refreshRemote'))).thenAnswer(
      (_) async => {
        'company': 'دفتر آزمایشی',
        'year': 1405,
        'month': 1,
        'timezone': 'America/New_York',
        'official_status': 'اطلاعات تعطیلات دریافت شد.',
        'pending_count': 0,
        'days': <String, dynamic>{},
        'alerts': <dynamic>[],
        'reminders': <dynamic>[],
        'items': <dynamic>[],
      },
    );
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('Calendar displays time zone in Persian at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // On 2026-03-21, America/New_York is in Daylight Saving Time (EDT = UTC-4)
      await tester.pumpWidget(
        MaterialApp(
          theme: AsoudTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: AsoudCalendar(
                company: 'دفتر آزمایشی',
                repository: repository,
                now: DateTime(2026, 3, 21),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Raw IANA id America/New_York should NOT be shown
      expect(find.textContaining('America/New_York'), findsNothing);
      // Persian formatted name with Persian digits and dynamic DST offset must be shown: «نیویورک (UTC-۴:۰۰)»
      expect(find.text('منطقه زمانی: نیویورک (UTC-۴:۰۰)'), findsOneWidget);
    });
  }
}
