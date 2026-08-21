// Minimal WidgetKit widget for the example app.
//
// Its only job is to exercise the generated `SelectTaskWidgetConfig`
// (`GeneratedIntents/GeneratedWidgetIntents.swift`) in a real Widget Extension
// target, so the App Group cache path is compiled the way a downstream app
// would compile it. The view itself is deliberately plain.
import AppIntents
import SwiftUI
import WidgetKit

struct TaskEntry: TimelineEntry {
    let date: Date
    let title: String
}

struct TaskTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), title: "Task")
    }

    func snapshot(for configuration: SelectTaskWidgetConfig, in context: Context) async -> TaskEntry {
        TaskEntry(date: Date(), title: configuration.task?.title ?? "No task selected")
    }

    func timeline(for configuration: SelectTaskWidgetConfig, in context: Context) async -> Timeline<TaskEntry> {
        // An unconfigured instance has no task; fall back rather than baking in
        // an add-time snapshot. See `generateDefaultResult` in
        // `@WidgetConfigurationSpec`.
        let entry = TaskEntry(date: Date(), title: configuration.task?.title ?? "No task selected")
        return Timeline(entries: [entry], policy: .never)
    }
}

struct TaskWidgetView: View {
    let entry: TaskEntry

    var body: some View {
        Text(entry.title)
    }
}

struct TaskWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "TaskWidget",
            intent: SelectTaskWidgetConfig.self,
            provider: TaskTimelineProvider()
        ) { entry in
            TaskWidgetView(entry: entry)
        }
    }
}

@main
struct TaskWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaskWidget()
    }
}
