// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint

part of 'create_task_with_image_intent.dart';

// **************************************************************************
// AppIntentsGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND

class CreateTaskWithImageIntentParams {
  final String title;
  final IntentFile? image;

  const CreateTaskWithImageIntentParams({required this.title, this.image});

  factory CreateTaskWithImageIntentParams.fromMap(Map<String, dynamic> map) {
    return CreateTaskWithImageIntentParams(
      title: map['title'] as String,
      image: map['image'] != null
          ? IntentFile.fromMap(Map<String, dynamic>.from(map['image'] as Map))
          : null,
    );
  }
  factory CreateTaskWithImageIntentParams.fromQueryParameters(
    Map<String, String> params,
  ) {
    return CreateTaskWithImageIntentParams(
      title: params['title']!,
      image: null,
    );
  }
}

/// Initialize all App Intents handlers.
void initializeCreateTaskWithImageAppIntents() {
  _registerCreateTaskWithImageIntentHandlers();
}

void _registerCreateTaskWithImageIntentHandlers() {
  AppIntents().registerIntentHandler(
    'com.example.taskapp.createTaskWithImage',
    (params) async {
      final p = CreateTaskWithImageIntentParams.fromMap(params);
      await createTaskWithImageIntentHandler(title: p.title, image: p.image);
      return <String, dynamic>{};
    },
  );
}
