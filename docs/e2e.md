# Android end-to-end tests

`integration_test/app_test.dart` drives the real app: sign in, open «ثبت درخواست»,
choose the ready HR leave form, fill a daily leave request, verify the server
confirmation and its request number in «درخواست‌های من», then sign out.
No repositories or HTTP responses are replaced.

## Prerequisites

Use an isolated local bench and an already running Android emulator. This test
creates a real leave request; it does not delete business records. Review and
cancel the created request after each run. Repeated runs on the same day may
fail overlapping-leave validation; cancel the previous request first.

Prepare a dedicated user with dashboard access, a complete selected office,
an Employee linked to that user, and a department. Enable the ready leave
request type and configure exactly one available leave type with an allocation
covering today, sufficient balance, and a working approval route. The first
available leave type is selected. Employee-only accounts use a different home
screen and are outside this initial test's scope.

Use a fresh app installation with no saved session or remembered preview choice.
Do not use production credentials or production data. Start the local bench
separately following the project environment guide. Android reaches the host
through `10.0.2.2`; configure the bench listener and site routing so the chosen
URL resolves to `asoud.test` (verify it from the emulator). The bench port is
installation dependent; do not use the separate Playwright server by mistake.

## Run locally

Supply all three values only as Dart defines. There are no credential defaults.
Read credentials interactively so their values do not enter shell history:

```bash
export PATH="$HOME/frappe-dev/flutter/bin:$PATH"
read -r -p 'Bench URL from Android: ' ASOUD_E2E_URL
read -r -p 'Test user: ' ASOUD_E2E_USER
read -r -s -p 'Test password: ' ASOUD_E2E_PASSWORD
flock /tmp/flutter.lock flutter test --no-pub --timeout 60s \
  integration_test/app_test.dart -d emulator-5554 \
  --dart-define="ASOUD_E2E_URL=$ASOUD_E2E_URL" \
  --dart-define="ASOUD_E2E_USER=$ASOUD_E2E_USER" \
  --dart-define="ASOUD_E2E_PASSWORD=$ASOUD_E2E_PASSWORD"
unset ASOUD_E2E_URL ASOUD_E2E_USER ASOUD_E2E_PASSWORD
```

Avoid shell tracing and sharing verbose build logs. Dart defines are embedded in
the test build: do not distribute its APK or upload it as an artifact. If any
define is missing, the runner marks the test skipped with a Persian explanation.
The regular `test/` suite does not execute this device test.

## Manual CI proposal (disabled)

This is a commented proposal only, outside `.github/workflows`. A dedicated
runner would need an existing emulator, isolated bench and prepared fixture.

```yaml
# name: Android E2E (manual)
# on: workflow_dispatch
# jobs:
#   android-e2e:
#     runs-on: [self-hosted, asoud-e2e]
#     steps:
#       - uses: actions/checkout@v4
#       - run: >-
#           flock /tmp/flutter.lock flutter test --timeout 60s
#           integration_test/app_test.dart -d emulator-5554
#           --dart-define=ASOUD_E2E_URL="${{ secrets.ASOUD_E2E_URL }}"
#           --dart-define=ASOUD_E2E_USER="${{ secrets.ASOUD_E2E_USER }}"
#           --dart-define=ASOUD_E2E_PASSWORD="${{ secrets.ASOUD_E2E_PASSWORD }}"
```

Production changes are limited to the existing login widgets' stable Keys:
`username_field`, `password_field`, `login_button`. All other selectors use
existing Keys, field definitions or exact Persian labels.
