import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    if let existing = NSRunningApplication.runningApplications(
        withBundleIdentifier: "com.aaronyanx.Breezeline").first(where: {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }) {
        existing.activate(options: [])
        exit(0)
    }
    do {
        try Migration.prepare()
    } catch {
        if (error as NSError).code != CocoaError.userCancelled.rawValue {
            let alert = NSAlert()
            alert.messageText = "Could Not Import Your Notes"
            alert.informativeText = "Your original files are unchanged. \(error.localizedDescription)"
            alert.addButton(withTitle: "OK")
            app.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        exit(1)
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
