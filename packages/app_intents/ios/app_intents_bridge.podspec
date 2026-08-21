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
# The same sources are also the `AppIntentsBridge` product of the plugin's own
# Swift package (`app_intents/Package.swift`), which is how SPM projects get
# them. See `docs/usage.md` → "Consuming AppIntentsBridge".
#
# Run `pod lib lint app_intents_bridge.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'app_intents_bridge'
  # Without this, CocoaPods derives the module name from `s.name` and the
  # generated modulemap says `framework module app_intents_bridge`, so
  # `import AppIntentsBridge` — what the SPM routes and the
  # `generate_widget_swift` output both use — does not resolve (#105). The
  # symptom is indirect: the import itself may not report `No such module`,
  # only the types come out as `Cannot find 'AppIntentsEntityCache' in scope`.
  s.module_name      = 'AppIntentsBridge'
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
  # Shared source location with the plugin's Swift Package Manager manifest
  # (app_intents/Package.swift), so CocoaPods and SPM build the same files.
  # `app_intents.podspec` globs `app_intents/Sources/app_intents/**` only, so
  # this sibling directory is never compiled into both pods.
  s.source_files = 'app_intents/Sources/AppIntentsBridge/**/*.swift'
  s.platform = :ios, '17.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
