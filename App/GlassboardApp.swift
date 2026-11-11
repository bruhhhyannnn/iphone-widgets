import SwiftUI

@main
struct GlassboardApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Glassboard")
                .padding()
                .glassEffect(.regular, in: .capsule)
        }
    }
}
