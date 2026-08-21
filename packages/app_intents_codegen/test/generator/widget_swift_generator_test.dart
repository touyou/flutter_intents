import 'package:app_intents_codegen/src/generator/widget_swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/widget_configuration_info.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

const _generator = WidgetSwiftGenerator(
  appGroupIdentifier: 'group.com.example.app',
  storageIdentifier: 'com.example.app',
);

EntityInfo teamEntity({
  String idField = 'id',
  String idType = 'String',
  String titleField = 'name',
  bool enumerable = true,
  String? persistedCacheKey,
  bool withSubtitle = false,
  bool withImage = false,
  String subtitleType = 'String?',
}) {
  return EntityInfo(
    className: 'TeamEntitySpec',
    identifier: 'com.example.joinedTeam',
    title: 'Team',
    pluralTitle: 'Teams',
    enumerable: enumerable,
    persistedCacheKey: persistedCacheKey,
    properties: [
      EntityPropertyInfo(
        fieldName: idField,
        dartType: idType,
        role: EntityPropertyRole.id,
      ),
      EntityPropertyInfo(
        fieldName: titleField,
        dartType: 'String',
        role: EntityPropertyRole.title,
      ),
      if (withSubtitle)
        EntityPropertyInfo(
          fieldName: 'note',
          dartType: subtitleType,
          role: EntityPropertyRole.subtitle,
        ),
      if (withImage)
        const EntityPropertyInfo(
          fieldName: 'symbol',
          dartType: 'String?',
          role: EntityPropertyRole.image,
        ),
    ],
  );
}

WidgetConfigurationInfo selectTeamConfig({
  bool isDiscoverable = false,
  bool generateDefaultResult = false,
  List<WidgetParamInfo>? parameters,
}) {
  return WidgetConfigurationInfo(
    className: 'SelectTeamWidgetConfig',
    identifier: 'com.example.selectTeam',
    title: 'Displayed team',
    description: 'Choose which team this widget shows.',
    isDiscoverable: isDiscoverable,
    generateDefaultResult: generateDefaultResult,
    parameters:
        parameters ??
        const [
          WidgetParamInfo(
            name: 'team',
            dartType: 'TeamEntitySpec?',
            title: 'Team',
            entityType: 'TeamEntitySpec',
          ),
        ],
  );
}

