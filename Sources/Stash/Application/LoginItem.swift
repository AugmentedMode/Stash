import ServiceManagement

/// Open at login through the system Login Items list, so users can also manage it in System Settings.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }
    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
