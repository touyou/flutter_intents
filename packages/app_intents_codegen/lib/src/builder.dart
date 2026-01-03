import 'dart:async';

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'analyzer/entity_analyzer.dart';
import 'analyzer/intent_analyzer.dart';
import 'models/entity_info.dart';
import 'models/intent_info.dart';

/// Creates an [AppIntentsBuilder] for use with build_runner.
Builder appIntentsBuilder(BuilderOptions options) => LibraryBuilder(
      AppIntentsGenerator(),
      generatedExtension: '.intent.dart',
    );

/// Generator that processes @IntentSpec and @EntitySpec annotations
/// and generates Swift/Dart code.
class AppIntentsGenerator extends Generator {
  final IntentAnalyzer _intentAnalyzer = const IntentAnalyzer();
  final EntityAnalyzer _entityAnalyzer = const EntityAnalyzer();

  @override
  FutureOr<String?> generate(LibraryReader library, BuildStep buildStep) {
    final intents = <IntentInfo>[];
    final entities = <EntityInfo>[];

    for (final classElement in library.classes) {
      // Check for @IntentSpec annotation
      if (_intentAnalyzer.hasIntentSpecAnnotation(classElement)) {
        final intentInfo = _intentAnalyzer.analyze(classElement);
        if (intentInfo != null) {
          intents.add(intentInfo);
        }
      }

      // Check for @EntitySpec annotation
      if (_entityAnalyzer.hasEntitySpecAnnotation(classElement)) {
        final entityInfo = _entityAnalyzer.analyze(classElement);
        if (entityInfo != null) {
          entities.add(entityInfo);
        }
      }
    }

    if (intents.isEmpty && entities.isEmpty) {
      return null;
    }

    return _generateOutput(intents, entities);
  }

  String _generateOutput(List<IntentInfo> intents, List<EntityInfo> entities) {
    final buffer = StringBuffer();

    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln();
    buffer.writeln('// **************************************************************************');
    buffer.writeln('// AppIntentsGenerator');
    buffer.writeln('// **************************************************************************');
    buffer.writeln();

    // Generate intent information
    for (final intent in intents) {
      buffer.writeln('// Intent: ${intent.className}');
      buffer.writeln('// Identifier: ${intent.identifier}');
      buffer.writeln('// Title: ${intent.title}');
      if (intent.description != null) {
        buffer.writeln('// Description: ${intent.description}');
      }
      buffer.writeln('// Implementation: ${intent.implementation.name}');
      if (intent.inputType != null) {
        buffer.writeln('// Input Type: ${intent.inputType}');
      }
      if (intent.outputType != null) {
        buffer.writeln('// Output Type: ${intent.outputType}');
      }
      if (intent.parameters.isNotEmpty) {
        buffer.writeln('// Parameters:');
        for (final param in intent.parameters) {
          buffer.writeln('//   - ${param.fieldName}: ${param.dartType} (${param.title})');
        }
      }
      buffer.writeln();
    }

    // Generate entity information
    for (final entity in entities) {
      buffer.writeln('// Entity: ${entity.className}');
      buffer.writeln('// Identifier: ${entity.identifier}');
      buffer.writeln('// Title: ${entity.title}');
      buffer.writeln('// Plural Title: ${entity.pluralTitle}');
      if (entity.description != null) {
        buffer.writeln('// Description: ${entity.description}');
      }
      if (entity.modelType != null) {
        buffer.writeln('// Model Type: ${entity.modelType}');
      }
      if (entity.properties.isNotEmpty) {
        buffer.writeln('// Properties:');
        for (final prop in entity.properties) {
          buffer.writeln('//   - ${prop.fieldName}: ${prop.dartType} (${prop.role.name})');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
