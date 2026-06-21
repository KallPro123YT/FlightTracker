import WidgetKit
import SwiftUI
import ActivityKit

public struct FlightWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var planesCount: Int
        public var alertMessage: String
    }
    public var radiusKm: Int
}

@main
struct FlightTrackerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightWidgetAttributes.self) { context in
            VBox(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Planes nearby", systemImage: "airplane")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.blue)
                    Spacer()
                    Text("within \(context.attributes.radiusKm) km")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(context.state.planesCount)")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.blue)
                    Text("planes")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                    Spacer()
                }
                
                Text(context.state.alertMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("✈️ Radar")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.planesCount) Actv")
                        .bold()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.alertMessage)
                        .font(.subheadline)
                }
            } compactLeading: {
                Text("✈️ \(context.state.planesCount)")
                    .foregroundColor(.blue)
            } compactTrailing: {
                Text("Nearby")
            } minimal: {
                Text("\(context.state.planesCount)")
                    .bold()
            }
        }
    }
}
