import SwiftUI
import WidgetKit

// v156: the Home Screen widget (its views and data are in ios/Shared)
@main
struct FlappyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlappyWidget", provider: FlappyProvider()) { e in FlappyWidgetView(e: e) }
            .configurationDisplayName("Flappy Bird")
            .description("Your bird, your best, your Daily streak and today's Daily.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
