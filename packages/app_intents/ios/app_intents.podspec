#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint app_intents.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'app_intents'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin for iOS App Intents integration.'
  s.description      = <<-DESC
Flutter plugin for iOS App Intents integration. Enables Siri, Shortcuts, and Spotlight support.
                       DESC
  s.homepage         = 'https://github.com/touyou/flutter_intents'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'touyou' => 'https://github.com/touyou' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'app_intents_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
