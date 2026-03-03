import 'package:app_intents_codegen/src/generator/swift_generator.dart';
import 'package:app_intents_codegen/src/models/entity_info.dart';
import 'package:app_intents_codegen/src/models/enum_info.dart';
import 'package:app_intents_codegen/src/models/intent_info.dart';
import 'package:test/test.dart';

void main() {
  group('SwiftGenerator', () {
    late SwiftGenerator generator;

    setUp(() {
      generator = SwiftGenerator();
    });

    group('generateIntent', () {
      test('generates basic AppIntent struct with title', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet User',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('import AppIntents'));
        expect(result, contains('@available(iOS 17.0, *)'));
        expect(result, contains('struct GreetIntent: AppIntent'));
        expect(
            result, contains('static var title: LocalizedStringResource = "Greet User"'));
      });

      test('generates intent with description', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet User',
          description: 'Greets the user with a friendly message',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('static var description: IntentDescription'));
        expect(
            result, contains('IntentDescription("Greets the user with a friendly message")'));
      });

      test('generates intent with String parameter', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'title',
              dartType: 'String',
              title: 'Task Title',
              isOptional: false,
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('@Parameter(title: "Task Title")'));
        expect(result, contains('var title: String'));
      });

      test('generates intent with optional parameter', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'dueDate',
              dartType: 'DateTime?',
              title: 'Due Date',
              isOptional: true,
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('@Parameter(title: "Due Date")'));
        expect(result, contains('var dueDate: Date?'));
      });

      test('generates intent with parameter description', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'title',
              dartType: 'String',
              title: 'Task Title',
              description: 'The title of the task to create',
              isOptional: false,
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(
            result,
            contains(
                '@Parameter(title: "Task Title", description: "The title of the task to create")'));
      });

      test('generates perform method with FlutterBridge invocation', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'title',
              dartType: 'String',
              title: 'Task Title',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'dueDate',
              dartType: 'DateTime?',
              title: 'Due Date',
              isOptional: true,
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('@MainActor'));
        expect(result, contains('func perform() async throws -> some IntentResult'));
        expect(result, contains('FlutterBridge.shared.invoke'));
        expect(result, contains('intent: "CreateTaskIntent"'));
        expect(result, contains('"title": title'));
        expect(result, contains('"dueDate": dueDate'));
        expect(result, contains('return .result()'));
      });

      test('generates import AppIntentsBridge for FlutterBridge mode', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('import AppIntentsBridge'));
      });

      test('does not generate import AppIntentsBridge for URL scheme mode', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          urlScheme: 'taskapp',
          urlAction: 'create',
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, isNot(contains('import AppIntentsBridge')));
      });

      test('generates intent with multiple type mappings', () {
        final intentInfo = IntentInfo(
          className: 'TestIntent',
          identifier: 'com.example.test',
          title: 'Test Intent',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'stringParam',
              dartType: 'String',
              title: 'String Param',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'intParam',
              dartType: 'int',
              title: 'Int Param',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'boolParam',
              dartType: 'bool',
              title: 'Bool Param',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'dateParam',
              dartType: 'DateTime',
              title: 'Date Param',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'doubleParam',
              dartType: 'double',
              title: 'Double Param',
              isOptional: false,
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('var stringParam: String'));
        expect(result, contains('var intParam: Int'));
        expect(result, contains('var boolParam: Bool'));
        expect(result, contains('var dateParam: Date'));
        expect(result, contains('var doubleParam: Double'));
      });
    });

    group('generateIntent with URL scheme', () {
      test('generates URL scheme perform with no params', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet User',
          implementation: IntentImplementationType.dart,
          parameters: [],
          urlScheme: 'myapp',
          urlAction: 'greet',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('import UIKit'));
        expect(result, contains('static var openAppWhenRun: Bool { true }'));
        expect(result, contains('URL(string: "myapp://greet")'));
        expect(result, contains('UIApplication.shared.open(url)'));
        expect(result, isNot(contains('FlutterBridge')));
      });

      test('generates URL scheme with String parameter', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'title',
              dartType: 'String',
              title: 'Task Title',
              isOptional: false,
            ),
          ],
          urlScheme: 'taskapp',
          urlAction: 'create',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('var components = URLComponents()'));
        expect(result, contains('components.scheme = "taskapp"'));
        expect(result, contains('components.host = "create"'));
        expect(result, contains('URLQueryItem(name: "title", value: String(describing: title))'));
        expect(result, contains('UIApplication.shared.open(url)'));
      });

      test('generates URL scheme with optional DateTime parameter', () {
        final intentInfo = IntentInfo(
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
            IntentParamInfo(
              fieldName: 'dueDate',
              dartType: 'DateTime?',
              title: 'Due Date',
              isOptional: true,
            ),
          ],
          urlScheme: 'taskapp',
          urlAction: 'create',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('if let dueDate'));
        expect(result, contains('ISO8601DateFormatter().string(from: dueDate)'));
      });

      test('derives urlAction from identifier when not provided', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.taskapp.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [],
          urlScheme: 'taskapp',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('URL(string: "taskapp://createTask")'));
      });

      test('without urlScheme still generates FlutterBridge code', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet User',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('FlutterBridge.shared.invoke'));
        expect(result, isNot(contains('UIApplication')));
        expect(result, isNot(contains('openAppWhenRun')));
        expect(result, isNot(contains('import UIKit')));
      });

      test('generates URL scheme with int, bool, optional String params', () {
        final intentInfo = IntentInfo(
          className: 'TestIntent',
          identifier: 'com.example.test',
          title: 'Test',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'count',
              dartType: 'int',
              title: 'Count',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'enabled',
              dartType: 'bool',
              title: 'Enabled',
              isOptional: false,
            ),
            IntentParamInfo(
              fieldName: 'note',
              dartType: 'String?',
              title: 'Note',
              isOptional: true,
            ),
          ],
          urlScheme: 'testapp',
          urlAction: 'run',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('String(describing: count)'));
        expect(result, contains('String(describing: enabled)'));
        expect(result, contains('if let note'));
      });
    });

    group('generateIntent with entity parameter', () {
      test('generates entity type for parameter with entityType', () {
        final intentInfo = IntentInfo(
          className: 'CompleteTaskIntent',
          identifier: 'com.example.completeTask',
          title: 'Complete Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'task',
              dartType: 'String',
              title: 'Task',
              isOptional: false,
              entityType: 'TaskEntitySpec',
            ),
          ],
          urlScheme: 'taskapp',
          urlAction: 'complete',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('var task: TaskEntitySpec'));
        expect(result, contains('task.id'));
        expect(result, isNot(contains('var task: String')));
      });

      test('generates entity .id in FlutterBridge params', () {
        final intentInfo = IntentInfo(
          className: 'CompleteTaskIntent',
          identifier: 'com.example.completeTask',
          title: 'Complete Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'task',
              dartType: 'String',
              title: 'Task',
              isOptional: false,
              entityType: 'TaskEntitySpec',
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('"task": task.id'));
        expect(result, contains('var task: TaskEntitySpec'));
      });
    });

    group('generateIntent with resultDialogTemplate', () {
      test('generates ProvidesDialog return type for FlutterBridge', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'title',
              dartType: 'String',
              title: 'Task Title',
              isOptional: false,
            ),
          ],
          resultDialogTemplate: 'Created task "{title}"',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('func perform() async throws -> some IntentResult & ProvidesDialog'));
        expect(result, contains(r'return .result(dialog: .init("Created task \"'));
        expect(result, contains(r'\(title)'));
      });

      test('generates ProvidesDialog return type for URL scheme', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'title',
              dartType: 'String',
              title: 'Task Title',
              isOptional: false,
            ),
          ],
          urlScheme: 'taskapp',
          urlAction: 'create',
          resultDialogTemplate: 'Created task "{title}"',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('func perform() async throws -> some IntentResult & ProvidesDialog'));
        expect(result, contains(r'return .result(dialog: .init("Created task \"'));
      });

      test('without dialog returns plain IntentResult', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('func perform() async throws -> some IntentResult'));
        expect(result, isNot(contains('ProvidesDialog')));
        expect(result, contains('return .result()'));
      });
    });

    group('generateIntent with parameterSummary', () {
      test('generates parameterSummary property', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'title',
              dartType: 'String',
              title: 'Task Title',
              isOptional: false,
            ),
          ],
          parameterSummary: 'Create {title}',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('static var parameterSummary: some ParameterSummary'));
        expect(result, contains(r'Summary("Create \(\.$title)")'));
      });

      test('does not generate parameterSummary when not provided', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, isNot(contains('parameterSummary')));
        expect(result, isNot(contains('Summary(')));
      });
    });

    group('generateIntent with supportedModes', () {
      test('generates supportedModes and openAppWhenRun when foreground', () {
        final intentInfo = IntentInfo(
          className: 'OpenAppIntent',
          identifier: 'com.example.openApp',
          title: 'Open App',
          implementation: IntentImplementationType.dart,
          parameters: [],
          supportedModes: IntentModeType.foreground,
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('@available(iOS 26.0, *)'));
        expect(
            result,
            contains(
                'static var supportedModes: IntentModes { .foreground }'));
        expect(
            result, contains('static var openAppWhenRun: Bool { true }'));
      });

      test('does not generate supportedModes when not set and no urlScheme',
          () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet',
          implementation: IntentImplementationType.dart,
          parameters: [],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, isNot(contains('supportedModes')));
        expect(result, isNot(contains('openAppWhenRun')));
      });

      test('does not generate supportedModes when background', () {
        final intentInfo = IntentInfo(
          className: 'BackgroundIntent',
          identifier: 'com.example.background',
          title: 'Background Task',
          implementation: IntentImplementationType.dart,
          parameters: [],
          supportedModes: IntentModeType.background,
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, isNot(contains('supportedModes')));
        expect(result, isNot(contains('openAppWhenRun')));
      });

      test('urlScheme implies foreground even without explicit supportedModes',
          () {
        final intentInfo = IntentInfo(
          className: 'OpenIntent',
          identifier: 'com.example.open',
          title: 'Open',
          implementation: IntentImplementationType.dart,
          parameters: [],
          urlScheme: 'myapp',
          urlAction: 'open',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('@available(iOS 26.0, *)'));
        expect(
            result,
            contains(
                'static var supportedModes: IntentModes { .foreground }'));
        expect(
            result, contains('static var openAppWhenRun: Bool { true }'));
      });

      test(
          'foreground with parameters generates both supportedModes and openAppWhenRun',
          () {
        final intentInfo = IntentInfo(
          className: 'CreatePostIntent',
          identifier: 'com.example.createPost',
          title: 'Create Post',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'title',
              dartType: 'String',
              title: 'Post Title',
              isOptional: false,
            ),
          ],
          supportedModes: IntentModeType.foreground,
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('@available(iOS 26.0, *)'));
        expect(
            result,
            contains(
                'static var supportedModes: IntentModes { .foreground }'));
        expect(
            result, contains('static var openAppWhenRun: Bool { true }'));
        expect(result, contains('@Parameter(title: "Post Title")'));
      });
    });

    group('generateIntent with enum parameter', () {
      test('generates enum type for parameter with enumType', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'priority',
              dartType: 'String',
              title: 'Priority',
              isOptional: false,
              enumType: 'TaskPriority',
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('var priority: TaskPriority'));
        expect(result, contains('priority.rawValue'));
      });

      test('generates enum .rawValue in URL query items', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'priority',
              dartType: 'String',
              title: 'Priority',
              isOptional: false,
              enumType: 'TaskPriority',
            ),
          ],
          urlScheme: 'taskapp',
          urlAction: 'create',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('var priority: TaskPriority'));
        expect(result, contains('priority.rawValue'));
      });
    });

    group('generateIntent with file parameter', () {
      test('generates IntentFile type with supportedTypeIdentifiers', () {
        final intentInfo = IntentInfo(
          className: 'CreatePostIntent',
          identifier: 'com.example.createPost',
          title: 'Create Post',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'image',
              dartType: 'IntentFile?',
              title: 'Image',
              isOptional: true,
              fileType: 'public.image',
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result,
            contains('@Parameter(title: "Image", supportedTypeIdentifiers: ["public.image"])'));
        expect(result, contains('var image: IntentFile?'));
      });

      test('generates required IntentFile parameter', () {
        final intentInfo = IntentInfo(
          className: 'UploadIntent',
          identifier: 'com.example.upload',
          title: 'Upload File',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'document',
              dartType: 'IntentFile',
              title: 'Document',
              isOptional: false,
              fileType: 'public.data',
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result,
            contains('@Parameter(title: "Document", supportedTypeIdentifiers: ["public.data"])'));
        expect(result, contains('var document: IntentFile'));
        expect(result, isNot(contains('var document: IntentFile?')));
      });

      test('generates import UniformTypeIdentifiers for file params', () {
        final intentInfo = IntentInfo(
          className: 'CreatePostIntent',
          identifier: 'com.example.createPost',
          title: 'Create Post',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'image',
              dartType: 'IntentFile?',
              title: 'Image',
              isOptional: true,
              fileType: 'public.image',
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('import UniformTypeIdentifiers'));
      });

      test('generates file serialization code for optional file param', () {
        final intentInfo = IntentInfo(
          className: 'CreatePostIntent',
          identifier: 'com.example.createPost',
          title: 'Create Post',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'image',
              dartType: 'IntentFile?',
              title: 'Image',
              isOptional: true,
              fileType: 'public.image',
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('var imageFileInfo: [String: Any?]? = nil'));
        expect(result, contains('if let image'));
        expect(result, contains('image.data.write(to: tempUrl'));
        expect(result, contains('"path": tempUrl.path()'));
        expect(result, contains('"mimeType": image.type?.preferredMIMEType'));
        expect(result, contains('"filename": image.filename'));
        // Verify the serialized variable is used in params dict
        expect(result, contains('"image": imageFileInfo'));
      });

      test('generates file serialization code for required file param', () {
        final intentInfo = IntentInfo(
          className: 'UploadIntent',
          identifier: 'com.example.upload',
          title: 'Upload File',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'document',
              dartType: 'IntentFile',
              title: 'Document',
              isOptional: false,
              fileType: 'public.data',
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('let documentFileInfo: [String: Any?]'));
        expect(result, contains('document.data.write(to: documentTempUrl'));
        expect(result, contains('"document": documentFileInfo'));
      });

      test('generates mixed file and non-file params', () {
        final intentInfo = IntentInfo(
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
            IntentParamInfo(
              fieldName: 'image',
              dartType: 'IntentFile?',
              title: 'Image',
              isOptional: true,
              fileType: 'public.image',
            ),
          ],
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('var title: String'));
        expect(result, contains('var image: IntentFile?'));
        expect(result, contains('"title": title'));
        expect(result, contains('"image": imageFileInfo'));
      });
    });

    group('generateIntent with cache mode', () {
      test('generates cache perform method for foreground without urlScheme',
          () {
        final intentInfo = IntentInfo(
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
          supportedModes: IntentModeType.foreground,
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('AppIntentsPlugin.setPendingAction'));
        expect(result, contains('identifier: "com.example.createPost"'));
        expect(result, contains('params["title"] = title'));
        expect(result, contains('return .result()'));
        expect(result, isNot(contains('FlutterBridge')));
        expect(result, isNot(contains('UIApplication')));
      });

      test('generates import app_intents for cache mode', () {
        final intentInfo = IntentInfo(
          className: 'CreatePostIntent',
          identifier: 'com.example.createPost',
          title: 'Create Post',
          implementation: IntentImplementationType.dart,
          parameters: [],
          supportedModes: IntentModeType.foreground,
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('import app_intents'));
      });

      test('handles optional params in cache mode with if let', () {
        final intentInfo = IntentInfo(
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
            IntentParamInfo(
              fieldName: 'note',
              dartType: 'String?',
              title: 'Note',
              isOptional: true,
            ),
          ],
          supportedModes: IntentModeType.foreground,
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('params["title"] = title'));
        expect(result, contains('if let noteValue = note'));
        expect(result, contains('params["note"] = noteValue'));
      });

      test('generates cache mode with file params and serialization', () {
        final intentInfo = IntentInfo(
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
            IntentParamInfo(
              fieldName: 'image',
              dartType: 'IntentFile?',
              title: 'Image',
              isOptional: true,
              fileType: 'public.image',
            ),
          ],
          supportedModes: IntentModeType.foreground,
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('var imageFileInfo: [String: Any?]? = nil'));
        expect(result, contains('if let imageValue = imageFileInfo'));
        expect(result, contains('params["image"] = imageValue'));
        expect(result, contains('AppIntentsPlugin.setPendingAction'));
      });

      test('does not use cache mode when urlScheme is set', () {
        final intentInfo = IntentInfo(
          className: 'OpenAppIntent',
          identifier: 'com.example.openApp',
          title: 'Open App',
          implementation: IntentImplementationType.dart,
          parameters: [],
          urlScheme: 'myapp',
          urlAction: 'open',
          supportedModes: IntentModeType.foreground,
        );

        final result = generator.generateIntent(intentInfo);

        // URL scheme takes priority over cache mode
        expect(result, contains('UIApplication.shared.open'));
        expect(result, isNot(contains('AppIntentsPlugin.setPendingAction')));
      });

      test('generates cache mode with dialog', () {
        final intentInfo = IntentInfo(
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
          supportedModes: IntentModeType.foreground,
          resultDialogTemplate: 'Created "{title}"',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('AppIntentsPlugin.setPendingAction'));
        expect(result, contains('return .result(dialog:'));
      });
    });

    group('generateAll with file parameters', () {
      test('includes UniformTypeIdentifiers import when file params exist',
          () {
        final intents = [
          IntentInfo(
            className: 'CreatePostIntent',
            identifier: 'com.example.createPost',
            title: 'Create Post',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'image',
                dartType: 'IntentFile?',
                title: 'Image',
                isOptional: true,
                fileType: 'public.image',
              ),
            ],
          ),
        ];

        final result = generator.generateAll(intents: intents);

        expect(result, contains('import UniformTypeIdentifiers'));
      });

      test('omits UniformTypeIdentifiers import when no file params', () {
        final intents = [
          IntentInfo(
            className: 'GreetIntent',
            identifier: 'com.example.greet',
            title: 'Greet',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final result = generator.generateAll(intents: intents);

        expect(result, isNot(contains('import UniformTypeIdentifiers')));
      });
    });

    group('generateIntent error handling', () {
      test('URL scheme with no params throws on guard failure', () {
        final intentInfo = IntentInfo(
          className: 'GreetIntent',
          identifier: 'com.example.greet',
          title: 'Greet User',
          implementation: IntentImplementationType.dart,
          parameters: [],
          urlScheme: 'myapp',
          urlAction: 'greet',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('throw AppIntentError.custom('));
        expect(result, contains('URL_CONSTRUCTION_FAILED'));
      });

      test('URL scheme with params throws on guard failure', () {
        final intentInfo = IntentInfo(
          className: 'CreateTaskIntent',
          identifier: 'com.example.createTask',
          title: 'Create Task',
          implementation: IntentImplementationType.dart,
          parameters: [
            IntentParamInfo(
              fieldName: 'title',
              dartType: 'String',
              title: 'Task Title',
              isOptional: false,
            ),
          ],
          urlScheme: 'taskapp',
          urlAction: 'create',
        );

        final result = generator.generateIntent(intentInfo);

        expect(result, contains('guard let url = components.url else'));
        expect(result, contains('throw AppIntentError.custom('));
        expect(result, contains('URL_CONSTRUCTION_FAILED'));
      });
    });

    group('generateAll with URL scheme', () {
      test('includes UIKit import when URL scheme intents exist', () {
        final intents = [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [],
            urlScheme: 'taskapp',
            urlAction: 'create',
          ),
        ];

        final result = generator.generateAll(intents: intents);

        expect(result, contains('import UIKit'));
        expect(result, contains('openAppWhenRun'));
      });

      test('omits UIKit import when no URL scheme intents', () {
        final intents = [
          IntentInfo(
            className: 'GreetIntent',
            identifier: 'com.example.greet',
            title: 'Greet',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final result = generator.generateAll(intents: intents);

        expect(result, isNot(contains('import UIKit')));
      });
    });

    group('generateEntity', () {
      test('generates basic AppEntity struct', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('import AppIntents'));
        expect(result, contains('@available(iOS 17.0, *)'));
        expect(result, contains('struct TaskEntity: AppEntity'));
      });

      test('generates typeDisplayRepresentation', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('static var typeDisplayRepresentation: TypeDisplayRepresentation'));
        expect(result, contains('TypeDisplayRepresentation(name: "Task")'));
      });

      test('generates id property', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('var id: String'));
      });

      test('generates displayRepresentation with title', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
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
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('var displayRepresentation: DisplayRepresentation'));
        expect(result, contains('DisplayRepresentation(title: "\\(name)")'));
      });

      test('generates displayRepresentation with title and subtitle', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
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
              fieldName: 'description',
              dartType: 'String?',
              role: EntityPropertyRole.subtitle,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(
            result,
            contains(
                'DisplayRepresentation(title: "\\(name)", subtitle: "\\(description ?? "")")'));
      });

      test('generates entity properties', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
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
              fieldName: 'isCompleted',
              dartType: 'bool',
              role: EntityPropertyRole.none,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('var id: String'));
        expect(result, contains('var name: String'));
        expect(result, contains('var isCompleted: Bool'));
      });

      test('generates default query struct', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
          properties: [
            EntityPropertyInfo(
              fieldName: 'id',
              dartType: 'String',
              role: EntityPropertyRole.id,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('static var defaultQuery = TaskEntityQuery()'));
        expect(result, contains('struct TaskEntityQuery: EntityQuery'));
      });

      test('generates displayRepresentation with image', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
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
              fieldName: 'iconName',
              dartType: 'String',
              role: EntityPropertyRole.image,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('image: .init(systemName: iconName)'));
      });

      test('generates displayRepresentation with nullable image', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
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
              fieldName: 'iconName',
              dartType: 'String?',
              role: EntityPropertyRole.image,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('if let iconName'));
        expect(result, contains('image: .init(systemName: iconName)'));
      });

      test('generates query struct with image mapping', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntity',
          identifier: 'com.example.task',
          title: 'Task',
          pluralTitle: 'Tasks',
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
              fieldName: 'iconName',
              dartType: 'String?',
              role: EntityPropertyRole.image,
            ),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('let iconName = dict["iconName"] as? String'));
        expect(result, contains('iconName: iconName'));
      });

      test('uses entity identifier (not className) for FlutterBridge entityIdentifier', () {
        final entityInfo = EntityInfo(
          className: 'TaskEntitySpec',
          identifier: 'com.example.taskapp.TaskEntity',
          title: 'Task',
          pluralTitle: 'Tasks',
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

        final result = generator.generateEntity(entityInfo);

        // Should use identifier, not className
        expect(result, contains('entityIdentifier: "com.example.taskapp.TaskEntity"'));
        expect(result, isNot(contains('entityIdentifier: "TaskEntitySpec"')));
      });

      test('generates displayRepresentation with displayImageName', () {
        final entityInfo = EntityInfo(
          className: 'TeamEntity',
          identifier: 'com.example.team',
          title: 'Team',
          pluralTitle: 'Teams',
          displayImageName: 'team',
          properties: [
            EntityPropertyInfo(
                fieldName: 'id',
                dartType: 'String',
                role: EntityPropertyRole.id),
            EntityPropertyInfo(
                fieldName: 'name',
                dartType: 'String',
                role: EntityPropertyRole.title),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result,
            contains('image: .init(named: "team", isTemplate: true)'));
      });

      test(
          'displayImageName is fallback when @EntityImage property is nullable',
          () {
        final entityInfo = EntityInfo(
          className: 'TeamEntity',
          identifier: 'com.example.team',
          title: 'Team',
          pluralTitle: 'Teams',
          displayImageName: 'team',
          properties: [
            EntityPropertyInfo(
                fieldName: 'id',
                dartType: 'String',
                role: EntityPropertyRole.id),
            EntityPropertyInfo(
                fieldName: 'name',
                dartType: 'String',
                role: EntityPropertyRole.title),
            EntityPropertyInfo(
                fieldName: 'iconName',
                dartType: 'String?',
                role: EntityPropertyRole.image),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        // Per-instance image takes priority
        expect(result, contains('if let iconName'));
        expect(result, contains('image: .init(systemName: iconName)'));
        // Fallback to displayImageName
        expect(result,
            contains('image: .init(named: "team", isTemplate: true)'));
      });

      test('generates EnumerableEntityQuery extension when enumerable', () {
        final entityInfo = EntityInfo(
          className: 'TeamEntity',
          identifier: 'com.example.team',
          title: 'Team',
          pluralTitle: 'Teams',
          enumerable: true,
          properties: [
            EntityPropertyInfo(
                fieldName: 'id',
                dartType: 'String',
                role: EntityPropertyRole.id),
            EntityPropertyInfo(
                fieldName: 'name',
                dartType: 'String',
                role: EntityPropertyRole.title),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result,
            contains('extension TeamEntityQuery: EnumerableEntityQuery'));
        expect(result, contains('func allEntities()'));
        expect(result, contains('try await suggestedEntities()'));
      });

      test('does not generate EnumerableEntityQuery when not enumerable', () {
        final entityInfo = EntityInfo(
          className: 'TeamEntity',
          identifier: 'com.example.team',
          title: 'Team',
          pluralTitle: 'Teams',
          properties: [
            EntityPropertyInfo(
                fieldName: 'id',
                dartType: 'String',
                role: EntityPropertyRole.id),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, isNot(contains('EnumerableEntityQuery')));
      });

      test('generates IndexedEntity extension when indexed', () {
        final entityInfo = EntityInfo(
          className: 'TeamEntity',
          identifier: 'com.example.team',
          title: 'Team',
          pluralTitle: 'Teams',
          indexed: true,
          properties: [
            EntityPropertyInfo(
                fieldName: 'id',
                dartType: 'String',
                role: EntityPropertyRole.id),
            EntityPropertyInfo(
                fieldName: 'name',
                dartType: 'String',
                role: EntityPropertyRole.title),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, contains('import CoreSpotlight'));
        expect(result, contains('@available(iOS 26.0, *)'));
        expect(result, contains('extension TeamEntity: IndexedEntity'));
        expect(result,
            contains('var attributeSet: CSSearchableItemAttributeSet'));
        expect(result, contains('attributes.displayName = name'));
      });

      test('does not generate IndexedEntity when not indexed', () {
        final entityInfo = EntityInfo(
          className: 'TeamEntity',
          identifier: 'com.example.team',
          title: 'Team',
          pluralTitle: 'Teams',
          properties: [
            EntityPropertyInfo(
                fieldName: 'id',
                dartType: 'String',
                role: EntityPropertyRole.id),
          ],
        );

        final result = generator.generateEntity(entityInfo);

        expect(result, isNot(contains('IndexedEntity')));
        expect(result, isNot(contains('CoreSpotlight')));
      });
    });

    group('generateAppShortcutsProvider', () {
      test('generates AppShortcutsProvider with single shortcut', () {
        final shortcuts = [
          AppShortcutInfo(
            intentClassName: 'CreateTaskIntent',
            phrases: ['Create a task', 'Add new task'],
            shortTitle: 'Create Task',
            systemImageName: 'plus.circle',
          ),
        ];

        final result = generator.generateAppShortcutsProvider(shortcuts);

        expect(result, contains('import AppIntents'));
        expect(result, contains('@available(iOS 17.0, *)'));
        expect(result, contains('struct AppShortcuts: AppShortcutsProvider'));
        expect(result, contains('static var appShortcuts: [AppShortcut]'));
        expect(result, contains('AppShortcut('));
        expect(result, contains('intent: CreateTaskIntent()'));
        expect(result, contains('"Create a task"'));
        expect(result, contains('"Add new task"'));
        expect(result, contains('shortTitle: "Create Task"'));
        expect(result, contains('systemImageName: "plus.circle"'));
      });

      test('generates AppShortcutsProvider with multiple shortcuts', () {
        final shortcuts = [
          AppShortcutInfo(
            intentClassName: 'CreateTaskIntent',
            phrases: ['Create a task'],
            shortTitle: 'Create Task',
            systemImageName: 'plus.circle',
          ),
          AppShortcutInfo(
            intentClassName: 'ListTasksIntent',
            phrases: ['List my tasks'],
            shortTitle: 'List Tasks',
            systemImageName: 'list.bullet',
          ),
        ];

        final result = generator.generateAppShortcutsProvider(shortcuts);

        expect(result, contains('intent: CreateTaskIntent()'));
        expect(result, contains('intent: ListTasksIntent()'));
      });

      test('converts {applicationName} to Swift string interpolation', () {
        final shortcuts = [
          AppShortcutInfo(
            intentClassName: 'CreateTaskIntent',
            phrases: [
              'Create a task in {applicationName}',
              'Add new task',
            ],
            shortTitle: 'Create Task',
            systemImageName: 'plus.circle',
          ),
        ];

        final result = generator.generateAppShortcutsProvider(shortcuts);

        expect(result, contains(r'"Create a task in \(.applicationName)"'));
        expect(result, isNot(contains('{applicationName}')));
        expect(result, contains('"Add new task"'));
      });

      test('converts \${applicationName} to Swift string interpolation', () {
        final shortcuts = [
          AppShortcutInfo(
            intentClassName: 'CreateTaskIntent',
            phrases: [
              r'Create a task in ${applicationName}',
            ],
            shortTitle: 'Create Task',
            systemImageName: 'plus.circle',
          ),
        ];

        final result = generator.generateAppShortcutsProvider(shortcuts);

        expect(result, contains(r'"Create a task in \(.applicationName)"'));
        expect(result, isNot(contains(r'${applicationName}')));
      });

      test('converts {paramName} to Swift parameter reference', () {
        final shortcuts = [
          AppShortcutInfo(
            intentClassName: 'CompleteTaskIntent',
            phrases: [
              'Complete {target} in {applicationName}',
            ],
            shortTitle: 'Complete Task',
            systemImageName: 'checkmark.circle',
          ),
        ];

        final result = generator.generateAppShortcutsProvider(shortcuts);

        expect(
            result,
            contains(
                r'"Complete \(\.$target) in \(.applicationName)"'));
        expect(result, isNot(contains('{target}')));
      });

      test('converts multiple {paramName} in single phrase', () {
        final shortcuts = [
          AppShortcutInfo(
            intentClassName: 'MoveTaskIntent',
            phrases: [
              'Move {task} to {category} in {applicationName}',
            ],
            shortTitle: 'Move Task',
            systemImageName: 'arrow.right',
          ),
        ];

        final result = generator.generateAppShortcutsProvider(shortcuts);

        expect(
            result,
            contains(
                r'Move \(\.$task) to \(\.$category) in \(.applicationName)'));
      });
    });

    group('generateAll', () {
      test('generates combined Swift file with intents and entities', () {
        final intents = [
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
                isOptional: false,
              ),
            ],
          ),
        ];

        final entities = [
          EntityInfo(
            className: 'TaskEntity',
            identifier: 'com.example.task',
            title: 'Task',
            pluralTitle: 'Tasks',
            properties: [
              EntityPropertyInfo(
                fieldName: 'id',
                dartType: 'String',
                role: EntityPropertyRole.id,
              ),
            ],
          ),
        ];

        final result = generator.generateAll(
          intents: intents,
          entities: entities,
        );

        // Should contain single import at top
        expect(result.indexOf('import AppIntents'), isNonNegative);
        // Should contain AppIntentsBridge import (entities use FlutterBridge)
        expect(result, contains('import AppIntentsBridge'));
        // Should contain both intent and entity
        expect(result, contains('struct CreateTaskIntent: AppIntent'));
        expect(result, contains('struct TaskEntity: AppEntity'));
      });

      test('generateAll includes import AppIntentsBridge when entities exist',
          () {
        final entities = [
          EntityInfo(
            className: 'TaskEntity',
            identifier: 'com.example.task',
            title: 'Task',
            pluralTitle: 'Tasks',
            properties: [
              EntityPropertyInfo(
                fieldName: 'id',
                dartType: 'String',
                role: EntityPropertyRole.id,
              ),
            ],
          ),
        ];

        final result = generator.generateAll(entities: entities);

        expect(result, contains('import AppIntentsBridge'));
      });

      test(
          'generateAll does not include import AppIntentsBridge for URL scheme only',
          () {
        final intents = [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            urlScheme: 'taskapp',
            urlAction: 'create',
            parameters: [],
          ),
        ];

        final result = generator.generateAll(intents: intents);

        expect(result, isNot(contains('import AppIntentsBridge')));
      });

      test('generates combined Swift file with shortcuts', () {
        final intents = [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [],
          ),
        ];

        final shortcuts = [
          AppShortcutInfo(
            intentClassName: 'CreateTaskIntent',
            phrases: ['Create a task'],
            shortTitle: 'Create Task',
            systemImageName: 'plus.circle',
          ),
        ];

        final result = generator.generateAll(
          intents: intents,
          entities: [],
          shortcuts: shortcuts,
        );

        expect(result, contains('struct CreateTaskIntent: AppIntent'));
        expect(result, contains('struct AppShortcuts: AppShortcutsProvider'));
      });
    });

    group('generateEnum', () {
      test('generates basic AppEnum', () {
        final enumInfo = EnumInfo(
          className: 'TaskPriority',
          identifier: 'com.example.taskPriority',
          title: 'Priority',
          cases: [
            EnumCaseInfo(name: 'high', displayTitle: 'High'),
            EnumCaseInfo(name: 'medium', displayTitle: 'Medium'),
            EnumCaseInfo(name: 'low', displayTitle: 'Low'),
          ],
        );

        final result = generator.generateEnum(enumInfo);

        expect(result, contains('import AppIntents'));
        expect(result, contains('@available(iOS 17.0, *)'));
        expect(result, contains('enum TaskPriority: String, AppEnum'));
        expect(result, contains('case high'));
        expect(result, contains('case medium'));
        expect(result, contains('case low'));
        expect(result, contains('static var typeDisplayRepresentation: TypeDisplayRepresentation = "Priority"'));
        expect(result, contains('static var caseDisplayRepresentations: [TaskPriority: DisplayRepresentation]'));
        expect(result, contains('.high: "High"'));
        expect(result, contains('.medium: "Medium"'));
        expect(result, contains('.low: "Low"'));
      });

      test('generates caseDisplayRepresentations with image', () {
        final enumInfo = EnumInfo(
          className: 'FeedCategory',
          identifier: 'com.example.category',
          title: 'Category',
          cases: [
            EnumCaseInfo(
                name: 'feed', displayTitle: 'Feed', imageName: 'feed'),
            EnumCaseInfo(name: 'explore', displayTitle: 'Explore'),
          ],
        );

        final result = generator.generateEnum(enumInfo);

        expect(
            result,
            contains('.feed: .init(title: "Feed", '
                'image: .init(named: "feed", isTemplate: true))'));
        expect(result, contains('.explore: "Explore"'));
      });
    });

    group('generateAll with enums', () {
      test('generates enums before intents', () {
        final enums = [
          EnumInfo(
            className: 'TaskPriority',
            identifier: 'com.example.taskPriority',
            title: 'Priority',
            cases: [
              EnumCaseInfo(name: 'high', displayTitle: 'High'),
              EnumCaseInfo(name: 'low', displayTitle: 'Low'),
            ],
          ),
        ];

        final intents = [
          IntentInfo(
            className: 'CreateTaskIntent',
            identifier: 'com.example.createTask',
            title: 'Create Task',
            implementation: IntentImplementationType.dart,
            parameters: [
              IntentParamInfo(
                fieldName: 'priority',
                dartType: 'String',
                title: 'Priority',
                isOptional: false,
                enumType: 'TaskPriority',
              ),
            ],
          ),
        ];

        final result = generator.generateAll(
          intents: intents,
          enums: enums,
        );

        // Enum should appear before intent
        final enumIndex = result.indexOf('enum TaskPriority');
        final intentIndex = result.indexOf('struct CreateTaskIntent');
        expect(enumIndex, lessThan(intentIndex));
        expect(result, contains('enum TaskPriority: String, AppEnum'));
        expect(result, contains('var priority: TaskPriority'));
      });
    });

    group('dartTypeToSwiftType', () {
      test('maps String to String', () {
        expect(generator.dartTypeToSwiftType('String'), equals('String'));
      });

      test('maps int to Int', () {
        expect(generator.dartTypeToSwiftType('int'), equals('Int'));
      });

      test('maps double to Double', () {
        expect(generator.dartTypeToSwiftType('double'), equals('Double'));
      });

      test('maps bool to Bool', () {
        expect(generator.dartTypeToSwiftType('bool'), equals('Bool'));
      });

      test('maps DateTime to Date', () {
        expect(generator.dartTypeToSwiftType('DateTime'), equals('Date'));
      });

      test('maps nullable types correctly', () {
        expect(generator.dartTypeToSwiftType('String?'), equals('String?'));
        expect(generator.dartTypeToSwiftType('int?'), equals('Int?'));
        expect(generator.dartTypeToSwiftType('DateTime?'), equals('Date?'));
      });

      test('returns original type for unknown types', () {
        expect(generator.dartTypeToSwiftType('CustomType'), equals('CustomType'));
      });
    });
  });
}
