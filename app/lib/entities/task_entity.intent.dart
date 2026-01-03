// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint

part of 'task_entity.dart';

// **************************************************************************
// AppIntentsGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND

/// Initialize all App Intents handlers.
void initializeTaskAppIntents() {
  _registerTaskEntityHandlers();
}

void _registerTaskEntityHandlers() {
  AppIntents().registerEntityQueryHandler('com.example.taskapp.TaskEntity', (
    identifiers,
  ) async {
    final entities = await taskEntityQuery(identifiers);
    return entities.map((e) => e.toJson()).toList();
  });
}
