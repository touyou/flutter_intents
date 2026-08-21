import 'package:app_intents_annotations/app_intents_annotations.dart';

import '../entities/task_entity.dart';

/// Widget configuration intent for a Home Screen task widget (#98).
///
/// Generated into the Widget Extension target only:
///
/// ```bash
/// dart run app_intents_codegen:generate_widget_swift \
///   -o ios/TaskWidget/GeneratedIntents \
///   --app-group group.com.example.app \
///   --storage-identifier com.example.app
/// ```
///
/// The generated `TaskEntitySpecWidgetQuery` reads the App Group cache
/// `TaskRepository` already writes under
/// `com.example.taskapp.cache.tasks` — a Widget Extension cannot start a
/// Flutter engine, so there is no Dart round-trip available to it.
///
/// Note that this class has no handler and no `part` directive: nothing runs in
/// Dart, so no Dart code is generated for it.
@WidgetConfigurationSpec(
  identifier: 'com.example.taskapp.selectTask',
  title: 'Displayed task',
  description: 'Choose which task this widget shows.',
)
class SelectTaskWidgetConfig extends WidgetConfigurationSpecBase {
  /// The task the widget displays.
  ///
  /// Left unset, the widget falls back to whatever its timeline provider
  /// decides — see `generateDefaultResult` on [WidgetConfigurationSpec] for why
  /// no default is baked in.
  @WidgetParameter(title: 'Task', description: 'The task to display')
  final TaskEntitySpec? task;

  /// Whether the widget also shows completed tasks.
  @WidgetParameter(title: 'Show completed')
  final bool showCompleted;

  const SelectTaskWidgetConfig({this.task, this.showCompleted = false});
}
