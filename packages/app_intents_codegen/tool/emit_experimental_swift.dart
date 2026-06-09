// Verification helper: emits a Swift file exercising the WWDC26 experimental
// features so it can be `swiftc -typecheck`ed against the beta iOS 27 SDK —
// the load-bearing check (golden tests only assert the emitted strings, not
// that they compile). Driven by `scripts/verify_experimental_swift.sh`.
//
// Usage: dart run tool/emit_experimental_swift.dart <out.swift>
//
// Avoids cache-key features (enumerable/indexed/persistedCacheKey) so the
// output references only AppIntents + AppIntentsBridge (FlutterBridge), not the
// Flutter plugin module, keeping the typecheck self-contained.
import 'dart:io';

import 'package:app_intents_codegen/src/experimental/experimental_features.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';

void main(List<String> args) {
  final out = args.isNotEmpty ? args.first : 'GeneratedVerify.swift';

  const gen = SwiftGenerator(
    experimental: ExperimentalFeatures(masterEnabled: true),
  );

  // Entity exercising the four new entity-level features (#51/#54/#55) with no
  // cache-key features, so it stays iOS 17 base + additive #if blocks.
  const productEntity = EntityInfo(
    className: 'ProductEntity',
    identifier: 'com.example.app.ProductEntity',
    title: 'Product',
    pluralTitle: 'Products',
    valueQuery: true, // #51
    exportAs: EntityExportKind.person, // #54
    syncable: true, // #55 SyncableEntity
    relevantEntities: true, // #55 RelevantEntities donator
    properties: [
      EntityPropertyInfo(
        fieldName: 'id',
        dartType: 'String',
        role: EntityPropertyRole.id,
      ),
      EntityPropertyInfo(
        fieldName: 'name',
        dartType: 'String',
        role: EntityPropertyRole.title,
      ),
      EntityPropertyInfo(
        fieldName: 'detail',
        dartType: 'String',
        role: EntityPropertyRole.subtitle,
      ),
    ],
  );

  // Entity exercising already-merged #49 schema + #55 ownership + #50 indexingKey
  // (regression guard), again without cache-key features.
  const messageEntity = EntityInfo(
    className: 'MessageEntity',
    identifier: 'com.example.app.MessageEntity',
    title: 'Message',
    pluralTitle: 'Messages',
    schema: 'messages.message', // #49
    ownership: EntityOwnershipType.shared, // #55 ownership
    properties: [
      EntityPropertyInfo(
        fieldName: 'id',
        dartType: 'String',
        role: EntityPropertyRole.id,
      ),
      EntityPropertyInfo(
        fieldName: 'title',
        dartType: 'String',
        role: EntityPropertyRole.title,
      ),
      EntityPropertyInfo(
        fieldName: 'body',
        dartType: 'String',
        role: EntityPropertyRole.none,
        exposeAsProperty: true, // #50 @Property
        propertyTitle: 'Body',
        indexingKey: 'contentDescription',
      ),
    ],
  );

  // Intent exercising #52 execution control + #49 schema.
  const sendIntent = IntentInfo(
    className: 'SendMessageIntent',
    identifier: 'com.example.app.sendMessage',
    title: 'Send Message',
    description: 'Sends a message',
    implementation: IntentImplementationType.dart,
    schema: 'messages.sendMessage', // #49
    longRunning: true, // #52
    cancellable: true, // #52
    parameters: [
      IntentParamInfo(
        fieldName: 'text',
        dartType: 'String',
        title: 'Text',
        isOptional: false,
      ),
    ],
  );

  final swift = gen.generateAll(
    intents: [sendIntent],
    entities: [productEntity, messageEntity],
  );

  File(out).writeAsStringSync('// GENERATED FOR VERIFICATION ONLY\n$swift\n');
  stdout.writeln('Wrote $out');
}
