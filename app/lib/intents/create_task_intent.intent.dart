// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint

part of 'create_task_intent.dart';

// **************************************************************************
// AppIntentsGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND

class CreateTaskIntentParams {
  final String title;
  final String? description;
  final DateTime? dueDate;

  const CreateTaskIntentParams({
    required this.title,
    this.description,
    this.dueDate,
  });

  factory CreateTaskIntentParams.fromMap(Map<String, dynamic> map) {
    return CreateTaskIntentParams(
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : null,
    );
  }
  factory CreateTaskIntentParams.fromQueryParameters(
    Map<String, String> params,
  ) {
    return CreateTaskIntentParams(
      title: params['title']!,
      description: params['description'],
      dueDate: params['dueDate'] != null
          ? DateTime.tryParse(params['dueDate']!)
          : null,
    );
  }
}

/// Initialize all App Intents handlers.
void initializeCreateTaskAppIntents() {
  _registerCreateTaskIntentHandlers();
}

void _registerCreateTaskIntentHandlers() {
  AppIntents().registerIntentHandler('com.example.taskapp.createTask', (
    params,
  ) async {
    final p = CreateTaskIntentParams.fromMap(params);
    await createTaskIntentHandler(
      title: p.title,
      description: p.description,
      dueDate: p.dueDate,
    );
    return <String, dynamic>{};
  });
}
