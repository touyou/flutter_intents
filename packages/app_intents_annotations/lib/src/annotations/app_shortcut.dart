/// App Shortcutを定義するためのアノテーション
///
/// AppShortcutsProviderを生成し、アプリインストール直後から
/// Siri/Spotlightで利用可能にします。
///
/// iOS 16以降で利用可能です。
///
/// Example:
/// ```dart
/// @AppShortcut(
///   intentIdentifier: 'CreateTaskIntent',
///   phrases: ['Create a task in {applicationName}', 'Add task'],
///   shortTitle: 'Create Task',
///   systemImageName: 'plus.circle',
/// )
/// class CreateTaskShortcut {}
/// ```
class AppShortcut {
  /// ショートカットに関連付けるIntentの識別子
  final String intentIdentifier;

  /// Siriが認識するフレーズ一覧
  ///
  /// 特殊な変数として `{applicationName}` を使用できます。
  /// 例: ["Create a task in {applicationName}", "Add task"]
  final List<String> phrases;

  /// 短いタイトル（Shortcuts.appで表示）
  final String shortTitle;

  /// SF Symbolシステムアイコン名
  ///
  /// iOS標準のSF Symbolから選択します。
  /// 例: "plus.circle", "checkmark.circle", "star.fill"
  final String? systemImageName;

  const AppShortcut({
    required this.intentIdentifier,
    required this.phrases,
    required this.shortTitle,
    this.systemImageName,
  });
}

/// AppShortcutsProviderを定義するクラスに付与するアノテーション
///
/// このアノテーションが付与されたクラスは、アプリのショートカットを
/// 一元管理するProviderとして機能します。
///
/// iOS 16以降で利用可能です。
///
/// Example:
/// ```dart
/// @AppShortcutsProvider()
/// class MyAppShortcuts {
///   @AppShortcut(
///     intentIdentifier: 'CreateTaskIntent',
///     phrases: ['Create a task'],
///     shortTitle: 'Create Task',
///   )
///   static const createTask = null;
/// }
/// ```
class AppShortcutsProvider {
  const AppShortcutsProvider();
}
