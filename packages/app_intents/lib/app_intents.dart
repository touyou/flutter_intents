
import 'app_intents_platform_interface.dart';

class AppIntents {
  Future<String?> getPlatformVersion() {
    return AppIntentsPlatform.instance.getPlatformVersion();
  }
}
