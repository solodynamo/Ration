import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService so the rest of the app doesn't touch
/// login-item plumbing directly.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Best-effort: login-item registration can fail for an
            // unsigned/unbundled build. Not worth surfacing to the user.
        }
    }
}
