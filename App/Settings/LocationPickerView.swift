import CoreLocation
import MapKit
import SwiftUI

/// One-shot GPS fix, waiting for the permission prompt if needed.
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func currentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                finish(.failure(CLError(.denied)))
            default:
                manager.requestLocation()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .notDetermined: break
        case .denied, .restricted: finish(.failure(CLError(.denied)))
        default: manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last { finish(.success(location)) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

struct LocationPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isLocating = false
    @State private var errorText: String?
    @State private var fetcher = LocationFetcher()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        HStack {
                            Label("Use my current location", systemImage: "location.fill")
                            Spacer()
                            if isLocating { ProgressView() }
                        }
                    }
                    .disabled(isLocating)
                } footer: {
                    Text("Your location is saved on this iPhone only. It's used for sun times and weather.")
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }

                if !results.isEmpty {
                    Section("Results") {
                        ForEach(results, id: \.self) { item in
                            Button {
                                choose(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unknown place").foregroundStyle(Color.primary)
                                    if let detail = item.placemark.title {
                                        Text(detail).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if let current = model.global.location {
                    Section("Current") {
                        LabeledContent(current.name, value: String(format: "%.2f, %.2f", current.latitude, current.longitude))
                        Button("Remove location", role: .destructive) {
                            model.global.location = nil
                            dismiss()
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for a city")
            .onSubmit(of: .search) { Task { await search() } }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = .address
        do {
            let response = try await MKLocalSearch(request: request).start()
            results = response.mapItems
            errorText = results.isEmpty ? "No places found." : nil
        } catch {
            errorText = "Search failed: \(error.localizedDescription)"
        }
    }

    private func choose(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        model.global.location = SavedLocation(name: item.name ?? "Here", latitude: coordinate.latitude,
                                              longitude: coordinate.longitude, timeZoneID: item.timeZone?.identifier)
        Task { await model.refreshData(force: true) }
        dismiss()
    }

    private func useCurrentLocation() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let location = try await fetcher.currentLocation()
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            let name = placemark?.locality ?? placemark?.name ?? "Current location"
            model.global.location = SavedLocation(name: name, latitude: location.coordinate.latitude,
                                                  longitude: location.coordinate.longitude,
                                                  timeZoneID: placemark?.timeZone?.identifier ?? TimeZone.current.identifier)
            await model.refreshData(force: true)
            dismiss()
        } catch {
            errorText = "Couldn't get your location. Check Settings › Privacy › Location Services, or search for your city instead."
        }
    }
}
