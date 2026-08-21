#
# Standalone pod for the `AppIntentsBridge` Swift module.
#
# Deliberately separate from `app_intents.podspec`: the generated
# `WidgetConfigurationIntent` code imports `AppIntentsBridge` from a Widget
# Extension target, and extension targets do not take part in
# `flutter_install_all_ios_pods` (they must not link Flutter). This pod carries
# no Flutter dependency, so it can be added to such a target on its own:
#
#   target 'MyWidgetExtension' do
#     use_frameworks!
#     pod 'app_intents_bridge', :path => '.symlinks/plugins/app_intents/ios'
#   end
#
# Declare it *after* the Runner target block — `.symlinks/plugins` is created
# by `flutter_install_all_ios_pods` while the Podfile is being evaluated.
#
# The same sources are also reachable as a Swift package: this directory's
# `AppIntentsBridge/Package.swift` (local), or the repository root manifest
# (`.package(url:)`). See `docs/usage.md` → "Consuming AppIntentsBridge".
#
# Run `pod lib lint app_intents_bridge.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'app_intents_bridge'
  s.version          = '0.14.0'
  s.summary          = 'Flutter-free Swift bridge shared by the app_intents plugin and its App Extensions.'
  s.description      = <<-DESC
The Swift side of the app_intents Flutter plugin: the FlutterBridge executor
registry, the App Intents error types, and the read-only App Group entity cache
used by generated WidgetConfigurationIntent code. Contains no Flutter
dependency so that App Extension targets can link it.
                       DESC
  s.homepage         = 'https://github.com/touyou/flutter_intents'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'touyou' => 'https://github.com/touyou' }
  s.source           = { :path => '.' }
  # Shared source location with the Swift Package Manager manifest
  # (AppIntentsBridge/Package.swift) so CocoaPods and SPM build the same files.
  s.source_files = 'AppIntentsBridge/Sources/AppIntentsBridge/**/*.swift'
  s.platform = :ios, '17.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
