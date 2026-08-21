import 'package:app_intents_codegen/src/cli/analyze_sources.dart';
import 'package:app_intents_codegen/src/models/widget_configuration_info.dart';
import 'package:test/test.dart';

const _widgetConfig = WidgetConfigurationInfo(
  className: 'SelectTeamWidgetConfig',
  identifier: 'com.example.selectTeam',
  title: 'Displayed team',
  parameters: [
    WidgetParamInfo(
      name: 'showCompleted',
      dartType: 'bool',
      title: 'Show completed',
    ),
  ],
);

void main() {
  group('AnalyzeResult', () {
    test('isEmpty is true when nothing was found', () {
      const result = AnalyzeResult(
        intents: [],
        entities: [],
        enums: [],
        shortcuts: [],
      );

      expect(result.isEmpty, isTrue);
      expect(result.hasAppTargetAnnotations, isFalse);
    });

    test(
      'a widget-configuration-only project has nothing for the app target',
      () {
        // `generate_swift` gates on hasAppTargetAnnotations, so it must stay
        // false here — otherwise it writes an otherwise-empty
        // GeneratedAppIntents.swift for a project whose output belongs to
        // `generate_widget_swift` and a separate Xcode target.
        const result = AnalyzeResult(
          intents: [],
          entities: [],
          enums: [],
          shortcuts: [],
          widgetConfigurations: [_widgetConfig],
        );

        expect(result.hasAppTargetAnnotations, isFalse);
        // The overall result is still non-empty: there *is* something to
        // generate, just not here.
        expect(result.isEmpty, isFalse);
      },
    );
  });
}
