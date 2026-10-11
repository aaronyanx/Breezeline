import Foundation
import Observation

struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = ""
    var text = ""
    var color = 0
    var tilt = Double.random(in: -2...2)
}

@MainActor @Observable
final class NoteStore {
    private(set) var notes: [Note] = []
    private(set) var errorMessage: String?
    private(set) var loadFailed = false
    var onChange: () -> Void = {}
    let file: URL
    private let moveToTrash: (URL) throws -> Void

    init(file: URL? = nil, moveToTrash: @escaping (URL) throws -> Void = {
        try FileManager.default.trashItem(at: $0, resultingItemURL: nil)
    }) {
        self.moveToTrash = moveToTrash
        self.file = file ?? Migration.notesFile
        guard FileManager.default.fileExists(atPath: self.file.path) else { return }
        do {
            notes = try JSONDecoder().decode([Note].self, from: Data(contentsOf: self.file))
            guard Set(notes.map(\.id)).count == notes.count,
                  notes.allSatisfy({ $0.tilt.isFinite }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
        } catch {
            loadFailed = true
            notes = []
            errorMessage = "Could not read your notes. The original file is preserved. Check \(self.file.path)"
        }
    }

    @discardableResult
    func add() -> UUID? {
        guard !loadFailed else { return nil }
        var note = Note()
        note.color = notes.count % 4
        notes.append(note)
        save()
        return note.id
    }

    func update(_ id: UUID, title: String, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].title = title
        notes[index].text = text
        save()
    }

    func setColor(_ id: UUID, to color: Int) {
        guard (0..<4).contains(color),
              let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].color = color
        save()
    }

    func move(_ id: UUID, to index: Int) {
        guard let source = notes.firstIndex(where: { $0.id == id }) else { return }
        let target = max(0, min(index, notes.count - 1))
        guard source != target else { return }
        let note = notes.remove(at: source)
        notes.insert(note, at: target)
        save()
    }

    func reorder(_ order: [UUID]) {
        guard order.count == notes.count, Set(order) == Set(notes.map(\.id)) else { return }
        let byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        notes = order.compactMap { byID[$0] }
        save()
    }

    @discardableResult
    func remove(_ id: UUID) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return false }
        let note = notes[index]
        let discardedFile = file.deletingLastPathComponent()
            .appendingPathComponent("Breezeline-\(id.uuidString).json")
        do {
            try JSONEncoder().encode(note).write(to: discardedFile, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: discardedFile.path)
            try moveToTrash(discardedFile)
        } catch {
            errorMessage = "The note was not deleted. Could not move it to Trash. Check folder permissions and try again."
            return false
        }
        let previous = notes
        notes.remove(at: index)
        save()
        if errorMessage != nil {
            notes = previous
            return false
        }
        return true
    }

    func save() {
        guard !loadFailed else { return }
        defer { onChange() }
        do {
            let folder = file.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(notes)
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            errorMessage = nil
        } catch {
            errorMessage = "Your changes are still in this session. Check disk space and folder permissions, then choose Retry Save."
        }
    }
}
