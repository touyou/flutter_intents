import 'package:flutter_test/flutter_test.dart';
import 'package:app_intents/app_intents.dart';
import 'package:app_intents/app_intents_platform_interface.dart';
import 'package:app_intents/app_intents_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAppIntentsPlatform
    with MockPlatformInterfaceMixin
    implements AppIntentsPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AppIntentsPlatform initialPlatform = AppIntentsPlatform.instance;

  test('$MethodChannelAppIntents is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAppIntents>());
  });

  test('getPlatformVersion', () async {
    AppIntents appIntentsPlugin = AppIntents();
    MockAppIntentsPlatform fakePlatform = MockAppIntentsPlatform();
    AppIntentsPlatform.instance = fakePlatform;

    expect(await appIntentsPlugin.getPlatformVersion(), '42');
  });
}
