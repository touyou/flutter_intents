import 'dart:async';

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'analyzer/entity_analyzer.dart';
import 'analyzer/intent_analyzer.dart';
import 'generator/dart_generator.dart';
import 'models/entity_info.dart';
import 'models/intent_info.dart';

/// Creates an [AppIntentsBuilder] for use with build_runner.
Builder appIntentsBuilder(BuilderOptions options) => LibraryBuilder(
      AppIntentsGenerator(),
      generatedExtension: '.intent.dart',
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

    // Generate Dart handler registration code
    return _dartGenerator.generate(intents, entities);
  }
}
