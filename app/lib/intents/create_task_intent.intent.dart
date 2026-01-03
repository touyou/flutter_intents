// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint

part of 'create_task_intent.dart';

// **************************************************************************
// AppIntentsGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND

/// Initialize all App Intents handlers.
void initializeCreateTaskAppIntents() {
  _registerCreateTaskIntentHandlers();
}

void _registerCreateTaskIntentHandlers() {
  AppIntents().registerIntentHandler('com.example.taskapp.createTask', (
    params,
  ) async {
    final title = params['title'] as String;
    final description = params['description'] as String?;
    final dueDateRaw = params['dueDate'] as String?;
    final dueDate = dueDateRaw != null ? DateTime.parse(dueDateRaw) : null;
    final result = await createTaskIntentHandler(
      title: title,
      description: description,
      dueDate: dueDate,
    );
    return result.toJson();
  });
}
