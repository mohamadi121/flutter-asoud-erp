import 'package:flutter/foundation.dart';

const bool kAsoudSetupReset =
    bool.fromEnvironment('ASOUD_SETUP_RESET', defaultValue: false) || kDebugMode;
