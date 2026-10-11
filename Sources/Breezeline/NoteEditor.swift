import SwiftUI

struct NoteEditor: View {
    let store: NoteStore
    let note: Note
    let onDone: () -> Void
    @State private var title: String
    @State private var text: String
    @FocusState private var focused: Bool

    init(store: NoteStore, note: Note, onDone: @escaping () -> Void) {
        self.store = store
        self.note = note
        self.onDone = onDone
        _title = State(initialValue: note.title)
        _text = State(initialValue: note.text)
    }

    private var selectedColor: Int {
        store.notes.first(where: { $0.id == note.id })?.color ?? note.color
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                phosphorIcon("feather").frame(width: 18, height: 18)
                Text("Edit Note").font(.system(size: 14, weight: .medium))
                Spacer()
                Text(store.errorMessage == nil ? "Saved" : "Not Saved")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .glassDoneButton()
                    .controlSize(.large)
            }
            VStack(alignment: .leading, spacing: 14) {
                TextField("Give it a title…", text: $title)
                    .font(Handwriting.font(30))
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Note title")
                Rectangle().fill(Color(red: 0.35, green: 0.29, blue: 0.19).opacity(0.15))
                    .frame(height: 1)
                TextEditor(text: $text)
                    .font(Handwriting.font(24))
                    .lineSpacing(6)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .accessibilityLabel("Note text")
                    .frame(minHeight: 270)
            }
            .foregroundStyle(Color(red: 0.24, green: 0.20, blue: 0.15))
            .padding(26)
            .background(PaperSurface(color: selectedColor))
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
            HStack(spacing: 14) {
                HStack(spacing: 12) {
                    ForEach(0..<4) { color in
                        Button { store.setColor(note.id, to: color) } label: {
                            RoundedRectangle(cornerRadius: 5).fill(paperColor(color))
                                .frame(width: 28, height: 32)
                                .overlay {
                                    if selectedColor == color {
                                        phosphorIcon("check").frame(width: 12, height: 12)
                                            .foregroundStyle(Color(red: 0.24, green: 0.20, blue: 0.15))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(["Cream paper", "Sage paper", "Blush paper", "Blue paper"][color])
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .noteGlass(cornerRadius: 24, interactive: true)
                Spacer()
                Text("Stored on this Mac")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let error = store.errorMessage {
                HStack {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button("Retry Save") { store.save() }
                }
            }
        }
        .padding(24)
        .frame(width: 540)
        .noteGlass(cornerRadius: 28)
        .padding(12)
        .onChange(of: title) { store.update(note.id, title: title, text: text) }
        .onChange(of: text) { store.update(note.id, title: title, text: text) }
        .onAppear { focused = true }
        .onExitCommand(perform: onDone)
    }
}

struct NotePaper: View {
    let note: Note
    var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(Handwriting.font(25))
                .lineLimit(2)
            Text(note.text.isEmpty ? "Click to write something…" : note.text)
                .font(Handwriting.font(21))
                .lineSpacing(5)
                .lineLimit(7)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                phosphorIcon("feather").frame(width: 17, height: 17)
                    .opacity(hovered ? 0.85 : 0.65)
            }
        }
        .foregroundStyle(Color(red: 0.18, green: 0.20, blue: 0.17))
        .padding(20)
        .frame(width: NoteLayout.cardWidth, height: 260, alignment: .topLeading)
        .background(PaperSurface(color: note.color))
    }
}
