import AppKit

enum Migration {
    static let support = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask)[0]
    static let notesFile = support.appendingPathComponent("Breezeline/notes.json")

    static func prepare() throws {
        // Legacy apps have independent stores and screenshot settings; never import a live session.
        let legacyIDs = ["com.aaronyanx.Hangline", "com.aaronyanx.Hangnotes"]
        guard !NSWorkspace.shared.runningApplications.contains(where: {
            legacyIDs.contains($0.bundleIdentifier ?? "")
        }) else {
            let alert = NSAlert()
            alert.messageText = "Close Hangline and Hangnotes First"
            alert.informativeText = "Breezeline replaces both apps. Quit them, then open Breezeline again. Your original data will be preserved."
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            throw CocoaError(.userCancelled)
        }

        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "legacyImportCompleted") else { return }
        let folder = notesFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let legacyFile = support.appendingPathComponent("Hangnotes/notes.json")
        if !FileManager.default.fileExists(atPath: notesFile.path),
           FileManager.default.fileExists(atPath: legacyFile.path) {
            // Copy instead of moving; the old app and its recovery file remain intact.
            let data = try Data(contentsOf: legacyFile)
            let notes = try JSONDecoder().decode([Note].self, from: data)
            guard Set(notes.map(\.id)).count == notes.count,
                  notes.allSatisfy({ $0.tilt.isFinite }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try data.write(to: notesFile, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: notesFile.path)
        }
        let legacy = defaults.persistentDomain(forName: "com.aaronyanx.Hangline") ?? [:]
        for key in ["pegged", "mixedOrder", "soundOff", "clipboardDisabled"] {
            if defaults.object(forKey: key) == nil, let value = legacy[key] {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: "legacyImportCompleted")
    }
}
