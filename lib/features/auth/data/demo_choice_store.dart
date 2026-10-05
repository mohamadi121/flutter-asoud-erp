import 'package:shared_preferences/shared_preferences.dart';

/// Remembers that the user chose the offline demo preview on the login page,
/// so the splash can open it directly next time.
class DemoChoiceStore {
  static const key = 'asoud_demo_preview_choice_v1';

  static Future<bool> isDemoChosen() async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? false;

  static Future<void> setDemoChosen(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(key, value);
}
