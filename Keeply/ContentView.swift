//
//  ContentView.swift
//  Keeply
//
//  Created by Harshana Amuwatte on 2026-05-31.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedSection: PocketSection = .notes
    @State private var notes = PocketNote.samples
    @State private var snippets = CopySnippet.samples
    @State private var showingComposer = false
    @State private var noteEditor: NoteEditorPresentation?
    @State private var copiedSnippetID: UUID?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppColor.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HeaderView(selectedSection: $selectedSection)
                    .padding(.horizontal, 20)
                    .padding(.top, 22)

                content
                    .padding(.top, 26)
            }

            AddButton(section: selectedSection) {
                if selectedSection == .notes {
                    noteEditor = NoteEditorPresentation(note: nil)
                } else {
                    showingComposer = true
                }
            }
            .padding(.trailing, 22)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showingComposer) {
            ComposerView(section: .quickCopy) { title, detail in
                addSnippet(label: title, value: detail)
            }
            .presentationDetents([.height(310)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(AppColor.secondarySurface)
        }
        .fullScreenCover(item: $noteEditor) { presentation in
            NoteEditorView(note: presentation.note) { title, content in
                saveNote(presentation.note, title: title, content: content)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .notes:
            NotesView(
                notes: notes,
                onOpen: openNote,
                onEdit: openNote,
                onDelete: deleteNote
            )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .opacity
                ))
        case .quickCopy:
            QuickCopyView(snippets: snippets, copiedSnippetID: copiedSnippetID) { snippet in
                copy(snippet)
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    private func addSnippet(label: String, value: String) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            snippets.insert(
                CopySnippet(
                    label: label,
                    value: value.isEmpty ? label : value,
                    icon: "doc.on.doc",
                    tint: .purple
                ),
                at: 0
            )
        }
    }

    private func openNote(_ note: PocketNote) {
        noteEditor = NoteEditorPresentation(note: note)
    }

    private func saveNote(_ note: PocketNote?, title: String, content: String) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            if let note, let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = PocketNote(
                    id: note.id,
                    title: title,
                    content: content,
                    modified: "Today",
                    icon: note.icon,
                    tint: note.tint
                )
            } else {
                notes.insert(
                    PocketNote(
                        title: title,
                        content: content.isEmpty ? "A fresh note, saved for later." : content,
                        modified: "Today",
                        icon: "note.text",
                        tint: .purple
                    ),
                    at: 0
                )
            }
        }
    }

    private func deleteNote(_ note: PocketNote) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            notes.removeAll { $0.id == note.id }
        }
    }

    private func copy(_ snippet: CopySnippet) {
        UIPasteboard.general.string = snippet.value
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
            copiedSnippetID = snippet.id
        }

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard copiedSnippetID == snippet.id else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                copiedSnippetID = nil
            }
        }
    }
}

private struct HeaderView: View {
    @Binding var selectedSection: PocketSection

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Pocket")
                        .font(.system(size: 39, weight: .bold, design: .rounded))
                        .tracking(-1.2)
                        .foregroundStyle(AppColor.primaryText)

                    Text("Everything you need, close at hand.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColor.secondaryText)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.accent)
                    .frame(width: 42, height: 42)
                    .background(AppColor.cardSurface.opacity(0.8), in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    }
            }

            SegmentedControl(selectedSection: $selectedSection)
        }
    }
}

private struct SegmentedControl: View {
    @Binding var selectedSection: PocketSection
    @Namespace private var selectionAnimation

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PocketSection.allCases) { section in
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedSection == section ? AppColor.primaryText : AppColor.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 43)
                        .background {
                            if selectedSection == section {
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppColor.cardSurface)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                        }

                                    Capsule()
                                        .fill(AppColor.accent)
                                        .frame(width: 28, height: 2)
                                        .padding(.bottom, 5)
                                }
                                .matchedGeometryEffect(id: "selectedSegment", in: selectionAnimation)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppColor.secondarySurface.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.045), lineWidth: 1)
        }
    }
}

private struct NotesView: View {
    let notes: [PocketNote]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "RECENT NOTES", count: notes.count)

                ForEach(notes) { note in
                    NoteCard(note: note)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 106)
        }
    }
}

private struct NoteCard: View {
    let note: PocketNote

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SurfaceIcon(symbol: note.icon, tint: note.tint)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(note.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(note.modified)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColor.secondaryText.opacity(0.78))
                }

                Text(note.preview)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppColor.secondaryText)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .background(AppColor.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.055), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 14, y: 8)
    }
}

private struct QuickCopyView: View {
    let snippets: [CopySnippet]
    let copiedSnippetID: UUID?
    let onCopy: (CopySnippet) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "SAVED CLIPS", count: snippets.count)

                ForEach(snippets) { snippet in
                    CopyCard(
                        snippet: snippet,
                        isCopied: copiedSnippetID == snippet.id,
                        onCopy: { onCopy(snippet) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 106)
        }
    }
}

private struct CopyCard: View {
    let snippet: CopySnippet
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 14) {
                SurfaceIcon(symbol: snippet.icon, tint: snippet.tint)

                VStack(alignment: .leading, spacing: 6) {
                    Text(snippet.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.primaryText)
                        .lineLimit(1)

                    Text(snippet.value)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppColor.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isCopied ? AppColor.accent : AppColor.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(isCopied ? 0.07 : 0.035), in: Circle())
            }
            .padding(14)
            .background(AppColor.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isCopied ? AppColor.accent.opacity(0.28) : Color.white.opacity(0.055), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.16), radius: 14, y: 8)
        }
        .buttonStyle(PressableCardButtonStyle())
    }
}

