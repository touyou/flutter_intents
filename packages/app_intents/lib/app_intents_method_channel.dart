import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_intents_platform_interface.dart';

/// An implementation of [AppIntentsPlatform] that uses method channels.
class MethodChannelAppIntents extends AppIntentsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('app_intents');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
