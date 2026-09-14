import 'package:app_intents_codegen/src/generator/widget_swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/widget_configuration_info.dart';
import 'package:test/test.dart';

const _generator = WidgetSwiftGenerator(
  appGroupIdentifier: 'group.com.example.app',
  storageIdentifier: 'com.example.app',
);

const _entity = EntityInfo(
  className: 'TaskEntitySpec',
  identifier: 'com.example.task',
  title: 'Task',
  pluralTitle: 'Tasks',
  enumerable: true,
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
  ],
);

WidgetConfigurationInfo _config({bool relevantIntents = false}) =>
    WidgetConfigurationInfo(
      className: 'SelectTaskWidgetConfig',
      identifier: 'com.example.taskapp.selectTask',
      title: 'Displayed task',
      relevantIntents: relevantIntents,
      parameters: const [
        WidgetParamInfo(
          name: 'task',
          dartType: 'TaskEntitySpec?',
          title: 'Task',
          entityType: 'TaskEntitySpec',
        ),
        WidgetParamInfo(
          name: 'showCompleted',
          dartType: 'bool',
          title: 'Show completed',
        ),
      ],
    );

String _generate({bool relevantIntents = false}) => _generator.generateAll(
  configurations: [_config(relevantIntents: relevantIntents)],
  entities: const [_entity],
);

void main() {
  group('WidgetSwiftGenerator relevant intents (#55)', () {
    test('emits nothing without the opt-in', () {
      final result = _generate();
      expect(result, isNot(contains('RelevantIntent')));
      expect(result, isNot(contains('import RelevanceKit')));
    });

    test('emits one donator for the whole file, not one per configuration', () {
      // updateRelevantIntents replaces the app's entire set, so a second
      // registration would erase the first one's donations.
      final result = _generate(relevantIntents: true);
      expect(
        'func registerRelevantIntentDonator()'.allMatches(result).length,
        1,
      );
      expect('updateRelevantIntents('.allMatches(result).length, 1);
    });

    test('imports RelevanceKit and registers through the bridge', () {
      final result = _generate(relevantIntents: true);
      expect(result, contains('import RelevanceKit'));
      expect(
        result,
        contains('await FlutterBridge.shared.setRelevantIntentDonator'),
      );
      expect(result, contains('case "com.example.taskapp.selectTask":'));
    });

    test('resolves an entity parameter through the cache-backed query', () {
      // Only the identifier crosses the channel; the donated intent should
      // still carry a fully formed entity.
      final result = _generate(relevantIntents: true);
      expect(
        result,
        contains(
          'intent.task = try? await TaskEntitySpecWidgetQuery()'
          '.entities(for: [id]).first',
        ),
      );
    });

    test('leaves a scalar parameter alone when the donation omits it', () {
      final result = _generate(relevantIntents: true);
      expect(
        result,
        contains('if let value = parameters["showCompleted"] as? Bool {'),
      );
    });

    test('gates the iOS 26 date kinds behind an availability check', () {
      final result = _generate(relevantIntents: true);
      expect(result, contains('if #available(iOS 26.0, *)'));
      expect(result, contains('return .date(date)'));
      expect(result, contains('func appIntentsRelevantDateKind('));
      // `standard` is spelled `default` in Swift; Dart cannot use that word.
      expect(result, contains('default: return .default'));
    });

    test('has no case for CLRegion locations', () {
      // A CLRegion cannot be rebuilt from a dictionary, so offering it would
      // produce donations the system silently drops.
      final result = _generate(relevantIntents: true);
      expect(result, isNot(contains('CLRegion')));
      expect(result, contains('case "inferredLocation":'));
    });

    test('emits no leaked Dart interpolation', () {
      // String assertions cannot see a broken indent helper; this is the cheap
      // half of that guard, the Swift typecheck is the real one.
      final result = _generate(relevantIntents: true);
      expect(result, isNot(contains(r'${')));
      expect(result, isNot(contains(r'$_indent')));
    });
  });
}
