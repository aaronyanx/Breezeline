import AppKit
import SwiftUI

struct NoteDragArea: NSViewRepresentable {
    let note: Note
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void
    let onDrag: (Bool) -> Void

    func makeNSView(context: Context) -> NoteDragView {
        let view = NoteDragView()
        configure(view)
        return view
    }

    func updateNSView(_ view: NoteDragView, context: Context) { configure(view) }

    private func configure(_ view: NoteDragView) {
        view.note = note
        view.onEdit = onEdit
        view.onDelete = onDelete
        view.onMove = onMove
        view.onDrag = onDrag
        view.setAccessibilityElement(true)
        view.setAccessibilityLabel(note.title.isEmpty ? "Untitled" : note.title)
        view.setAccessibilityRole(.button)
        view.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: "Edit", handler: { onEdit(); return true }),
            NSAccessibilityCustomAction(name: "Move to Trash", handler: { onDelete(); return true }),
        ])
    }
}

final class NoteDragView: NSView, NSDraggingSource {
    var note = Note()
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    var onMove: (Int) -> Void = { _ in }
    var onDrag: (Bool) -> Void = { _ in }
    private var downPoint: NSPoint?
    private var dragging = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func accessibilityPerformPress() -> Bool {
        onEdit()
        return true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if CGRect(x: 0, y: isFlipped ? 0 : bounds.height - 30, width: 30, height: 30).contains(point) {
            downPoint = nil
            onDelete()
            return
        }
        downPoint = event.locationInWindow
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = downPoint, !dragging,
              hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) > 4 else { return }
        let text = [note.title, note.text].filter { !$0.isEmpty }.joined(separator: "\n\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Breezeline-\(UUID().uuidString).txt")
        do {
            try Data(text.utf8).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            NSSound.beep()
            return
        }
        let entry = NSPasteboardItem()
        entry.setString(text, forType: .string)
        entry.setString(url.absoluteString, forType: .fileURL)
        let item = NSDraggingItem(pasteboardWriter: entry)
        let renderer = ImageRenderer(content: NotePaper(note: note))
        renderer.scale = window?.backingScaleFactor ?? 2
        item.setDraggingFrame(bounds, contents: renderer.nsImage)
        dragging = true
        onDrag(true)
        beginDraggingSession(with: [item], event: event, source: self)
            .animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        if downPoint != nil && !dragging { onEdit() }
        downPoint = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(NoteMenuAction("Edit", handler: onEdit))
        menu.addItem(NoteMenuAction("Move Left") { self.onMove(-1) })
        menu.addItem(NoteMenuAction("Move Right") { self.onMove(1) })
        menu.addItem(.separator())
        menu.addItem(NoteMenuAction("Move to Trash", handler: onDelete))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .delete] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        dragging = false
        downPoint = nil
        onDrag(false)
        if operation.contains(.delete) { onDelete() }
        // The exported text stays in the system temp directory so destinations can read it after the drag.
    }
}

private final class NoteMenuAction: NSMenuItem {
    private let handler: () -> Void
    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func run() { handler() }
}
