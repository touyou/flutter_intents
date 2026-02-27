// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint

part of 'complete_task_intent.dart';

// **************************************************************************
// AppIntentsGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND

/// Initialize all App Intents handlers.
void initializeCompleteTaskAppIntents() {
  _registerCompleteTaskIntentHandlers();
}

void _registerCompleteTaskIntentHandlers() {
  AppIntents().registerIntentHandler('com.example.taskapp.completeTask', (
    params,
  ) async {
    final task = params['task'] as String;
    final result = await completeTaskIntentHandler(task: task);
    return result?.toJson() ?? <String, dynamic>{};
  });
}