private struct SurfaceIcon: View {
    let symbol: String
    let tint: NoteTint

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint.color)
            .frame(width: 40, height: 40)
            .background(tint.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SectionTitle: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(AppColor.secondaryText.opacity(0.8))

            Spacer()

            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.secondaryText.opacity(0.75))
                .frame(minWidth: 22, minHeight: 22)
                .background(Color.white.opacity(0.04), in: Capsule())
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }
}

private struct AddButton: View {
    let section: PocketSection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x9B72F6), AppColor.accent, Color(hex: 0x7145D6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: AppColor.accent.opacity(0.38), radius: 16, y: 8)
                .shadow(color: Color.black.opacity(0.4), radius: 10, y: 8)
        }
        .buttonStyle(FloatingButtonStyle())
        .accessibilityLabel("Add \(section.title)")
    }
}

private struct ComposerView: View {
    let section: PocketSection
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var detail = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.composerTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.primaryText)

                    Text(section.composerSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColor.secondaryText)
                }

                Spacer()

                Button {
                    save()
                } label: {
                    Text("Save")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColor.secondaryText : AppColor.primaryText)
                        .padding(.horizontal, 15)
                        .frame(height: 38)
                        .background(AppColor.accent.opacity(title.isEmpty ? 0.14 : 0.9), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            VStack(spacing: 0) {
                TextField(section.titlePlaceholder, text: $title)
                    .focused($focusedField, equals: .title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColor.primaryText)
                    .padding(16)

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                TextField(section.detailPlaceholder, text: $detail, axis: .vertical)
                    .focused($focusedField, equals: .detail)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.primaryText)
                    .lineLimit(section == .notes ? 3 : 1, reservesSpace: section == .notes)
                    .padding(16)
            }
            .background(AppColor.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            }
            .padding(.top, 22)

            Spacer(minLength: 20)
        }
        .padding(20)
        .onAppear {
            focusedField = .title
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        onSave(cleanTitle, detail.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
}

private struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct FloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

private enum PocketSection: String, CaseIterable, Identifiable {
    case notes
    case quickCopy

    var id: Self { self }

    var title: String {
        switch self {
        case .notes: "Notes"
        case .quickCopy: "Quick Copy"
        }
    }

    var composerTitle: String {
        switch self {
        case .notes: "New note"
        case .quickCopy: "New clip"
        }
    }

    var composerSubtitle: String {
        switch self {
        case .notes: "Capture a thought before it drifts away."
        case .quickCopy: "Keep something useful within reach."
        }
    }

    var titlePlaceholder: String {
        switch self {
        case .notes: "Note title"
        case .quickCopy: "Label"
        }
    }

    var detailPlaceholder: String {
        switch self {
        case .notes: "Start writing..."
        case .quickCopy: "Text to copy"
        }
    }
}

private struct PocketNote: Identifiable {
    let id = UUID()
    let title: String
    let preview: String
    let modified: String
    let icon: String
    let tint: NoteTint

    static let samples = [
        PocketNote(
            title: "Weekend ideas",
            preview: "Book a quiet table, pick up coffee beans, and finally visit the gallery.",
            modified: "12m",
            icon: "sun.max",
            tint: .amber
        ),
        PocketNote(
            title: "Books to find",
            preview: "The Creative Act, Tomorrow and Tomorrow and Tomorrow, The Design of Everyday Things.",
            modified: "1h",
            icon: "book.closed",
            tint: .blue
        ),
        PocketNote(
            title: "Apartment checklist",
            preview: "Measure the office wall. Replace the entryway bulb. Order a small rug.",
            modified: "Tue",
            icon: "checkmark.circle",
            tint: .purple
        ),
        PocketNote(
            title: "Gift notes",
            preview: "A few small ideas for birthdays coming up this month.",
            modified: "Fri",
            icon: "gift",
            tint: .rose
        )
    ]
}

private struct CopySnippet: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let icon: String
    let tint: NoteTint

    static let samples = [
        CopySnippet(
            label: "Personal email",
            value: "hello@alexmorgan.design",
            icon: "envelope",
            tint: .purple
        ),
        CopySnippet(
            label: "Home address",
            value: "48 Juniper Lane, Portland, OR",
            icon: "house",
            tint: .blue
        ),
        CopySnippet(
            label: "Portfolio",
            value: "alexmorgan.design",
            icon: "link",
            tint: .amber
        ),
        CopySnippet(
            label: "Wi-Fi password",
            value: "SundayCoffee27",
            icon: "wifi",
            tint: .rose
        ),
        CopySnippet(
            label: "Phone number",
            value: "+1 (503) 555-0148",
            icon: "phone",
            tint: .blue
        )
    ]
}

private enum NoteTint {
    case purple
    case blue
    case amber
    case rose

    var color: Color {
        switch self {
        case .purple: AppColor.accent
        case .blue: Color(hex: 0x7B9BCB)
        case .amber: Color(hex: 0xC79B63)
        case .rose: Color(hex: 0xB9828D)
        }
    }
}

private enum AppColor {
    static let background = Color(hex: 0x0D0D0D)
    static let secondarySurface = Color(hex: 0x171717)
    static let cardSurface = Color(hex: 0x1E1E1E)
    static let accent = Color(hex: 0x8B5CF6)
    static let primaryText = Color.white
    static let secondaryText = Color(hex: 0x9CA3AF)
}

private extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
