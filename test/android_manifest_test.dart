import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifest;

  setUpAll(() {
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  });

  test('release manifest declares the INTERNET permission', () {
    expect(
      manifest,
      contains(
        '<uses-permission android:name="android.permission.INTERNET"/>',
      ),
    );
  });

  test('release manifest allows cleartext HTTP traffic', () {
    expect(manifest, contains('android:usesCleartextTraffic="true"'));
  });

  test('INTERNET permission sits outside <application>', () {
    expect(
      manifest.indexOf('android.permission.INTERNET'),
      lessThan(manifest.indexOf('<application')),
    );
  });
}
