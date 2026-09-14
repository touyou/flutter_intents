// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint

part of 'task_summary_intent.dart';

// **************************************************************************
// AppIntentsGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND

/// Initialize all App Intents handlers.
void initializeTaskSummaryAppIntents() {
  _registerTaskSummaryIntentHandlers();
}

void _registerTaskSummaryIntentHandlers() {
  AppIntents().registerIntentHandler('com.example.taskapp.taskSummary', (
    params,
  ) async {
    final result = await taskSummaryIntentHandler();
    return intentResultPayload(result);
  });
}
