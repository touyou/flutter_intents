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
import 'package:app_intents_codegen/src/models/snippet_info.dart';
import 'package:app_intents_codegen/src/models/union_info.dart';

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
    importable: true, // #129 — exporting: + importing: in one representation
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
    // #133: IndexedEntity + IndexedEntityQuery re-indexing.
    indexed: true,
    // #51 on a schema entity: the query must follow the entity into BOTH
    // branches (iOS 27 in the #if, iOS 26 in the #else) or it would reference
    // a type newer than itself.
    valueQuery: true,
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

  // Entities exercising the extended export catalog (#128): a place built from
  // coordinate + address export fields, and a currency amount. Both throw from
  // the export closure, which is what forces the AppIntentsBridge import.
  const storeEntity = EntityInfo(
    className: 'StoreEntity',
    identifier: 'com.example.app.StoreEntity',
    title: 'Store',
    pluralTitle: 'Stores',
    exportAs: EntityExportKind.place, // #128
    importable: true, // #129
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
      // Optional coordinate halves and a non-optional address, so the emitted
      // optional-normalizing locals are exercised in both shapes.
      EntityPropertyInfo(
        fieldName: 'latitude',
        dartType: 'double?',
        role: EntityPropertyRole.none,
        exportRole: EntityExportRoleKind.latitude,
      ),
      EntityPropertyInfo(
        fieldName: 'longitude',
        dartType: 'double?',
        role: EntityPropertyRole.none,
        exportRole: EntityExportRoleKind.longitude,
      ),
      EntityPropertyInfo(
        fieldName: 'address',
        dartType: 'String',
        role: EntityPropertyRole.none,
        exportRole: EntityExportRoleKind.address,
      ),
    ],
  );

  // Entity exercising the dual identifier (#132): a local id paired with a
  // server-assigned stable one. The whole entity + query dual-branches, since
  // SyncableEntityIdentifier is iOS 27 only.
  const deviceEntity = EntityInfo(
    className: 'DeviceEntity',
    identifier: 'com.example.app.DeviceEntity',
    title: 'Device',
    pluralTitle: 'Devices',
    syncable: true,
    relevantEntities: true,
    properties: [
      EntityPropertyInfo(
        fieldName: 'localId',
        dartType: 'String',
        role: EntityPropertyRole.id,
      ),
      EntityPropertyInfo(
        fieldName: 'name',
        dartType: 'String',
        role: EntityPropertyRole.title,
      ),
      EntityPropertyInfo(
        fieldName: 'serverId',
        dartType: 'String',
        role: EntityPropertyRole.none,
        isStableId: true,
      ),
    ],
  );

  // Union returning several entity types from one IntentValueQuery (#133).
  const searchResult = UnionInfo(
    className: 'SearchResult',
    identifier: 'com.example.app.SearchResult',
    valueQuery: true,
    cases: [
      UnionCaseInfo(dartClassName: 'ProductResult', entityType: 'ProductEntity'),
      UnionCaseInfo(dartClassName: 'MessageResult', entityType: 'MessageEntity'),
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
    // A `{result.…}` template on a long-running intent: the invoke runs inside
    // the wrapper closure, so the payload must be bound outside it or the
    // interpolation locals are out of scope at the return statement.
    resultDialogTemplate: 'Sent to {result.recipient}',
    snippet: SnippetInfo(
      title: '{result.recipient}',
      rows: [SnippetRowInfo(label: 'Status', value: '{result.status}')],
    ),
    parameters: [
      IntentParamInfo(
        fieldName: 'text',
        dartType: 'String',
        title: 'Text',
        isOptional: false,
      ),
      // #131: an optional parameter the handler can ask the system to prompt
      // for mid-run. iOS 16 API, so it must compile in BOTH branches.
      IntentParamInfo(
        fieldName: 'note',
        dartType: 'String?',
        title: 'Note',
        isOptional: true,
        requestValue: true,
      ),
      IntentParamInfo(
        fieldName: 'due',
        dartType: 'DateTime?',
        title: 'Due',
        isOptional: true,
        requestValue: true,
      ),
    ],
  );

  // Intent exercising the dual-text + symbol result dialog (ADR 0006). Not
  // experimental — `IntentDialog(full:supporting:)` is iOS 16 and the symbol
  // form is iOS 17.2, reached through an `if #available` — but it still has to
  // compile, and only a typecheck proves the availability dance is right.
  const dialogIntent = IntentInfo(
    className: 'AnnounceTaskIntent',
    identifier: 'com.example.app.announceTask',
    title: 'Announce Task',
    implementation: IntentImplementationType.dart,
    resultDialogTemplate: 'I created the task {title}',
    resultDialogSupportingTemplate: 'Task created',
    resultDialogSystemImageName: 'checkmark.circle',
    // ADR 0007: the declarative snippet card, reading both an intent parameter
    // and a key of the Dart handler's result.
    snippet: SnippetInfo(
      title: '{title}',
      subtitle: 'Saved to {result.listName}',
      systemImageName: 'checkmark.circle.fill',
      rows: [
        SnippetRowInfo(label: 'Due', value: '{result.dueDate}'),
        SnippetRowInfo(label: 'List', value: 'Inbox'),
      ],
    ),
    parameters: [
      IntentParamInfo(
        fieldName: 'title',
        dartType: 'String',
        title: 'Title',
        isOptional: false,
      ),
    ],
  );

  final swift = gen.generateAll(
    intents: [sendIntent, dialogIntent],
    entities: [productEntity, messageEntity, storeEntity, deviceEntity],
    unions: [searchResult],
  );

  File(out).writeAsStringSync('// GENERATED FOR VERIFICATION ONLY\n$swift\n');
  stdout.writeln('Wrote $out');
}
