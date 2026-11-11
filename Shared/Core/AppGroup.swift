import Foundation

/// Finds the App Group shared by the app and the widget extension.
///
/// Sideloading tools (Sideloadly, AltStore) may rename the group when they re-sign
/// the app with a free Apple ID, so the group is looked up in this order:
/// 1. the groups listed in the embedded provisioning profile (what the device really granted),
/// 2. the `AppGroupIdentifier` value in Info.plist,
/// 3. `group.<app bundle id>`.
/// The first candidate the system actually gives us a container for wins.
enum AppGroup {
    static let identifier: String? = resolve()

    static var defaults: UserDefaults {
        if let identifier, let shared = UserDefaults(suiteName: identifier) { return shared }
        return .standard
    }

    static var containerURL: URL {
        if let identifier,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    static var isShared: Bool { identifier != nil }

    // MARK: - Resolution

    private static func resolve() -> String? {
        var candidates: [String] = []
        candidates += provisioningProfileGroups()
        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
           !fromPlist.isEmpty, !fromPlist.contains("$(") {
            candidates.append(fromPlist)
        }
        if let appID = mainAppBundleIdentifier {
            candidates.append("group.\(appID)")
        }
        for candidate in candidates where !candidate.contains("*") {
            if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: candidate) != nil {
                return candidate
            }
        }
        return nil
    }

    /// The containing app's bundle id, also when running inside the widget extension.
    private static var mainAppBundleIdentifier: String? {
        var url = Bundle.main.bundleURL
        if url.pathExtension == "appex" {
            // .../Glassboard.app/PlugIns/GlassboardWidgets.appex
            url = url.deletingLastPathComponent().deletingLastPathComponent()
            return Bundle(url: url)?.bundleIdentifier
        }
        return Bundle.main.bundleIdentifier
    }

    /// Reads `com.apple.security.application-groups` from embedded.mobileprovision.
    private static func provisioningProfileGroups() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return [] }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String]
        else { return [] }
        return groups
    }
}
