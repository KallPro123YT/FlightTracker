import SwiftUI
import CoreLocation
import ActivityKit
import UserNotifications

public struct FlightWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var planesCount: Int
        public var alertMessage: String
        public init(planesCount: Int, alertMessage: String) {
            self.planesCount = planesCount
            self.alertMessage = alertMessage
        }
    }
    public var radiusKm: Int
    public init(radiusKm: Int) {
        self.radiusKm = radiusKm
    }
}

class LocationAndFlightManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var nearbyPlanesCount: Int = 0
    @Published var closestFlightCallsign: String = "Searching..."
    private var currentActivity: Activity<FlightWidgetAttributes>? = nil

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func startTracking() {
        locationManager.startUpdatingLocation()
        startLiveActivity()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task {
            await fetchNearbyPlanes(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        }
    }

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if currentActivity != nil { return }
        
        let attributes = FlightWidgetAttributes(radiusKm: 10)
        let initialState = FlightWidgetAttributes.ContentState(planesCount: 0, alertMessage: "Scanning skies...")
        let content = ActivityContent(state: initialState, staleDate: nil)
        
        do {
            currentActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            print("Live Activity failed to start: \(error)")
        }
    }

    func updateLiveActivity(count: Int, message: String) {
        Task {
            let updatedState = FlightWidgetAttributes.ContentState(planesCount: count, alertMessage: message)
            let content = ActivityContent(state: updatedState, staleDate: nil)
            await currentActivity?.update(content)
        }
    }

    func triggerNotification(flight: String) {
        let content = UNMutableNotificationContent()
        content.title = "✈️ Flight Overhead!"
        content.body = "Aircraft \(flight) just passed inside your 10km radius."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func fetchNearbyPlanes(lat: Double, lon: Double) async {
        let urlString = "https://api.adsb.lol/v2/lat/\(lat)/lon/\(lon)/dist/10"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let acList = json["ac"] as? [[String: Any]] {
                
                let count = acList.count
                var callsign = "Clear Skies"
                
                if let firstPlane = acList.first, let flightName = firstPlane["flight"] as? String {
                    callsign = flightName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if count > 0 {
                        triggerNotification(flight: callsign)
                    }
                }

                DispatchQueue.main.async {
                    self.nearbyPlanesCount = count
                    self.closestFlightCallsign = callsign
                    self.updateLiveActivity(count: count, message: count > 0 ? "Closest: \(callsign)" : "No immediate flights")
                }
            }
        } catch {
            print("API error: \(error)")
        }
    }
}

struct ContentView: View {
    @StateObject private var manager = LocationAndFlightManager()

    var body: some View {
        VBox(spacing: 25) {
            Image(systemName: "airplane.circle.fill")
                .resizable()
                .frame(width: 110, height: 110)
                .foregroundColor(.blue)
            
            VBox(spacing: 8) {
                Text("Planes Nearby: \(manager.nearbyPlanesCount)")
                    .font(.title2)
                    .bold()
                Text("Current Active Target: \(manager.closestFlightCallsign)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                manager.requestPermissions()
                manager.startTracking()
            }) {
                Text("Initialize Active Radar Overlay")
                    .bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
