// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint

part of 'create_task_with_image_intent.dart';

// **************************************************************************
// AppIntentsGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND

/// Initialize all App Intents handlers.
void initializeCreateTaskWithImageAppIntents() {
  _registerCreateTaskWithImageIntentHandlers();
}

void _registerCreateTaskWithImageIntentHandlers() {
  AppIntents().registerIntentHandler(
    'com.example.taskapp.createTaskWithImage',
    (params) async {
      final title = params['title'] as String;
      final imageRaw = params['image'] as Map?;
      final image = imageRaw != null
          ? IntentFile.fromMap(Map<String, dynamic>.from(imageRaw))
          : null;
      final result = await createTaskWithImageIntentHandler(
        title: title,
        image: image,
      );
      return result.toJson();
    },
  );
}