void main() {
  group('WidgetSwiftGenerator', () {
    group('storage configuration', () {
      test('bakes in the app group and storage identifier', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity()],
        );

        expect(swift, contains('enum GeneratedWidgetEntityCache {'));
        expect(
          swift,
          contains('static let appGroupIdentifier = "group.com.example.app"'),
        );
        expect(
          swift,
          contains('static let storageIdentifier = "com.example.app"'),
        );
        expect(swift, contains('AppIntentsEntityCache('));
      });

      test('imports AppIntents and AppIntentsBridge', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity()],
        );

        expect(swift, startsWith('import AppIntents\n'));
        expect(swift, contains('import AppIntentsBridge'));
      });
    });

    group('entity generation', () {
      test('names the widget entity and query distinctly', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity()],
        );

        expect(
          swift,
          contains('struct TeamEntitySpecWidgetEntity: AppEntity {'),
        );
        expect(
          swift,
          contains('struct TeamEntitySpecWidgetQuery: EnumerableEntityQuery {'),
        );
        // The app target's own type name must not be reused, or including both
        // files in one target duplicates the intent metadata.
        expect(swift, isNot(contains('struct TeamEntitySpec:')));
      });

      test('uses the default entity cache key', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity()],
        );

        expect(
          swift,
          contains(
            'static let cacheKey = '
            '"app_intents.entities.com.example.joinedTeam"',
          ),
        );
      });

      test('uses an explicit persistedCacheKey when set', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [
            teamEntity(
              enumerable: false,
              persistedCacheKey: 'com.example.taskapp.cache.teams',
            ),
          ],
        );

        expect(
          swift,
          contains('static let cacheKey = "com.example.taskapp.cache.teams"'),
        );
      });

      test('maps id/title field names onto the cache reader', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity()],
        );

        expect(swift, contains('idKey: "id"'));
        expect(swift, contains('titleKey: "name"'));
        expect(swift, contains('id: cached.id'));
        expect(swift, contains('name: cached.title'));
      });

      test('normalizes a non-`id` @EntityId field to `id` in Swift', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity(idField: 'teamId')],
        );

        // AppEntity refines Identifiable, so the Swift property must be `id`
        // regardless of the Dart field name; the Dart name only names the key
        // inside the cached payload.
        expect(swift, contains('var id: String'));
        expect(swift, isNot(contains('var teamId: String')));
        expect(swift, contains('idKey: "teamId"'));
        expect(swift, contains('id: cached.id'));
        expect(swift, contains(r'all.first { $0.id == identifier }'));
      });

      test('passes subtitle and image keys when the entity has them', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity(withSubtitle: true, withImage: true)],
        );

        expect(swift, contains('subtitleKey: "note"'));
        expect(swift, contains('imageKey: "symbol"'));
        expect(swift, contains('note: cached.subtitle'));
        expect(swift, contains('symbol: cached.imageName'));
      });

      test('coalesces a non-optional subtitle field', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity(withSubtitle: true, subtitleType: 'String')],
        );

        expect(swift, contains('note: cached.subtitle ?? ""'));
      });

      test('implements allEntities and entities(for:)', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity()],
        );

        expect(
          swift,
          contains(
            'func allEntities() async throws -> [TeamEntitySpecWidgetEntity] {',
          ),
        );
        expect(
          swift,
          contains('func entities(for identifiers: [String]) async throws'),
        );
      });

      test('omits defaultResult by default', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity()],
        );

        expect(swift, isNot(contains('func defaultResult()')));
      });

      test('emits defaultResult when the configuration opts in', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig(generateDefaultResult: true)],
          entities: [teamEntity()],
        );

        expect(
          swift,
          contains(
            'func defaultResult() async -> TeamEntitySpecWidgetEntity? {',
          ),
        );
      });

      test('generates each referenced entity once', () {
        final config = WidgetConfigurationInfo(
          className: 'SelectTeamWidgetConfig',
          identifier: 'com.example.selectTeam',
          title: 'Displayed team',
          parameters: const [
            WidgetParamInfo(
              name: 'primary',
              dartType: 'TeamEntitySpec?',
              title: 'Primary team',
              entityType: 'TeamEntitySpec',
            ),
            WidgetParamInfo(
              name: 'secondary',
              dartType: 'TeamEntitySpec?',
              title: 'Secondary team',
              entityType: 'TeamEntitySpec',
            ),
          ],
        );

        final swift = _generator.generateAll(
          configurations: [config],
          entities: [teamEntity()],
        );

        expect('struct TeamEntitySpecWidgetEntity'.allMatches(swift).length, 1);
      });
    });

    group('configuration intent generation', () {
      test('conforms to WidgetConfigurationIntent with title/description', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity()],
        );

        expect(
          swift,
          contains(
            'struct SelectTeamWidgetConfig: WidgetConfigurationIntent {',
          ),
        );
        expect(
          swift,
          contains(
            'static var title: LocalizedStringResource = "Displayed team"',
          ),
        );
        expect(
          swift,
          contains('IntentDescription("Choose which team this widget shows.")'),
        );
      });

      test('defaults isDiscoverable to false', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity()],
        );

        expect(swift, contains('static var isDiscoverable: Bool { false }'));
      });

      test('honors isDiscoverable: true', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig(isDiscoverable: true)],
          entities: [teamEntity()],
        );

        expect(swift, contains('static var isDiscoverable: Bool { true }'));
      });

      test('emits the identifier as persistentIdentifier', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity()],
        );

        expect(
          swift,
          contains(
            'static var persistentIdentifier: String '
            '{ "com.example.selectTeam" }',
          ),
        );
      });

      test('emits an optional entity parameter', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [teamEntity()],
        );

        expect(swift, contains('@Parameter(title: "Team")'));
        expect(swift, contains('var team: TeamEntitySpecWidgetEntity?'));
      });

      test('makes a non-optional entity parameter optional anyway', () {
        final swift = _generator.generateAll(
          configurations: [
            selectTeamConfig(
              parameters: const [
                WidgetParamInfo(
                  name: 'team',
                  dartType: 'TeamEntitySpec',
                  title: 'Team',
                  entityType: 'TeamEntitySpec',
                ),
              ],
            ),
          ],
          entities: [teamEntity()],
        );

        expect(swift, contains('var team: TeamEntitySpecWidgetEntity?'));
      });

      test('emits scalar parameters with their Swift types', () {
        final swift = _generator.generateAll(
          configurations: [
            selectTeamConfig(
              parameters: const [
                WidgetParamInfo(
                  name: 'showCompleted',
                  dartType: 'bool',
                  title: 'Show completed',
                  description: 'Include finished tasks',
                ),
                WidgetParamInfo(
                  name: 'limit',
                  dartType: 'int?',
                  title: 'Limit',
                ),
              ],
            ),
          ],
          entities: [teamEntity()],
        );

        expect(
          swift,
          contains(
            '@Parameter(title: "Show completed", '
            'description: "Include finished tasks")',
          ),
        );
        expect(swift, contains('var showCompleted: Bool\n'));
        expect(swift, contains('var limit: Int?\n'));
        // A nullable scalar must not pick up a second `?` from the
        // entity-parameter path.
        expect(swift, isNot(contains('Int??')));
      });
    });

    group('Swift string escaping', () {
      test('escapes quotes and backslashes in author-supplied strings', () {
        final swift = _generator.generateAll(
          configurations: [
            WidgetConfigurationInfo(
              className: 'SelectTeamWidgetConfig',
              identifier: 'com.example.selectTeam',
              title: r'Displayed "team"',
              description: r'Backslash \ and \(name)',
              parameters: const [
                WidgetParamInfo(
                  name: 'team',
                  dartType: 'TeamEntitySpec?',
                  title: r'Team "picker"',
                  entityType: 'TeamEntitySpec',
                ),
              ],
            ),
          ],
          entities: [teamEntity()],
        );

        expect(swift, contains(r'"Displayed \"team\""'));
        expect(swift, contains(r'"Backslash \\ and \\(name)"'));
        expect(swift, contains(r'title: "Team \"picker\""'));
        // No unescaped quote may survive inside a literal.
        expect(swift, isNot(contains('"Displayed "team""')));
      });

      test('escapes the entity type display name', () {
        final swift = _generator.generateAll(
          configurations: [selectTeamConfig()],
          entities: [
            EntityInfo(
              className: 'TeamEntitySpec',
              identifier: 'com.example.joinedTeam',
              title: r'The "Team"',
              pluralTitle: 'Teams',
              enumerable: true,
              properties: teamEntity().properties,
            ),
          ],
        );

        expect(
          swift,
          contains(r'TypeDisplayRepresentation(name: "The \"Team\"")'),
        );
      });
    });

    group('validation', () {
      test('rejects an unknown entity type', () {
        expect(
          () => _generator.generateAll(
            configurations: [selectTeamConfig()],
            entities: const [],
          ),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (e) => e.message,
              'message',
              contains('no @EntitySpec class with that name was found'),
            ),
          ),
        );
      });

      test('rejects an entity that persists no cache', () {
        expect(
          () => _generator.generateAll(
            configurations: [selectTeamConfig()],
            entities: [teamEntity(enumerable: false)],
          ),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (e) => e.message,
              'message',
              contains('persists no entity cache'),
            ),
          ),
        );
      });

      test('rejects an entity without id/title roles', () {
        expect(
          () => _generator.generateAll(
            configurations: [selectTeamConfig()],
            entities: const [
              EntityInfo(
                className: 'TeamEntitySpec',
                identifier: 'com.example.joinedTeam',
                title: 'Team',
                pluralTitle: 'Teams',
                enumerable: true,
                properties: [],
              ),
            ],
          ),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (e) => e.message,
              'message',
              contains('missing an @EntityId or @EntityTitle field'),
            ),
          ),
        );
      });

      test('rejects a non-String @EntityId field', () {
        // The App Group payload only carries strings, so an `int` id would
        // compile into `var id: Int` fed from `cached.id` (a String).
        expect(
          () => _generator.generateAll(
            configurations: [selectTeamConfig()],
            entities: [teamEntity(idField: 'rowId', idType: 'int')],
          ),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (e) => e.message,
              'message',
              allOf(contains('`rowId`'), contains('must be `String`')),
            ),
          ),
        );
      });

      test('rejects a non-String @EntitySubtitle field', () {
        expect(
          () => _generator.generateAll(
            configurations: [selectTeamConfig()],
            entities: [teamEntity(withSubtitle: true, subtitleType: 'int?')],
          ),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (e) => e.message,
              'message',
              contains('@EntitySubtitle'),
            ),
          ),
        );
      });

      test('accepts a nullable String subtitle and image', () {
        expect(
          () => _generator.generateAll(
            configurations: [selectTeamConfig()],
            entities: [teamEntity(withSubtitle: true, withImage: true)],
          ),
          returnsNormally,
        );
      });

      test('rejects a non-id role field named `id`', () {
        // `_swiftPropertyName` renames the @EntityId field to `id`, so a title
        // field literally named `id` would emit two `var id` declarations.
        expect(
          () => _generator.generateAll(
            configurations: [selectTeamConfig()],
            entities: [teamEntity(idField: 'teamId', titleField: 'id')],
          ),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (e) => e.message,
              'message',
              contains('collides with the generated identifier property'),
            ),
          ),
        );
      });

      test('rejects configurations that disagree on generateDefaultResult', () {
        // Only one query is generated per entity, so the opted-out config would
        // silently inherit defaultResult().
        expect(
          () => _generator.generateAll(
            configurations: [
              selectTeamConfig(generateDefaultResult: true),
              WidgetConfigurationInfo(
                className: 'OtherTeamWidgetConfig',
                identifier: 'com.example.otherTeam',
                title: 'Other team',
                parameters: const [
                  WidgetParamInfo(
                    name: 'team',
                    dartType: 'TeamEntitySpec?',
                    title: 'Team',
                    entityType: 'TeamEntitySpec',
                  ),
                ],
              ),
            ],
            entities: [teamEntity()],
          ),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('disagree on `generateDefaultResult`'),
                contains('OtherTeamWidgetConfig'),
              ),
            ),
          ),
        );
      });

      test('allows configurations that agree on generateDefaultResult', () {
        final swift = _generator.generateAll(
          configurations: [
            selectTeamConfig(generateDefaultResult: true),
            WidgetConfigurationInfo(
              className: 'OtherTeamWidgetConfig',
              identifier: 'com.example.otherTeam',
              title: 'Other team',
              generateDefaultResult: true,
              parameters: const [
                WidgetParamInfo(
                  name: 'team',
                  dartType: 'TeamEntitySpec?',
                  title: 'Team',
                  entityType: 'TeamEntitySpec',
                ),
              ],
            ),
          ],
          entities: [teamEntity()],
        );

        expect(swift, contains('func defaultResult() async ->'));
      });

      test('rejects an unsupported scalar parameter type', () {
        expect(
          () => _generator.generateAll(
            configurations: [
              selectTeamConfig(
                parameters: const [
                  WidgetParamInfo(
                    name: 'tags',
                    dartType: 'List<String>',
                    title: 'Tags',
                  ),
                ],
              ),
            ],
            entities: [teamEntity()],
          ),
          throwsA(
            isA<InvalidGenerationSourceError>().having(
              (e) => e.message,
              'message',
              contains('unsupported type `List<String>`'),
            ),
          ),
        );
      });
    });
  });
}
