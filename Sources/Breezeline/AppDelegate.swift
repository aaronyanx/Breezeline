import AppKit
import Carbon
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let line = Line()
    private var panel: LinePanel!
    private var statusItem: NSStatusItem!
    private var watcher: ScreenshotWatcher!
    /// In inbox mode, a second watcher on the Desktop. If a macOS version
    /// ignores the screenshot settings (macOS 27 renamed one), captures keep
    /// landing on the Desktop, and they still hang on the line.
    private var safetyWatcher: ScreenshotWatcher?
    private var signalSources: [DispatchSourceSignal] = []
    private var hotKey: HotKey?
    private var cancellables = Set<AnyCancellable>()
    private var mouseTimer: Timer?
    private var clipboardWatcher: ClipboardWatcher?
    private var visibility = LineVisibility(
        alwaysVisible: UserDefaults.standard.bool(forKey: "keepLineVisible"))
    private let notes = NoteStore()
    private var editor: NSWindow?
    private var editingNoteID: UUID?
    private var clipboardEnabled: Bool {
        get { !UserDefaults.standard.bool(forKey: "clipboardDisabled") }
        set { UserDefaults.standard.set(!newValue, forKey: "clipboardDisabled") }
    }

    /// Whether the panel is ordered in. It can be in and still tucked away
    /// above the top edge, like an auto-hiding Dock.
    private var isPresent = false
    /// Whether the line has slid down into view.
    private var isRevealed = false
    private var lastLiveCount = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditingMenu()
        Handwriting.register()
        line.notesAvailable = !notes.loadFailed
        line.syncNotes(notes.notes, file: notes.file)
        notes.onChange = { [weak self] in
            // Wait until a failed deletion has rolled back before refreshing the rope.
            DispatchQueue.main.async {
                guard let self else { return }
                self.line.syncNotes(self.notes.notes, file: self.notes.file)
            }
        }
        let host = NSHostingView(rootView: LineView(line: line))
        host.sizingOptions = []
        panel = LinePanel(content: host)
        panel.placeOnScreen()
        updateCapacity()

        if Inbox.isEnabled { Inbox.apply() }
        restoreSettingsOnTermination()
        startWatcher()
        clipboardWatcher = ClipboardWatcher { [weak self] url in self?.hangCapture(url) }
        if clipboardEnabled { clipboardWatcher?.start() }

        hotKey = HotKey(keyCode: kVK_ANSI_T, modifiers: controlKey | optionKey) { [weak self] in
            self?.toggle()
        }

        setUpStatusItem()
        line.onNoteEdit = { [weak self] in self?.editNote($0) }
        line.onNoteDiscard = { [weak self] in self?.deleteNote($0) }
        line.onNotesReordered = { [weak self] in self?.notes.reorder($0) }
        line.onNewNote = { [weak self] in self?.addNote() }
        startMouseTracking()

        Markup.shared.onSaved = { [weak self] url in self?.line.reloadThumbnail(for: url) }
        line.onFall = { [weak self] item in self?.fall(item) }

        line.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.itemsChanged() }
            .store(in: &cancellables)

        // Entering or leaving full screen switches Space. Check again once the
        // switch animation has settled.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refresh()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self?.refresh() }
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panel.placeOnScreen()
                self?.updateCapacity()
            }
        }

        if !Inbox.wasOffered {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.offerInbox() }
        }

        refresh()
        tick()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher?.stop()
        stopMouseTracking()
        if Inbox.isEnabled { Inbox.restore() }
    }

    // MARK: Inbox mode

    private func startWatcher() {
        watcher?.stop()
        safetyWatcher?.stop()
        safetyWatcher = nil
        watcher = ScreenshotWatcher(
            onNew: { [weak self] url in self?.hangCapture(url) },
            onChange: { [weak self] in self?.line.prune() })
        watcher.start()
        if Inbox.isEnabled, watcher.folder.standardizedFileURL != ScreenshotWatcher.desktop.standardizedFileURL {
            let safety = ScreenshotWatcher(
                folder: ScreenshotWatcher.desktop,
                onNew: { [weak self] url in
                    log.notice("Screenshot landed on the Desktop despite inbox mode: \(url.lastPathComponent, privacy: .public)")
                    self?.hangCapture(url)
                },
                onChange: { [weak self] in self?.line.prune() })
            safety.start()
            safetyWatcher = safety
        }
    }

    private func setInbox(_ on: Bool) {
        Inbox.isEnabled = on
        if on { Inbox.apply() } else { Inbox.restore() }
        startWatcher()
    }

    /// Asked once. Changing system settings is the user's call, never ours.
    private func offerInbox() {
        Inbox.wasOffered = true
        let alert = NSAlert()
        alert.messageText = L("Let Breezeline handle your screenshots?")
        alert.informativeText = L(
            "Screenshots will hang on the line the instant you take them, without the floating thumbnail, and will not pile up on your Desktop. Drag one to a folder to keep it, or discard it with the cross. You can turn this off from the menu bar, and your settings come back when Breezeline quits.")
        alert.addButton(withTitle: L("Turn on"))
        alert.addButton(withTitle: L("Not now"))
        alert.icon = NSApp.applicationIconImage
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { setInbox(true) }
    }

    /// Quitting from the menu or logging out runs applicationWillTerminate.
    /// A plain kill does not, so settings are also restored on those signals.
    private func restoreSettingsOnTermination() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                if Inbox.isEnabled { Inbox.restore() }
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    // MARK: Showing and hiding

    private func itemsChanged() {
        let live = line.liveCount
        if live > lastLiveCount {
            updateCapacity()
            refresh()
        }
        lastLiveCount = live
    }

    // MARK: The capture flying to the line

    /// A new screenshot lifts off from where it was taken and flies to its
    /// place on the line. Without a known capture area it simply drops in.
    private func hangCapture(_ url: URL) {
        let from = captureRect(of: url)
        guard let id = line.hang(url, flying: from != nil) else { return }
        let screen = from.flatMap { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            return NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) }
        }
        panel.placeOnScreen(screen)
        updateCapacity()
        // Reveal on successful import, even when replacing a card on a full line.
        visibility.revealNewImage()
        refresh()
        guard let from else { return }
        // Let the line come down and lay out before measuring the landing spot.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.fly(id, from: from)
        }
    }

    private func fly(_ id: UUID, from: CGRect) {
        guard isPresent, isRevealed, let screen = panel.screen,
              let to = cardFrame(for: id),
              let item = line.items.first(where: { $0.id == id }) else {
            line.land(id)
            return
        }
        let pixels = Int(max(from.width, from.height) * screen.backingScaleFactor)
        guard let image = makeThumbnail(item.url, maxPixels: min(3000, max(400, pixels)))?
            .cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            line.land(id)
            return
        }
        CaptureFlight.fly(image: image, from: from, to: to, tilt: CGFloat(item.tilt), on: screen) { [weak self] in
            self?.line.land(id)
        }
    }

    /// A discarded card falls over the whole screen, from where it hangs.
    private func fall(_ item: Pegged) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        if item.note != nil {
            guard isPresent, isRevealed, let screen = panel.screen,
                  let rect = line.hitRects[item.id],
                  let paper = item.thumb.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let frame = panel.convertToScreen(NSRect(
                x: rect.minX, y: panel.frame.height - rect.maxY, width: rect.width, height: rect.height))
            PaperFall.run(image: paper, card: frame, tilt: CGFloat(item.tilt), on: screen)
            return
        }
        guard isPresent, isRevealed, !item.flying, let screen = panel.screen,
              let card = cardFrame(for: item.id),
              let image = item.thumb.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        CaptureFlight.fall(image: image, card: card, tilt: CGFloat(item.tilt), on: screen)
    }

    /// Where a card will hang, in screen coordinates, using the same layout
    /// as the line view.
    private func cardFrame(for id: UUID) -> CGRect? {
        guard let index = line.items.firstIndex(where: { $0.id == id }) else { return nil }
        let width = panel.frame.width
        if let rect = line.hitRects[id] {
            return panel.convertToScreen(NSRect(x: rect.minX, y: panel.frame.height - rect.maxY,
                                                width: rect.width, height: rect.height))
        }
        let x = line.x(index: index, width: width)
        let viewTop = Layout.ropeY(x: x, width: width) - Layout.pinAbove
        let cardTop = viewTop + PeggedView.cardOffsetBelowTop
        let size = PeggedView.cardSize(for: line.items[index].thumb.size)
        return CGRect(x: panel.frame.minX + x - size.width / 2,
                      y: panel.frame.maxY - cardTop - size.height,
                      width: size.width, height: size.height)
    }

    /// Full screen apps keep the line hidden without changing the user's choice.
    private func refresh() {
        let blocked = panel.screen.map(FullScreen.isActive(on:))
            ?? LinePanel.screenUnderPointer().map(FullScreen.isActive(on:)) ?? false
        if visibility.isVisible && !blocked {
            present()
            setRevealed(true)
        } else {
            dismiss()
        }
    }

    private func present() {
        guard !isPresent else { return }
        isPresent = true
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    private func dismiss() {
        guard isPresent else { return }
        isPresent = false
        setRevealed(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.isPresent else { return }
            self.panel.orderOut(nil)
        }
    }

    private func setRevealed(_ on: Bool) {
        guard on != isRevealed else { return }
        isRevealed = on
        line.revealed = on
        if !on {
            panel.ignoresMouseEvents = true
        }
    }

    @objc private func toggle() {
        visibility.toggle()
        refresh()
    }

    private func setAlwaysVisible(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "keepLineVisible")
        visibility.setAlwaysVisible(on)
        if on {
            panel.placeOnScreen()
            updateCapacity()
        }
        refresh()
    }

    private func startMouseTracking() {
        guard mouseTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        mouseTimer = timer
    }

    private func stopMouseTracking() {
        mouseTimer?.invalidate()
        mouseTimer = nil
        panel.ignoresMouseEvents = true
    }

    /// The menu bar strip at the top of a screen. With an auto-hiding menu
    /// bar the visible frame reaches the top, so the system thickness is used.
    static func menuBarBand(of screen: NSScreen) -> NSRect {
        var h = screen.frame.maxY - screen.visibleFrame.maxY
        if h < 1 { h = max(NSStatusBar.system.thickness, screen.safeAreaInsets.top) }
        return NSRect(x: screen.frame.minX, y: screen.frame.maxY - h, width: screen.frame.width, height: h)
    }

    private func tick() {
        let mouse = NSEvent.mouseLocation

        let screenUnderPointer = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
        let inMenuBar = screenUnderPointer.map { NSMouseInRect(mouse, Self.menuBarBand(of: $0), false) } ?? false
        var zone = panel.frame
        if let screen = panel.screen { zone.size.height = screen.frame.maxY - zone.minY }
        let wasVisible = visibility.isVisible
        visibility.updateHover(
            inMenuBar: inMenuBar,
            insideLine: isRevealed && NSMouseInRect(mouse, zone, false),
            busy: GrabView.isDragging || line.draggingID != nil || line.pressedID != nil ||
                line.reorderingID != nil || editor != nil)
        if wasVisible != visibility.isVisible {
            if visibility.isVisible, let screen = screenUnderPointer {
                panel.placeOnScreen(screen)
                updateCapacity()
            }
            refresh()
        }
        if isRevealed { updateMousePassThrough(mouse) }
    }

    /// The panel spans the whole width of the screen, so it only accepts the
    /// mouse while the cursor is over a photo. Everywhere else, clicks go to
    /// whatever is underneath.
    private func updateMousePassThrough(_ mouse: NSPoint) {
        guard !GrabView.isDragging && line.draggingID == nil else { return }
        if line.reorderingID != nil {
            panel.ignoresMouseEvents = false
            return
        }
        let local = panel.convertPoint(fromScreen: mouse)
        let flipped = CGPoint(x: local.x, y: panel.frame.height - local.y)
        let overPhoto = line.hitRects.values.contains { $0.insetBy(dx: -4, dy: -4).contains(flipped) }
            || line.clipHitRects.values.contains { $0.insetBy(dx: -4, dy: 0).contains(flipped) }
        let plusX = panel.frame.width - 24
        let plusY = Layout.ropeY(x: plusX, width: panel.frame.width) + 24
        let plus = line.notesAvailable &&
            CGRect(x: plusX - 18, y: plusY - 18, width: 36, height: 36).contains(flipped)
        if panel.ignoresMouseEvents == (overPhoto || plus) {
            panel.ignoresMouseEvents = !(overPhoto || plus)
        }
    }

    private func updateCapacity() {
        let usable = panel.frame.width - Layout.cardWidth - 84
        line.maxItems = max(3, min(12, Int(usable / line.spacing) + 1))
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = Bundle.main.url(forResource: "Breezeline-menu", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "Breezeline")
        image?.size = NSSize(width: 18, height: 18)
        image?.accessibilityDescription = "Breezeline"
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Breezeline"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let keepVisible = ClosureMenuItem("Keep Line Visible") { [weak self] in
            guard let self else { return }
            self.setAlwaysVisible(!self.visibility.alwaysVisible)
        }
        keepVisible.state = visibility.alwaysVisible ? .on : .off
        menu.addItem(keepVisible)

        let toggleItem = ClosureMenuItem(visibility.enabled ? "Pause Line" : "Resume Line") { [weak self] in
            self?.toggle()
        }
        toggleItem.keyEquivalent = "t"
        toggleItem.keyEquivalentModifierMask = [.control, .option]
        menu.addItem(toggleItem)
        let newNote = ClosureMenuItem("New Note", key: "n") { [weak self] in self?.addNote() }
        newNote.isEnabled = !notes.loadFailed
        menu.addItem(newNote)
        menu.addItem(ClosureMenuItem("Move Line to This Screen") { [weak self] in
            self?.panel.placeOnScreen()
            self?.updateCapacity()
        })

        let clearItem = ClosureMenuItem("Take Images Down") { [weak self] in
            self?.line.clear()
        }
        clearItem.isEnabled = line.items.contains { $0.note == nil && !$0.falling }
        menu.addItem(clearItem)

        let inbox = ClosureMenuItem(L("Handle screenshots")) { [weak self] in
            self?.setInbox(!Inbox.isEnabled)
        }
        inbox.state = Inbox.isEnabled ? .on : .off
        inbox.toolTip = L("Screenshots hang instantly and skip the Desktop")
        menu.addItem(inbox)

        let clipboard = ClosureMenuItem(L("Watch clipboard images")) { [weak self] in
            guard let self else { return }
            self.clipboardEnabled.toggle()
            if self.clipboardEnabled { self.clipboardWatcher?.start() } else { self.clipboardWatcher?.stop() }
        }
        clipboard.state = clipboardEnabled ? .on : .off
        menu.addItem(clipboard)

        menu.addItem(ClosureMenuItem(L("Open screenshots folder")) { [weak self] in
            guard let self else { return }
            NSWorkspace.shared.open(self.watcher.folder)
        })
        menu.addItem(ClosureMenuItem("Open Notes Folder") { [weak self] in
            guard let self else { return }
            NSWorkspace.shared.open(self.notes.file.deletingLastPathComponent())
        })
        if notes.errorMessage != nil {
            menu.addItem(ClosureMenuItem("View Save Issue") { [weak self] in
                guard let self, let error = self.notes.errorMessage else { return }
                let alert = NSAlert()
                alert.messageText = "Notes Could Not Be Saved"
                alert.informativeText = error
                alert.addButton(withTitle: "OK")
                alert.runModal()
                self.notes.save()
            })
        }

        menu.addItem(.separator())

        let sound = ClosureMenuItem(L("Sounds")) { [weak self] in
            guard let self else { return }
            self.line.soundOn.toggle()
        }
        sound.state = line.soundOn ? .on : .off
        menu.addItem(sound)

        let login = ClosureMenuItem(L("Open at login")) {
            AppDelegate.toggleLaunchAtLogin()
        }
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(L("Quit Breezeline"), key: "q") {
            NSApp.terminate(nil)
        })
    }

    private static func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = L("Could not change the login setting")
            alert.informativeText = L("Move Breezeline to the Applications folder and try again.")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    // MARK: Notes

    @objc private func addNote() {
        guard let id = notes.add() else { NSSound.beep(); return }
        editNote(id)
    }

    private func editNote(_ id: UUID) {
        guard let note = notes.notes.first(where: { $0.id == id }) else { return }
        editor?.close()
        let window = GlassEditorWindow(
            contentRect: NSRect(x: 0, y: 0, width: 564, height: 620),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = "Breezeline · Edit Note"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.contentView = NSHostingView(rootView: NoteEditor(
            store: notes, note: note, onDone: { [weak window] in window?.close() }))
        window.center()
        editor = window
        editingNoteID = id
        line.editing = true
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func deleteNote(_ id: UUID) {
        guard notes.remove(id) else { NSSound.beep(); return }
        if editingNoteID == id { editor?.close() }
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === editor {
            editor = nil
            editingNoteID = nil
            line.editing = false
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard notes.errorMessage != nil, !notes.loadFailed else { return .terminateNow }
        notes.save()
        guard notes.errorMessage != nil else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Some Notes Have Not Been Saved"
        alert.informativeText = "Keep editing to retain your changes. Quitting will discard unsaved changes."
        alert.addButton(withTitle: "Keep Editing")
        alert.addButton(withTitle: "Quit Anyway")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
    }

    private func installEditingMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem(title: "Breezeline", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "Breezeline")
        let quit = NSMenuItem(title: "Quit Breezeline", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        appMenu.addItem(quit)
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "File")
        let newNote = NSMenuItem(title: "New Note", action: #selector(addNote), keyEquivalent: "n")
        newNote.target = self
        fileMenu.addItem(newNote)
        fileItem.submenu = fileMenu
        menu.addItem(fileItem)

        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }
}

private final class GlassEditorWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
