import 'dart:convert';
import 'dart:io';

import 'package:app_intents_codegen/src/cli/analyze_sources.dart';
import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/generator/xcstrings_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/enum_info.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

void main() {
  late XcstringsGenerator generator;

  setUp(() {
    generator = const XcstringsGenerator();
  });

  group('collectLocalizableStrings', () {
    test('collects intent title and description', () {
      final result = AnalyzeResult(
        intents: [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            description: 'Create a new task',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      final strings = generator.collectLocalizableStrings(result);
      expect(strings, contains('Create Task'));
      expect(strings, contains('Create a new task'));
    });

    test('collects intent resultDialogTemplate and parameterSummary', () {
      final result = AnalyzeResult(
        intents: [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'title',
                dartType: 'String',
                title: 'Title',
                isOptional: false,
              ),
            ],
            resultDialogTemplate: 'Created task "{title}"',
            parameterSummary: 'Create task {title}',
          ),
        ],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      final strings = generator.collectLocalizableStrings(result);
      expect(strings, contains('Created task "{title}"'));
      // parameterSummary uses ${param} format for Swift key-path placeholders
      expect(strings, contains(r'Create task ${title}'));
    });

    test('collects parameter title and description', () {
      final result = AnalyzeResult(
        intents: [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'title',
                dartType: 'String',
                title: 'Task Title',
                description: 'The title of the task',
                isOptional: false,
              ),
            ],
          ),
        ],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      final strings = generator.collectLocalizableStrings(result);
      expect(strings, contains('Task Title'));
      expect(strings, contains('The title of the task'));
    });

    test('collects entity title', () {
      final result = AnalyzeResult(
        intents: [],
        entities: [
          EntityInfo(
            className: 'TaskEntity',
            identifier: 'com.example.Task',
            title: 'Task',
            pluralTitle: 'Tasks',
            properties: [],
          ),
        ],
        enums: [],
        shortcuts: [],
      );

      final strings = generator.collectLocalizableStrings(result);
      expect(strings, contains('Task'));
    });

    test('collects enum title and case display titles', () {
      final result = AnalyzeResult(
        intents: [],
        entities: [],
        enums: [
          EnumInfo(
            className: 'Priority',
            identifier: 'com.example.Priority',
            title: 'Priority',
            cases: [
              EnumCaseInfo(name: 'high', displayTitle: 'High'),
              EnumCaseInfo(name: 'medium', displayTitle: 'Medium'),
              EnumCaseInfo(name: 'low', displayTitle: 'Low'),
            ],
          ),
        ],
        shortcuts: [],
      );

      final strings = generator.collectLocalizableStrings(result);
      expect(strings, contains('Priority'));
      expect(strings, contains('High'));
      expect(strings, contains('Medium'));
      expect(strings, contains('Low'));
    });

    test('collects shortcut shortTitle and phrases', () {
      final result = AnalyzeResult(
        intents: [],
        entities: [],
        enums: [],
        shortcuts: [
          AppShortcutInfo(
            intentClassName: 'CreateTaskIntent',
            phrases: [
              'Create a task with {applicationName}',
              'New task in {applicationName}',
            ],
            shortTitle: 'Create Task',
            systemImageName: 'plus',
          ),
        ],
      );

      final strings = generator.collectLocalizableStrings(result);
      expect(strings, contains('Create Task'));
      // Phrases convert {param} to ${param} for Swift key-path placeholders
      expect(strings, contains(r'Create a task with ${applicationName}'));
      expect(strings, contains(r'New task in ${applicationName}'));
    });

    test('deduplicates identical strings', () {
      final result = AnalyzeResult(
        intents: [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ],
        entities: [],
        enums: [],
        shortcuts: [
          AppShortcutInfo(
            intentClassName: 'CreateTaskIntent',
            phrases: ['Create a task'],
            shortTitle: 'Create Task',
            systemImageName: 'plus',
          ),
        ],
      );

      final strings = generator.collectLocalizableStrings(result);
      // "Create Task" appears in both intent title and shortcut shortTitle
      // but should only appear once in the set
      expect(strings.where((s) => s == 'Create Task').length, 1);
    });

    test('returns empty set for empty AnalyzeResult', () {
      const result = AnalyzeResult(
        intents: [],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      final strings = generator.collectLocalizableStrings(result);
      expect(strings, isEmpty);
    });
  });

  group('convertPlaceholders', () {
    test('returns text without placeholders unchanged', () {
      expect(generator.convertPlaceholders('Create Task'), 'Create Task');
    });

    test('converts single placeholder to %@', () {
      expect(
        generator.convertPlaceholders('Created task "{title}"'),
        'Created task "%@"',
      );
    });

    test('converts multiple placeholders to positional format', () {
      expect(
        generator.convertPlaceholders('Create {title} with {description}'),
        'Create %1\$@ with %2\$@',
      );
    });

    test('converts three placeholders', () {
      expect(
        generator.convertPlaceholders('{a} and {b} and {c}'),
        '%1\$@ and %2\$@ and %3\$@',
      );
    });

    test(r'preserves system variable ${} placeholders', () {
      expect(
        generator.convertPlaceholders(
            r'Create task with ${applicationName}'),
        r'Create task with ${applicationName}',
      );
    });

    test(r'converts {param} but preserves ${system} in same string', () {
      expect(
        generator.convertPlaceholders(
            r'Create {title} in ${applicationName}'),
        r'Create %@ in ${applicationName}',
      );
    });
  });

  group('generate', () {
    test('generates valid xcstrings JSON with source language only', () {
      final result = AnalyzeResult(
        intents: [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            description: 'Create a new task',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      final json = generator.generate(analyzeResult: result);
      final parsed = jsonDecode(json) as Map<String, dynamic>;

      expect(parsed['sourceLanguage'], 'en');
      expect(parsed['version'], '1.0');

      final strings = parsed['strings'] as Map<String, dynamic>;
      expect(strings, contains('Create Task'));
      expect(strings, contains('Create a new task'));

      final createTask = strings['Create Task'] as Map<String, dynamic>;
      expect(createTask['extractionState'], 'manual');

      final localizations =
          createTask['localizations'] as Map<String, dynamic>;
      final en = localizations['en'] as Map<String, dynamic>;
      final stringUnit = en['stringUnit'] as Map<String, dynamic>;
      expect(stringUnit['state'], 'translated');
      expect(stringUnit['value'], 'Create Task');
    });

    test('includes translations from YAML', () {
      final result = AnalyzeResult(
        intents: [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      final translations = {
        'ja': {'Create Task': 'タスクを作成'},
        'zh-Hans': {'Create Task': '创建任务'},
      };

      final json = generator.generate(
        analyzeResult: result,
        translations: translations,
      );
      final parsed = jsonDecode(json) as Map<String, dynamic>;

      final strings = parsed['strings'] as Map<String, dynamic>;
      final createTask = strings['Create Task'] as Map<String, dynamic>;
      final localizations =
          createTask['localizations'] as Map<String, dynamic>;

      expect(localizations, contains('en'));
      expect(localizations, contains('ja'));
      expect(localizations, contains('zh-Hans'));

      final ja = localizations['ja'] as Map<String, dynamic>;
      expect(
        (ja['stringUnit'] as Map<String, dynamic>)['value'],
        'タスクを作成',
      );

      final zh = localizations['zh-Hans'] as Map<String, dynamic>;
      expect(
        (zh['stringUnit'] as Map<String, dynamic>)['value'],
        '创建任务',
      );
    });

    test('converts placeholders in both source and translations', () {
      final result = AnalyzeResult(
        intents: [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'title',
                dartType: 'String',
                title: 'Title',
                isOptional: false,
              ),
            ],
            resultDialogTemplate: 'Created task "{title}"',
          ),
        ],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      final translations = {
        'ja': {'Created task "{title}"': 'タスク「{title}」を作成しました'},
      };

      final json = generator.generate(
        analyzeResult: result,
        translations: translations,
      );
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final strings = parsed['strings'] as Map<String, dynamic>;

      // Key keeps original placeholders
      expect(strings, contains('Created task "{title}"'));

      final entry =
          strings['Created task "{title}"'] as Map<String, dynamic>;
      final localizations =
          entry['localizations'] as Map<String, dynamic>;

      // Values have %@ placeholders
      final enValue = ((localizations['en']
          as Map<String, dynamic>)['stringUnit'] as Map<String, dynamic>)['value'];
      expect(enValue, 'Created task "%@"');

      final jaValue = ((localizations['ja']
          as Map<String, dynamic>)['stringUnit'] as Map<String, dynamic>)['value'];
      expect(jaValue, 'タスク「%@」を作成しました');
    });

    test(r'parameterSummary uses ${param} key and preserves in value', () {
      final result = AnalyzeResult(
        intents: [
          IntentInfo(
            className: 'CreatePostIntent',
            identifier: 'com.example.createPost',
            title: 'Create Post',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'target',
                dartType: 'String',
                title: 'Target',
                isOptional: false,
              ),
              IntentParamInfo(
                fieldName: 'text',
                dartType: 'String',
                title: 'Text',
                isOptional: false,
              ),
            ],
            parameterSummary:
                'Create a post on {target} with {text}',
          ),
        ],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      final translations = {
        'ja': {
          r'Create a post on ${target} with ${text}':
              r'${target}で${text}を投稿する',
        },
      };

      final json = generator.generate(
        analyzeResult: result,
        translations: translations,
      );
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final strings = parsed['strings'] as Map<String, dynamic>;

      // Key uses ${param} format
      expect(strings, contains(r'Create a post on ${target} with ${text}'));

      final entry = strings[r'Create a post on ${target} with ${text}']
          as Map<String, dynamic>;
      final localizations =
          entry['localizations'] as Map<String, dynamic>;

      // Values preserve ${param} (not converted to %@)
      final enValue = ((localizations['en'] as Map<String, dynamic>)[
          'stringUnit'] as Map<String, dynamic>)['value'];
      expect(enValue, r'Create a post on ${target} with ${text}');

      final jaValue = ((localizations['ja'] as Map<String, dynamic>)[
          'stringUnit'] as Map<String, dynamic>)['value'];
      expect(jaValue, r'${target}で${text}を投稿する');
    });

    test('YAML translations match with {param} fallback key', () {
      final result = AnalyzeResult(
        intents: [
          IntentInfo(
            className: 'CreatePostIntent',
            identifier: 'com.example.createPost',
            title: 'Create Post',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'title',
                dartType: 'String',
                title: 'Title',
                isOptional: false,
              ),
            ],
            parameterSummary: 'Create post {title}',
          ),
        ],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      // User writes YAML with {param} (without $)
      final translations = {
        'ja': {'Create post {title}': '投稿を作成 {title}'},
      };

      final json = generator.generate(
        analyzeResult: result,
        translations: translations,
      );
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final strings = parsed['strings'] as Map<String, dynamic>;

      final entry =
          strings[r'Create post ${title}'] as Map<String, dynamic>;
      final localizations =
          entry['localizations'] as Map<String, dynamic>;

      // ja translation found via {param} fallback
      expect(localizations, contains('ja'));
      final jaValue = ((localizations['ja'] as Map<String, dynamic>)[
          'stringUnit'] as Map<String, dynamic>)['value'];
      // {title} in YAML value gets preserved since convertPlaceholders
      // treats single {param} → %@
      expect(jaValue, '投稿を作成 %@');
    });

    test('uses custom source language', () {
      final gen = const XcstringsGenerator(sourceLanguage: 'ja');
      final result = AnalyzeResult(
        intents: [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'タスクを作成',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      final json = gen.generate(analyzeResult: result);
      final parsed = jsonDecode(json) as Map<String, dynamic>;

      expect(parsed['sourceLanguage'], 'ja');

      final strings = parsed['strings'] as Map<String, dynamic>;
      final entry = strings['タスクを作成'] as Map<String, dynamic>;
      final localizations =
          entry['localizations'] as Map<String, dynamic>;
      expect(localizations, contains('ja'));
      expect(localizations, isNot(contains('en')));
    });

    test('generates empty strings for empty AnalyzeResult', () {
      const result = AnalyzeResult(
        intents: [],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      final json = generator.generate(analyzeResult: result);
      final parsed = jsonDecode(json) as Map<String, dynamic>;

      expect(parsed['sourceLanguage'], 'en');
      expect(parsed['version'], '1.0');
      expect(parsed['strings'] as Map<String, dynamic>, isEmpty);
    });

    test('sorts keys alphabetically', () {
      final result = AnalyzeResult(
        intents: [
          IntentInfo(
            className: 'ZIntent',
            identifier: 'com.z',
            title: 'Zebra',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
          IntentInfo(
            className: 'AIntent',
            identifier: 'com.a',
            title: 'Apple',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      final json = generator.generate(analyzeResult: result);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final keys = (parsed['strings'] as Map<String, dynamic>).keys.toList();

      expect(keys, ['Apple', 'Zebra']);
    });

    group('merge with existing xcstrings', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('xcstrings_test_');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('preserves existing translations not in YAML', () {
        // Create existing .xcstrings file with Korean translation
        final existingPath = '${tempDir.path}/existing.xcstrings';
        final existing = {
          'sourceLanguage': 'en',
          'version': '1.0',
          'strings': {
            'Create Task': {
              'extractionState': 'manual',
              'localizations': {
                'en': {
                  'stringUnit': {
                    'state': 'translated',
                    'value': 'Create Task',
                  },
                },
                'ko': {
                  'stringUnit': {
                    'state': 'translated',
                    'value': '작업 만들기',
                  },
                },
              },
            },
          },
        };
        File(existingPath)
            .writeAsStringSync(jsonEncode(existing));

        final result = AnalyzeResult(
          intents: [
            IntentInfo(
              className: 'CreateTaskIntent',
              identifier: 'com.example.createTask',
              title: 'Create Task',
              implementation: IntentImplementationType.dart,
              parameters: [],
            ),
          ],
          entities: [],
          enums: [],
          shortcuts: [],
        );

        final translations = {
          'ja': {'Create Task': 'タスクを作成'},
        };

        final json = generator.generate(
          analyzeResult: result,
          translations: translations,
          existingXcstringsPath: existingPath,
        );
        final parsed = jsonDecode(json) as Map<String, dynamic>;
        final strings = parsed['strings'] as Map<String, dynamic>;
        final createTask = strings['Create Task'] as Map<String, dynamic>;
        final localizations =
            createTask['localizations'] as Map<String, dynamic>;

        // en from generator, ja from YAML, ko from existing
        expect(localizations, contains('en'));
        expect(localizations, contains('ja'));
        expect(localizations, contains('ko'));

        final ko = localizations['ko'] as Map<String, dynamic>;
        expect(
          (ko['stringUnit'] as Map<String, dynamic>)['value'],
          '작업 만들기',
        );
      });

      test('removes keys no longer in annotations', () {
        final existingPath = '${tempDir.path}/existing.xcstrings';
        final existing = {
          'sourceLanguage': 'en',
          'version': '1.0',
          'strings': {
            'Create Task': {
              'extractionState': 'manual',
              'localizations': {
                'en': {
                  'stringUnit': {
                    'state': 'translated',
                    'value': 'Create Task',
                  },
                },
              },
            },
            'Old Removed Intent': {
              'extractionState': 'manual',
              'localizations': {
                'en': {
                  'stringUnit': {
                    'state': 'translated',
                    'value': 'Old Removed Intent',
                  },
                },
              },
            },
          },
        };
        File(existingPath)
            .writeAsStringSync(jsonEncode(existing));

        final result = AnalyzeResult(
          intents: [
            IntentInfo(
              className: 'CreateTaskIntent',
              identifier: 'com.example.createTask',
              title: 'Create Task',
              implementation: IntentImplementationType.dart,
              parameters: [],
            ),
          ],
          entities: [],
          enums: [],
          shortcuts: [],
        );

        final json = generator.generate(
          analyzeResult: result,
          existingXcstringsPath: existingPath,
        );
        final parsed = jsonDecode(json) as Map<String, dynamic>;
        final strings = parsed['strings'] as Map<String, dynamic>;

        expect(strings, contains('Create Task'));
        expect(strings, isNot(contains('Old Removed Intent')));
      });

      test('YAML translations override existing xcstrings translations', () {
        final existingPath = '${tempDir.path}/existing.xcstrings';
        final existing = {
          'sourceLanguage': 'en',
          'version': '1.0',
          'strings': {
            'Create Task': {
              'extractionState': 'manual',
              'localizations': {
                'en': {
                  'stringUnit': {
                    'state': 'translated',
                    'value': 'Create Task',
                  },
                },
                'ja': {
                  'stringUnit': {
                    'state': 'translated',
                    'value': '古い翻訳',
                  },
                },
              },
            },
          },
        };
        File(existingPath)
            .writeAsStringSync(jsonEncode(existing));

        final result = AnalyzeResult(
          intents: [
            IntentInfo(
              className: 'CreateTaskIntent',
              identifier: 'com.example.createTask',
              title: 'Create Task',
              implementation: IntentImplementationType.dart,
              parameters: [],
            ),
          ],
          entities: [],
          enums: [],
          shortcuts: [],
        );

        final translations = {
          'ja': {'Create Task': '新しい翻訳'},
        };

        final json = generator.generate(
          analyzeResult: result,
          translations: translations,
          existingXcstringsPath: existingPath,
        );
        final parsed = jsonDecode(json) as Map<String, dynamic>;
        final strings = parsed['strings'] as Map<String, dynamic>;
        final createTask = strings['Create Task'] as Map<String, dynamic>;
        final localizations =
            createTask['localizations'] as Map<String, dynamic>;
        final ja = localizations['ja'] as Map<String, dynamic>;

        expect(
          (ja['stringUnit'] as Map<String, dynamic>)['value'],
          '新しい翻訳',
        );
      });
    });
  });

  group('loadTranslations', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('xcstrings_yaml_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('loads translations from valid YAML file', () {
      final yamlPath = '${tempDir.path}/translations.yaml';
      File(yamlPath).writeAsStringSync('''
ja:
  "Create Task": "タスクを作成"
  "Title": "タイトル"
zh-Hans:
  "Create Task": "创建任务"
''');

      final translations = generator.loadTranslations(yamlPath);

      expect(translations, contains('ja'));
      expect(translations, contains('zh-Hans'));
      expect(translations['ja']!['Create Task'], 'タスクを作成');
      expect(translations['ja']!['Title'], 'タイトル');
      expect(translations['zh-Hans']!['Create Task'], '创建任务');
    });

    test('returns empty map for non-existent file', () {
      final translations =
          generator.loadTranslations('${tempDir.path}/nonexistent.yaml');
      expect(translations, isEmpty);
    });

    test('returns empty map for invalid YAML', () {
      final yamlPath = '${tempDir.path}/invalid.yaml';
      File(yamlPath).writeAsStringSync('just a string');

      final translations = generator.loadTranslations(yamlPath);
      expect(translations, isEmpty);
    });
  });
}
