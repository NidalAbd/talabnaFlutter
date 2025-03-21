import 'package:flutter/services.dart';
import 'package:restart_app/restart_app.dart';

class RestartHelper {
  static void restartApp() {
    try {
      Restart.restartApp(); // Works on both Android & iOS
    } catch (e) {
      print("Error restarting app: $e");
      SystemNavigator.pop(); // Fallback for Android
    }
  }
}
