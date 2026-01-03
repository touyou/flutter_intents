import 'dart:async';

import 'package:build/build.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';

import 'analyzer/entity_analyzer.dart';
import 'analyzer/intent_analyzer.dart';
import 'generator/dart_generator.dart';
import 'models/entity_info.dart';
import 'models/intent_info.dart';

/// Creates an [AppIntentsBuilder] for use with build_runner.
Builder appIntentsBuilder(BuilderOptions options) => PartBuilder(
      [AppIntentsGenerator()],
      '.intent.dart',
      header: '// coverage:ignore-file\n// ignore_for_file: type=lint',
    );

/// Generator that processes @IntentSpec and @EntitySpec annotations
/// and generates Dart handler registration code.
class AppIntentsGenerator extends Generator {
  final IntentAnalyzer _intentAnalyzer = const IntentAnalyzer();
  final EntityAnalyzer _entityAnalyzer = const EntityAnalyzer();
  final DartGenerator _dartGenerator = const DartGenerator();

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

    // Extract base name from file path for unique function names
    final fileName = path.basenameWithoutExtension(buildStep.inputId.path);
    final baseName = _toBaseName(fileName);

    // Generate Dart handler registration code
    return _dartGenerator.generate(intents, entities, baseName: baseName);
  }

  /// Converts a file name to a base name suitable for function naming.
  /// e.g., "create_task_intent" -> "createTaskIntent"
  String _toBaseName(String fileName) {
    // Remove common suffixes
    var name = fileName;
    for (final suffix in ['_intent', '_entity', '_spec']) {
      if (name.endsWith(suffix)) {
        name = name.substring(0, name.length - suffix.length);
      }
    }
    // Convert snake_case to camelCase
    final parts = name.split('_');
    return parts.first +
        parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
  }
}
