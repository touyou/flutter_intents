// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint

part of 'complete_task_intent.dart';

// **************************************************************************
// AppIntentsGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND

class CompleteTaskIntentParams {
  final String task;

  const CompleteTaskIntentParams({required this.task});

  factory CompleteTaskIntentParams.fromMap(Map<String, dynamic> map) {
    return CompleteTaskIntentParams(task: map['task'] as String);
  }
  factory CompleteTaskIntentParams.fromQueryParameters(
    Map<String, String> params,
  ) {
    return CompleteTaskIntentParams(task: params['task']!);
  }
}

/// Initialize all App Intents handlers.
void initializeCompleteTaskAppIntents() {
  _registerCompleteTaskIntentHandlers();
}

void _registerCompleteTaskIntentHandlers() {
  AppIntents().registerIntentHandler('com.example.taskapp.completeTask', (
    params,
  ) async {
    final p = CompleteTaskIntentParams.fromMap(params);
    await completeTaskIntentHandler(task: p.task);
    return <String, dynamic>{};
  });
}
