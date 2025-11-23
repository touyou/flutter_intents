import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'app_intents_method_channel.dart';

abstract class AppIntentsPlatform extends PlatformInterface {
  /// Constructs a AppIntentsPlatform.
  AppIntentsPlatform() : super(token: _token);

  static final Object _token = Object();

  static AppIntentsPlatform _instance = MethodChannelAppIntents();

  /// The default instance of [AppIntentsPlatform] to use.
  ///
  /// Defaults to [MethodChannelAppIntents].
  static AppIntentsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AppIntentsPlatform] when
  /// they register themselves.
  static set instance(AppIntentsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
