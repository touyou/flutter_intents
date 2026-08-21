import 'package:app_intents_codegen/src/analyzer/widget_configuration_analyzer.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

/// A source prelude with an entity the widget configurations can reference.
const _entitySource = '''
import 'package:app_intents_annotations/app_intents_annotations.dart';

@EntitySpec(
  identifier: 'com.example.joinedTeam',
  title: 'Team',
  pluralTitle: 'Teams',
  enumerable: true,
)
class TeamEntitySpec extends EntitySpecBase<Object> {
  @EntityId()
  final String id;
  @EntityTitle()
  final String name;

  TeamEntitySpec({required this.id, required this.name});
}
''';

void main() {
  group('WidgetConfigurationAnalyzer', () {
    const analyzer = WidgetConfigurationAnalyzer();

    test('detects @WidgetConfigurationSpec', () async {
      final library = await resolveSource('''
$_entitySource

@WidgetConfigurationSpec(
  identifier: 'com.example.selectTeam',
  title: 'Displayed team',
)
class SelectTeamWidgetConfig extends WidgetConfigurationSpecBase {}
''');

      expect(
        analyzer.hasWidgetConfigurationSpecAnnotation(
          findClass(library, 'SelectTeamWidgetConfig'),
        ),
        isTrue,
      );
      expect(
        analyzer.hasWidgetConfigurationSpecAnnotation(
          findClass(library, 'TeamEntitySpec'),
        ),
        isFalse,
      );
    });

    test('extracts identifier, title, description and defaults', () async {
      final library = await resolveSource('''
$_entitySource

@WidgetConfigurationSpec(
  identifier: 'com.example.selectTeam',
  title: 'Displayed team',
  description: 'Choose which team this widget shows.',
)
class SelectTeamWidgetConfig extends WidgetConfigurationSpecBase {}
''');

      final info = analyzer.analyze(
        findClass(library, 'SelectTeamWidgetConfig'),
      )!;

      expect(info.className, 'SelectTeamWidgetConfig');
      expect(info.identifier, 'com.example.selectTeam');
      expect(info.title, 'Displayed team');
      expect(info.description, 'Choose which team this widget shows.');
      // Both default to false: a configuration intent should not clutter the
      // Shortcuts app, and defaultResult() breaks the global-setting fallback.
      expect(info.isDiscoverable, isFalse);
      expect(info.generateDefaultResult, isFalse);
      expect(info.parameters, isEmpty);
    });

    test('reads explicit isDiscoverable and generateDefaultResult', () async {
      final library = await resolveSource('''
$_entitySource

@WidgetConfigurationSpec(
  identifier: 'com.example.selectTeam',
  title: 'Displayed team',
  isDiscoverable: true,
  generateDefaultResult: true,
)
class SelectTeamWidgetConfig extends WidgetConfigurationSpecBase {}
''');

      final info = analyzer.analyze(
        findClass(library, 'SelectTeamWidgetConfig'),
      )!;

      expect(info.isDiscoverable, isTrue);
      expect(info.generateDefaultResult, isTrue);
    });

    test('infers entityType from an @EntitySpec-typed field', () async {
      final library = await resolveSource('''
$_entitySource

@WidgetConfigurationSpec(
  identifier: 'com.example.selectTeam',
  title: 'Displayed team',
)
class SelectTeamWidgetConfig extends WidgetConfigurationSpecBase {
  @WidgetParameter(title: 'Team', description: 'Which team to show')
  final TeamEntitySpec? team;

  SelectTeamWidgetConfig({this.team});
}
''');

      final info = analyzer.analyze(
        findClass(library, 'SelectTeamWidgetConfig'),
      )!;

      expect(info.parameters, hasLength(1));
      final param = info.parameters.single;
      expect(param.name, 'team');
      expect(param.title, 'Team');
      expect(param.description, 'Which team to show');
      expect(param.entityType, 'TeamEntitySpec');
      expect(param.isOptional, isTrue);
    });

    test('an explicit entityType wins over the declared type', () async {
      final library = await resolveSource('''
$_entitySource

@WidgetConfigurationSpec(
  identifier: 'com.example.selectTeam',
  title: 'Displayed team',
)
class SelectTeamWidgetConfig extends WidgetConfigurationSpecBase {
  @WidgetParameter(title: 'Team', entityType: 'TeamEntitySpec')
  final String? teamId;

  SelectTeamWidgetConfig({this.teamId});
}
''');

      final info = analyzer.analyze(
        findClass(library, 'SelectTeamWidgetConfig'),
      )!;

      expect(info.parameters.single.entityType, 'TeamEntitySpec');
    });

    test('leaves scalar parameters without an entity type', () async {
      final library = await resolveSource('''
$_entitySource

@WidgetConfigurationSpec(
  identifier: 'com.example.selectTeam',
  title: 'Displayed team',
)
class SelectTeamWidgetConfig extends WidgetConfigurationSpecBase {
  @WidgetParameter(title: 'Show completed')
  final bool showCompleted;

  SelectTeamWidgetConfig({this.showCompleted = false});
}
''');

      final info = analyzer.analyze(
        findClass(library, 'SelectTeamWidgetConfig'),
      )!;

      final param = info.parameters.single;
      expect(param.entityType, isNull);
      expect(param.dartType, 'bool');
      expect(param.isOptional, isFalse);
    });

    test('ignores fields without @WidgetParameter', () async {
      final library = await resolveSource('''
$_entitySource

@WidgetConfigurationSpec(
  identifier: 'com.example.selectTeam',
  title: 'Displayed team',
)
class SelectTeamWidgetConfig extends WidgetConfigurationSpecBase {
  @WidgetParameter(title: 'Team')
  final TeamEntitySpec? team;

  final String internalNote = '';

  SelectTeamWidgetConfig({this.team});
}
''');

      final info = analyzer.analyze(
        findClass(library, 'SelectTeamWidgetConfig'),
      )!;

      expect(info.parameters.map((p) => p.name), ['team']);
    });

    test('returns null for classes without the annotation', () async {
      final library = await resolveSource(_entitySource);

      expect(analyzer.analyze(findClass(library, 'TeamEntitySpec')), isNull);
    });
  });
}
