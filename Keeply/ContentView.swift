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
    @State private var notes = PocketStorage.loadNotes()
    @State private var snippets = PocketStorage.loadSnippets()
    @State private var editor: EditorPresentation?
    @State private var viewer: NoteViewerPresentation?
    @State private var copiedSnippetID: UUID?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppColor.background
                .ignoresSafeArea()

            content

            AddButton(section: selectedSection) {
                editor = EditorPresentation(section: selectedSection)
            }
            .padding(.trailing, 22)
            .padding(.bottom, 24)
        }
        .sheet(item: $editor) { presentation in
            ItemEditorView(presentation: presentation) { draft in
                saveItem(presentation, draft: draft)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $viewer) { presentation in
            if let note = noteBinding(for: presentation.noteID) {
                NoteViewerView(note: note) { draft in
                    saveNote(note.wrappedValue, draft: draft)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(.ultraThinMaterial)
            }
        }
        .overlay(alignment: .bottom) {
            if selectedSection == .quickCopy, copiedSnippetID != nil {
                CopyToast()
                    .padding(.bottom, 104)
                    .transition(.opacity)
            }
        }
        .onChange(of: notes) { _, notes in
            PocketStorage.saveNotes(notes)
        }
        .onChange(of: snippets) { _, snippets in
            PocketStorage.saveSnippets(snippets)
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            NotesView(
                selectedSection: $selectedSection,
                notes: orderedNotes,
                onOpen: openNote,
                onEdit: editNote,
                onToggleFavorite: toggleFavorite,
                onDelete: deleteNote
            )
            .opacity(selectedSection == .notes ? 1 : 0)
            .allowsHitTesting(selectedSection == .notes)
            .accessibilityHidden(selectedSection != .notes)

            QuickCopyView(
                selectedSection: $selectedSection,
                snippets: snippets,
                copiedSnippetID: copiedSnippetID,
                onCopy: copy,
                onEdit: openSnippet,
                onDelete: deleteSnippet
            )
            .opacity(selectedSection == .quickCopy ? 1 : 0)
            .allowsHitTesting(selectedSection == .quickCopy)
            .accessibilityHidden(selectedSection != .quickCopy)
        }
        .animation(.easeInOut(duration: 0.18), value: selectedSection)
    }

    private func saveItem(
        _ presentation: EditorPresentation,
        draft: ItemEditorDraft
    ) {
        switch presentation.section {
        case .notes:
            saveNote(
                presentation.note,
                title: draft.title,
                content: draft.content,
                format: draft.noteFormat,
                checklistItems: draft.checklistItems
            )
        case .quickCopy:
            saveSnippet(
                presentation.snippet,
                title: draft.title,
                content: draft.content,
                iconOption: draft.iconOption
            )
        }
    }

    private func openNote(_ note: PocketNote) {
        viewer = NoteViewerPresentation(noteID: note.id)
    }

    private func editNote(_ note: PocketNote) {
        editor = EditorPresentation(section: .notes, note: note)
    }

    private func saveNote(
        _ note: PocketNote?,
        title: String,
        content: String,
        format: NoteFormat,
        checklistItems: [ChecklistItem]
    ) {
        withAnimation(.easeOut(duration: 0.2)) {
            if let note, let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = PocketNote(
                    id: note.id,
                    title: title,
                    content: content,
                    modified: "Today",
                    icon: note.icon,
                    tint: note.tint,
                    format: format,
                    checklistItems: checklistItems,
                    isFavorite: note.isFavorite
                )
            } else {
                notes.insert(
                    PocketNote(
                        title: title,
                        content: content.isEmpty ? "A fresh note, saved for later." : content,
                        modified: "Today",
                        icon: format == .checklist ? "checklist" : "note.text",
                        tint: .purple,
                        format: format,
                        checklistItems: checklistItems
                    ),
                    at: 0
                )
            }
        }
    }

    private func saveNote(_ note: PocketNote, draft: ItemEditorDraft) {
        saveNote(
            note,
            title: draft.title,
            content: draft.content,
            format: draft.noteFormat,
            checklistItems: draft.checklistItems
        )
    }

    private func openSnippet(_ snippet: CopySnippet) {
        editor = EditorPresentation(section: .quickCopy, snippet: snippet)
    }

    private func saveSnippet(
        _ snippet: CopySnippet?,
        title: String,
        content: String,
        iconOption: SnippetIconOption?
    ) {
        let iconOption = iconOption ?? .none
        let previousIconOption = SnippetIconOption.option(for: snippet?.icon)
        let category = snippet == nil || previousIconOption != iconOption
            ? iconOption.category
            : snippet?.category ?? iconOption.category
        let savedSnippet = CopySnippet(
            id: snippet?.id ?? UUID(),
            title: title,
            category: category,
            content: content,
            icon: iconOption.symbol,
            tint: iconOption.tint
        )

        withAnimation(.easeOut(duration: 0.2)) {
            if let snippet, let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
                snippets[index] = savedSnippet
            } else {
                snippets.insert(savedSnippet, at: 0)
            }
        }
    }

    private func deleteNote(_ note: PocketNote) {
        withAnimation(.easeOut(duration: 0.2)) {
            notes.removeAll { $0.id == note.id }
        }
    }

    private func toggleFavorite(_ note: PocketNote) {
        withAnimation(.easeOut(duration: 0.2)) {
            guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
            notes[index].isFavorite.toggle()
        }
    }

    private var orderedNotes: [PocketNote] {
        notes.enumerated()
            .sorted { lhs, rhs in
                lhs.element.isFavorite == rhs.element.isFavorite
                    ? lhs.offset < rhs.offset
                    : lhs.element.isFavorite && !rhs.element.isFavorite
            }
            .map(\.element)
    }

    private func noteBinding(for id: UUID) -> Binding<PocketNote>? {
        guard let existingNote = notes.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { notes.first(where: { $0.id == id }) ?? existingNote },
            set: { updatedNote in
                guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
                notes[index] = updatedNote
            }
        )
    }

    private func deleteSnippet(_ snippet: CopySnippet) {
        withAnimation(.easeOut(duration: 0.2)) {
            snippets.removeAll { $0.id == snippet.id }
            if copiedSnippetID == snippet.id {
                copiedSnippetID = nil
            }
        }
    }

    private func copy(_ snippet: CopySnippet) {
        UIPasteboard.general.string = snippet.content
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeOut(duration: 0.18)) {
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
                    Text("Keeply")
                        .font(.system(size: 39, weight: .bold, design: .rounded))
                        .tracking(-1.2)
                        .foregroundStyle(AppColor.primaryText)

                    Text("Everything you need, close at hand.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColor.secondaryText)
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedSection == section ? AppColor.primaryText : AppColor.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 43)
                        .contentShape(Rectangle())
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
    @Binding var selectedSection: PocketSection
    let notes: [PocketNote]
    let onOpen: (PocketNote) -> Void
    let onEdit: (PocketNote) -> Void
    let onToggleFavorite: (PocketNote) -> Void
    let onDelete: (PocketNote) -> Void

    var body: some View {
        List {
            HeaderView(selectedSection: $selectedSection)
                .listRowInsets(EdgeInsets(top: 22, leading: 20, bottom: 26, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            SectionTitle(title: "RECENT NOTES")
                .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 8, trailing: 22))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if notes.isEmpty {
                EmptyNotesView()
                    .listRowInsets(EdgeInsets(top: 30, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(notes) { note in
                    Button {
                        onOpen(note)
                    } label: {
                        NoteCard(note: note)
                    }
                    .buttonStyle(PressableCardButtonStyle())
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            onToggleFavorite(note)
                        } label: {
                            Label(note.isFavorite ? "Unfavorite" : "Favorite", systemImage: note.isFavorite ? "star.slash" : "star")
                        }
                        .tint(AppColor.accent)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            onEdit(note)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(AppColor.accent)
                    }
                    .contextMenu {
                        Button {
                            onToggleFavorite(note)
                        } label: {
                            Label(note.isFavorite ? "Remove Favorite" : "Favorite Note", systemImage: note.isFavorite ? "star.slash" : "star")
                        }

                        Button {
                            onEdit(note)
                        } label: {
                            Label("Edit Note", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete(note)
                        } label: {
                            Label("Delete Note", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 106, for: .scrollContent)
        .background(Color.clear)
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

                    HStack(spacing: 5) {
                        if note.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColor.accent)
                        }

                        Text(note.modified)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColor.secondaryText.opacity(0.78))
                    }
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

private struct EmptyNotesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(AppColor.accent)
                .frame(width: 52, height: 52)
                .background(AppColor.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("A quiet place for your notes.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.primaryText)

            Text("Tap + to capture a thought or reminder.")
                .font(.system(size: 13))
                .foregroundStyle(AppColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

private struct QuickCopyView: View {
    @Binding var selectedSection: PocketSection
    let snippets: [CopySnippet]
    let copiedSnippetID: UUID?
    let onCopy: (CopySnippet) -> Void
    let onEdit: (CopySnippet) -> Void
    let onDelete: (CopySnippet) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                HeaderView(selectedSection: $selectedSection)
                    .padding(.bottom, 26)

                VStack(alignment: .leading, spacing: 7) {
                    SectionTitle(title: "QUICK ACCESS")

                    Text("Tap any card to copy instantly.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColor.secondaryText)
                }
                .padding(.bottom, 3)

                LazyVStack(spacing: 10) {
                    ForEach(snippets) { snippet in
                        CopyCard(
                            snippet: snippet,
                            isCopied: copiedSnippetID == snippet.id,
                            onCopy: { onCopy(snippet) },
                            onEdit: { onEdit(snippet) },
                            onDelete: { onDelete(snippet) }
                        )
                    }
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 106)
        }
    }
}

private struct CopyCard: View {
    let snippet: CopySnippet
    let isCopied: Bool
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(alignment: .center, spacing: 14) {
                if let icon = snippet.icon {
                    SurfaceIcon(symbol: icon, tint: snippet.tint)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(snippet.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.primaryText)
                        .lineLimit(1)

                    Text(snippet.category.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(snippet.tint.color.opacity(0.92))
                        .lineLimit(1)

                    Text(snippet.content)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColor.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))

                    Text(isCopied ? "Copied" : "Copy")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isCopied ? AppColor.accent : AppColor.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(isCopied ? AppColor.accent.opacity(0.12) : Color.white.opacity(0.055), in: Capsule())
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
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Clip", systemImage: "pencil")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete Clip", systemImage: "trash")
            }
        }
    }
}

private struct CopyToast: View {
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColor.accent)

            Text("Copied")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.primaryText)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 12, y: 6)
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

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(AppColor.secondaryText.opacity(0.8))
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
                        .fill(AppColor.accent)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: AppColor.accent.opacity(0.24), radius: 14, y: 7)
                .shadow(color: Color.black.opacity(0.4), radius: 10, y: 8)
        }
        .buttonStyle(FloatingButtonStyle())
        .accessibilityLabel("Add \(section.title)")
    }
}

private struct NoteViewerView: View {
    @Binding var note: PocketNote
    let onSave: (ItemEditorDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editor: EditorPresentation?
    @State private var celebration: ChecklistCelebrationEvent?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.opacity(0.96)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(spacing: 12) {
                            SurfaceIcon(symbol: note.icon, tint: note.tint)

                            Text(note.modified)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColor.secondaryText)
                        }

                        Text(note.title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .tracking(-0.7)
                            .foregroundStyle(AppColor.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if note.format == .checklist {
                            NoteViewerChecklist(
                                items: $note.checklistItems,
                                onChange: {
                                    note.modified = "Today"
                                },
                                onMilestone: celebrate
                            )
                        } else {
                            Text(note.content.isEmpty ? "No additional content." : note.content)
                                .font(.system(size: 17))
                                .foregroundStyle(note.content.isEmpty ? AppColor.secondaryText : AppColor.primaryText)
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }

                if let celebration {
                    ChecklistMilestoneCelebration(milestone: celebration.milestone)
                        .id(celebration.id)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .allowsHitTesting(false)
                        .zIndex(2)
                }
            }
            .toolbarBackground(AppColor.background.opacity(0.92), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            note.isFavorite.toggle()
                        }
                    } label: {
                        Image(systemName: note.isFavorite ? "star.fill" : "star")
                    }
                    .accessibilityLabel(note.isFavorite ? "Remove favorite" : "Mark favorite")

                    Button("Edit") {
                        editor = EditorPresentation(section: .notes, note: note)
                    }
                    .fontWeight(.semibold)
                }
            }
            .tint(AppColor.accent)
        }
        .preferredColorScheme(.dark)
        .sheet(item: $editor) { presentation in
            ItemEditorView(presentation: presentation, onSave: onSave)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private func celebrate(_ milestone: ChecklistMilestone) {
        let event = ChecklistCelebrationEvent(milestone: milestone)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
            celebration = event
        }

        Task {
            try? await Task.sleep(for: .seconds(milestone == .complete ? 2 : 1.55))
            guard celebration?.id == event.id else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                celebration = nil
            }
        }
    }
}

private struct NoteViewerChecklist: View {
    @Binding var items: [ChecklistItem]
    let onChange: () -> Void
    let onMilestone: (ChecklistMilestone) -> Void

    @State private var burst: ChecklistBurstEvent?

    var body: some View {
        VStack(spacing: 14) {
            ChecklistProgressView(completedCount: completedCount, totalCount: items.count)

            VStack(spacing: 0) {
                ForEach($items) { $item in
                    Button {
                        toggle(itemID: item.id)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 21))
                                    .foregroundStyle(item.isChecked ? AppColor.accent : AppColor.secondaryText)
                                    .contentTransition(.symbolEffect(.replace))

                                if burst?.itemID == item.id {
                                    SmallChecklistBurst()
                                        .id(burst?.id)
                                }
                            }

                            Text(item.title)
                                .font(.system(size: 17))
                                .foregroundStyle(item.isChecked ? AppColor.secondaryText : AppColor.primaryText)
                                .strikethrough(item.isChecked, color: AppColor.secondaryText)

                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 52)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if item.id != items.last?.id {
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 1)
                            .padding(.leading, 49)
                    }
                }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var completedCount: Int {
        items.filter(\.isChecked).count
    }

    private func toggle(itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let wasChecked = items[index].isChecked
        let oldProgress = progress(completedCount: completedCount)

        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            items[index].isChecked.toggle()
            onChange()
        }

        guard !wasChecked else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
            return
        }

        let newProgress = progress(completedCount: completedCount)
        let milestone = ChecklistMilestone.crossed(from: oldProgress, to: newProgress)
        playHaptic(for: milestone)
        showBurst(for: itemID)

        if let milestone {
            onMilestone(milestone)
        }
    }

    private func progress(completedCount: Int) -> Double {
        guard !items.isEmpty else { return 0 }
        return Double(completedCount) / Double(items.count)
    }

    private func showBurst(for itemID: UUID) {
        let event = ChecklistBurstEvent(itemID: itemID)
        burst = event

        Task {
            try? await Task.sleep(for: .seconds(0.72))
            guard burst?.id == event.id else { return }
            burst = nil
        }
    }

    private func playHaptic(for milestone: ChecklistMilestone?) {
        guard let milestone else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.72)
            return
        }

        UIImpactFeedbackGenerator(style: milestone.impactStyle).impactOccurred(intensity: milestone.impactIntensity)

        Task {
            try? await Task.sleep(for: .milliseconds(110))
            if milestone == .complete {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.76)
            }
        }
    }
}

private struct ChecklistProgressView: View {
    let completedCount: Int
    let totalCount: Int

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var percentage: Int {
        Int((progress * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PROGRESS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(AppColor.secondaryText.opacity(0.82))

                Spacer()

                Text("\(completedCount) of \(totalCount)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColor.secondaryText)

                Text("\(percentage)%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColor.accent)
                    .contentTransition(.numericText())
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(Color.white.opacity(0.07))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(AppColor.accent)
                            .frame(width: geometry.size.width * progress)
                            .shadow(color: AppColor.accent.opacity(0.42), radius: 7)
                    }
            }
            .frame(height: 7)
            .animation(.spring(response: 0.5, dampingFraction: 0.76), value: progress)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct SmallChecklistBurst: View {
    @State private var expanded = false

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 3) ? Color.white : AppColor.accent)
                    .frame(width: index.isMultiple(of: 2) ? 4 : 3, height: index.isMultiple(of: 2) ? 4 : 3)
                    .offset(
                        x: expanded ? particleOffset(for: index).x : 0,
                        y: expanded ? particleOffset(for: index).y : 0
                    )
                    .opacity(expanded ? 0 : 0.92)
            }

            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white)
                .scaleEffect(expanded ? 1.7 : 0.5)
                .opacity(expanded ? 0 : 0.9)
        }
        .frame(width: 22, height: 22)
        .onAppear {
            withAnimation(.easeOut(duration: 0.66)) {
                expanded = true
            }
        }
    }

    private func particleOffset(for index: Int) -> CGPoint {
        let angle = Double(index) / 8 * Double.pi * 2
        let distance = index.isMultiple(of: 2) ? 25.0 : 20.0
        return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
    }
}

private struct ChecklistMilestoneCelebration: View {
    let milestone: ChecklistMilestone

    @State private var particlesExpanded = false
    @State private var badgeVisible = false

    var body: some View {
        ZStack {
            Color.black
                .opacity(badgeVisible ? milestone.backdropOpacity : 0)
                .ignoresSafeArea()

            ForEach(0..<milestone.particleCount, id: \.self) { index in
                Image(systemName: particleSymbol(for: index))
                    .font(.system(size: particleSize(for: index), weight: .bold))
                    .foregroundStyle(index.isMultiple(of: 4) ? Color.white : AppColor.accent)
                    .offset(
                        x: particlesExpanded ? particleOffset(for: index).x : 0,
                        y: particlesExpanded ? particleOffset(for: index).y : 0
                    )
                    .rotationEffect(.degrees(particlesExpanded ? Double(index * 38) : 0))
                    .scaleEffect(particlesExpanded ? 0.35 : 1)
                    .opacity(particlesExpanded ? 0 : 0.96)
            }

            VStack(spacing: 8) {
                Image(systemName: milestone.symbol)
                    .font(.system(size: milestone == .complete ? 44 : 34, weight: .bold))
                    .foregroundStyle(AppColor.accent)

                Text("\(milestone.rawValue)%")
                    .font(.system(size: milestone == .complete ? 42 : 34, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(AppColor.primaryText)

                Text(milestone.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.secondaryText)
            }
            .padding(.horizontal, milestone == .complete ? 34 : 28)
            .padding(.vertical, milestone == .complete ? 25 : 21)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(AppColor.accent.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: AppColor.accent.opacity(0.26), radius: 24, y: 12)
            .scaleEffect(badgeVisible ? 1 : 0.62)
            .opacity(badgeVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: milestone == .complete ? 1.7 : 1.25)) {
                particlesExpanded = true
            }

            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                badgeVisible = true
            }

            Task {
                try? await Task.sleep(for: .seconds(milestone == .complete ? 1.55 : 1.12))
                withAnimation(.easeOut(duration: 0.28)) {
                    badgeVisible = false
                }
            }
        }
    }

    private func particleSymbol(for index: Int) -> String {
        if index.isMultiple(of: 5) {
            return "star.fill"
        }
        return index.isMultiple(of: 2) ? "sparkle" : "circle.fill"
    }

    private func particleSize(for index: Int) -> CGFloat {
        index.isMultiple(of: 5) ? 13 : index.isMultiple(of: 2) ? 10 : 6
    }

    private func particleOffset(for index: Int) -> CGPoint {
        let angle = Double(index) / Double(milestone.particleCount) * Double.pi * 2
        let distance = milestone.radius * (0.76 + Double(index % 4) * 0.08)
        return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
    }
}

private struct ChecklistBurstEvent {
    let id = UUID()
    let itemID: UUID
}

private struct ChecklistCelebrationEvent {
    let id = UUID()
    let milestone: ChecklistMilestone
}

private enum ChecklistMilestone: Int, CaseIterable {
    case quarter = 25
    case half = 50
    case threeQuarter = 75
    case complete = 100

    var title: String {
        switch self {
        case .quarter: "Nice start"
        case .half: "Halfway there"
        case .threeQuarter: "Almost done"
        case .complete: "All done"
        }
    }

    var symbol: String {
        switch self {
        case .quarter: "sparkles"
        case .half: "star.fill"
        case .threeQuarter: "bolt.fill"
        case .complete: "checkmark.seal.fill"
        }
    }

    var particleCount: Int {
        switch self {
        case .quarter: 16
        case .half: 22
        case .threeQuarter: 28
        case .complete: 42
        }
    }

    var radius: Double {
        switch self {
        case .quarter: 128
        case .half: 154
        case .threeQuarter: 184
        case .complete: 236
        }
    }

    var backdropOpacity: Double {
        switch self {
        case .quarter: 0.04
        case .half: 0.07
        case .threeQuarter: 0.1
        case .complete: 0.16
        }
    }

    var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .quarter: .medium
        case .half: .medium
        case .threeQuarter: .heavy
        case .complete: .rigid
        }
    }

    var impactIntensity: CGFloat {
        switch self {
        case .quarter: 0.72
        case .half: 0.84
        case .threeQuarter: 0.94
        case .complete: 1
        }
    }

    static func crossed(from oldProgress: Double, to newProgress: Double) -> Self? {
        allCases.reversed().first {
            oldProgress < Double($0.rawValue) / 100
                && newProgress >= Double($0.rawValue) / 100
        }
    }
}

private struct ItemEditorView: View {
    let presentation: EditorPresentation
    let onSave: (ItemEditorDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var noteFormat: NoteFormat
    @State private var checklistItems: [ChecklistItem]
    @State private var iconOption: SnippetIconOption
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case content
    }

    init(
        presentation: EditorPresentation,
        onSave: @escaping (ItemEditorDraft) -> Void
    ) {
        self.presentation = presentation
        self.onSave = onSave
        _title = State(initialValue: presentation.existingTitle)
        _content = State(initialValue: presentation.existingContent)
        _noteFormat = State(initialValue: presentation.note?.format ?? .text)
        _checklistItems = State(initialValue: presentation.note?.checklistItems ?? [])
        _iconOption = State(initialValue: SnippetIconOption.option(for: presentation.snippet?.icon))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.opacity(0.94)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(presentation.editorTitle)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .tracking(-0.8)
                                .foregroundStyle(AppColor.primaryText)

                            Text(presentation.editorSubtitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColor.secondaryText)
                        }

                        if presentation.section == .notes {
                            NoteFormatPicker(selection: $noteFormat)
                        }

                        VStack(spacing: 0) {
                            EditorFieldLabel(title: "Title")

                            TextField(presentation.titlePlaceholder, text: $title)
                                .focused($focusedField, equals: .title)
                                .font(.system(size: 17))
                                .foregroundStyle(AppColor.primaryText)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)

                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                                .padding(.horizontal, 16)

                            EditorFieldLabel(title: presentation.contentLabel)

                            if presentation.section == .notes, noteFormat == .checklist {
                                ChecklistEditor(items: $checklistItems)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 10)
                            } else {
                                ZStack(alignment: .topLeading) {
                                    if content.isEmpty {
                                        Text(presentation.contentPlaceholder)
                                            .font(.system(size: 17))
                                            .foregroundStyle(AppColor.secondaryText.opacity(0.72))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 8)
                                            .allowsHitTesting(false)
                                    }

                                    TextEditor(text: $content)
                                        .focused($focusedField, equals: .content)
                                        .font(.system(size: 17))
                                        .foregroundStyle(AppColor.primaryText)
                                        .lineSpacing(4)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: presentation.section == .notes ? 230 : 150)
                                        .padding(.horizontal, -5)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }
                        }
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }

                        if presentation.section == .quickCopy {
                            SnippetIconPicker(selection: $iconOption)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbarBackground(AppColor.background.opacity(0.92), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .tint(AppColor.accent)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !presentation.isEditing {
                focusedField = .title
            }
        }
        .onChange(of: noteFormat) {
            updateContentForSelectedNoteFormat()
        }
    }

    private var canSave: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasContent = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasTitle && (presentation.section == .notes || hasContent)
    }

    private func save() {
        guard canSave else { return }
        let checklistItems = normalizedChecklistItems
        let savedContent = noteFormat == .checklist
            ? checklistItems.map(\.title).joined(separator: "\n")
            : content.trimmingCharacters(in: .whitespacesAndNewlines)

        onSave(
            ItemEditorDraft(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: savedContent,
                noteFormat: noteFormat,
                checklistItems: checklistItems,
                iconOption: presentation.section == .quickCopy ? iconOption : nil
            )
        )
        dismiss()
    }

    private var normalizedChecklistItems: [ChecklistItem] {
        checklistItems.compactMap { item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty
                ? nil
                : ChecklistItem(id: item.id, title: title, isChecked: item.isChecked)
        }
    }

    private func updateContentForSelectedNoteFormat() {
        switch noteFormat {
        case .text:
            content = normalizedChecklistItems.map(\.title).joined(separator: "\n")
        case .checklist:
            let existingChecklistContent = normalizedChecklistItems.map(\.title).joined(separator: "\n")
            guard checklistItems.isEmpty || content != existingChecklistContent else { return }
            let parsedItems = content
                .components(separatedBy: .newlines)
                .map { $0.replacingOccurrences(of: "• ", with: "") }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { ChecklistItem(title: $0) }
            checklistItems = parsedItems.isEmpty ? [ChecklistItem()] : parsedItems
        }
    }
}

private struct EditorFieldLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.9)
            .foregroundStyle(AppColor.secondaryText.opacity(0.82))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 15)
            .padding(.bottom, 9)
    }
}

private struct NoteFormatPicker: View {
    @Binding var selection: NoteFormat

    var body: some View {
        HStack(spacing: 4) {
            ForEach(NoteFormat.allCases) { format in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selection = format
                    }
                } label: {
                    Label(format.title, systemImage: format.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == format ? AppColor.primaryText : AppColor.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .contentShape(Rectangle())
                        .background {
                            if selection == format {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                                    }
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct ChecklistEditor: View {
    @Binding var items: [ChecklistItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach($items) { $item in
                HStack(spacing: 8) {
                    Button {
                        item.isChecked.toggle()
                    } label: {
                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(item.isChecked ? AppColor.accent : AppColor.secondaryText)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 32, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.isChecked ? "Mark incomplete" : "Mark complete")

                    TextField("List item", text: $item.title)
                        .font(.system(size: 17))
                        .foregroundStyle(item.isChecked ? AppColor.secondaryText : AppColor.primaryText)
                        .strikethrough(item.isChecked, color: AppColor.secondaryText)
                        .frame(minHeight: 44)

                    Button {
                        items.removeAll { $0.id == item.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColor.secondaryText.opacity(0.72))
                            .frame(width: 32, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove item")
                }

                if item.id != items.last?.id {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                        .padding(.leading, 40)
                }
            }

            Button {
                items.append(ChecklistItem())
            } label: {
                Label("Add item", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 46)
                    .padding(.leading, 7)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 230, alignment: .top)
    }
}

private struct SnippetIconPicker: View {
    @Binding var selection: SnippetIconOption

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CATEGORY ICON")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(AppColor.secondaryText.opacity(0.82))

                Text("Optional")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.secondaryText)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SnippetIconOption.allCases) { option in
                        Button {
                            selection = option
                        } label: {
                            VStack(spacing: 7) {
                                Image(systemName: option.symbol ?? "minus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(selection == option ? option.tint.color : AppColor.secondaryText)
                                    .frame(width: 48, height: 44)
                                    .background(Color.white.opacity(selection == option ? 0.08 : 0.035), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .strokeBorder(selection == option ? AppColor.accent.opacity(0.6) : Color.white.opacity(0.05), lineWidth: 1)
                                    }

                                Text(option.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppColor.secondaryText)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(minWidth: 54)
                    }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
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
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
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

}

private struct ItemEditorDraft {
    let title: String
    let content: String
    let noteFormat: NoteFormat
    let checklistItems: [ChecklistItem]
    let iconOption: SnippetIconOption?
}

private enum NoteFormat: String, CaseIterable, Identifiable, Codable {
    case text
    case checklist

    var id: Self { self }

    var title: String {
        switch self {
        case .text: "Text"
        case .checklist: "Checklist"
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .checklist: "checklist"
        }
    }
}

private struct ChecklistItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isChecked: Bool

    init(id: UUID = UUID(), title: String = "", isChecked: Bool = false) {
        self.id = id
        self.title = title
        self.isChecked = isChecked
    }
}

private struct NoteViewerPresentation: Identifiable {
    let noteID: UUID

    var id: UUID { noteID }
}

private struct EditorPresentation: Identifiable {
    let id = UUID()
    let section: PocketSection
    let note: PocketNote?
    let snippet: CopySnippet?

    init(section: PocketSection, note: PocketNote? = nil, snippet: CopySnippet? = nil) {
        self.section = section
        self.note = note
        self.snippet = snippet
    }

    var isEditing: Bool {
        note != nil || snippet != nil
    }

    var existingTitle: String {
        note?.title ?? snippet?.title ?? ""
    }

    var existingContent: String {
        note?.content ?? snippet?.content ?? ""
    }

    var editorTitle: String {
        switch (section, isEditing) {
        case (.notes, false): "New Note"
        case (.notes, true): "Edit Note"
        case (.quickCopy, false): "New Quick Copy"
        case (.quickCopy, true): "Edit Quick Copy"
        }
    }

    var editorSubtitle: String {
        switch section {
        case .notes: "Capture a thought or reminder."
        case .quickCopy: "Save something you copy often."
        }
    }

    var titlePlaceholder: String {
        switch section {
        case .notes: "Note title"
        case .quickCopy: "Label"
        }
    }

    var contentLabel: String {
        switch section {
        case .notes: "Content"
        case .quickCopy: "Content to Copy"
        }
    }

    var contentPlaceholder: String {
        switch section {
        case .notes: "Start writing..."
        case .quickCopy: "Paste or type the value..."
        }
    }
}

private struct PocketNote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var modified: String
    var icon: String
    var tint: NoteTint
    var format: NoteFormat
    var checklistItems: [ChecklistItem]
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        modified: String,
        icon: String,
        tint: NoteTint,
        format: NoteFormat = .text,
        checklistItems: [ChecklistItem] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.modified = modified
        self.icon = icon
        self.tint = tint
        self.format = format
        self.checklistItems = checklistItems
        self.isFavorite = isFavorite
    }

    var preview: String {
        guard format == .checklist else { return content }
        let checklistPreview = checklistItems
            .filter { !$0.title.isEmpty }
            .map { "\($0.isChecked ? "✓" : "○") \($0.title)" }
            .joined(separator: "\n")
        return checklistPreview.isEmpty ? "Checklist" : checklistPreview
    }

    static let samples = [
        PocketNote(
            title: "Tomorrow Tasks",
            content: "• Call bank\n• Finish report\n• Buy milk",
            modified: "Today",
            icon: "checklist",
            tint: .purple,
            format: .checklist,
            checklistItems: [
                ChecklistItem(title: "Call bank"),
                ChecklistItem(title: "Finish report"),
                ChecklistItem(title: "Buy milk")
            ],
            isFavorite: true
        ),
        PocketNote(
            title: "Grocery List",
            content: "• Oat milk\n• Fresh basil\n• Coffee beans",
            modified: "Today",
            icon: "cart",
            tint: .amber,
            format: .checklist,
            checklistItems: [
                ChecklistItem(title: "Oat milk", isChecked: true),
                ChecklistItem(title: "Fresh basil"),
                ChecklistItem(title: "Coffee beans")
            ]
        ),
        PocketNote(
            title: "Meeting Notes",
            content: "Review the launch timeline and send the revised brief before Thursday.",
            modified: "Yesterday",
            icon: "person.2",
            tint: .blue
        ),
        PocketNote(
            title: "Ideas",
            content: "A quiet reading mode with fewer controls and a warmer background.",
            modified: "Sat",
            icon: "lightbulb",
            tint: .purple
        ),
        PocketNote(
            title: "Books to Read",
            content: "The Creative Act\nThe Design of Everyday Things\nTomorrow, and Tomorrow, and Tomorrow",
            modified: "May 24",
            icon: "book.closed",
            tint: .rose
        )
    ]
}

private struct CopySnippet: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let category: String
    let content: String
    let icon: String?
    let tint: NoteTint

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        content: String,
        icon: String?,
        tint: NoteTint
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.content = content
        self.icon = icon
        self.tint = tint
    }

    static let samples = [
        CopySnippet(
            title: "Personal Bank",
            category: "Commercial Bank",
            content: "1234567890",
            icon: "building.columns",
            tint: .purple
        ),
        CopySnippet(
            title: "Email Signature",
            category: "Work",
            content: "Alex Morgan\nProduct Designer",
            icon: "signature",
            tint: .blue
        ),
        CopySnippet(
            title: "Company Address",
            category: "Work",
            content: "48 Juniper Lane\nPortland, OR 97205",
            icon: "building.2",
            tint: .amber
        ),
        CopySnippet(
            title: "Tax Number",
            category: "Finance",
            content: "US-TAX-84-2910473",
            icon: "number",
            tint: .rose
        ),
        CopySnippet(
            title: "GitHub Username",
            category: "Developer",
            content: "@alexmorgan",
            icon: "chevron.left.forwardslash.chevron.right",
            tint: .blue
        ),
        CopySnippet(
            title: "Rewrite Prompt",
            category: "Prompt Template",
            content: "Rewrite this with a clear, concise tone.",
            icon: "text.quote",
            tint: .purple
        )
    ]
}

private enum SnippetIconOption: String, CaseIterable, Identifiable {
    case none
    case banking
    case work
    case address
    case finance
    case developer
    case prompt

    var id: Self { self }

    var title: String {
        switch self {
        case .none: "None"
        case .banking: "Bank"
        case .work: "Work"
        case .address: "Address"
        case .finance: "Finance"
        case .developer: "Dev"
        case .prompt: "Prompt"
        }
    }

    var category: String {
        switch self {
        case .none: "Quick Copy"
        case .banking: "Banking"
        case .work: "Work"
        case .address: "Address"
        case .finance: "Finance"
        case .developer: "Developer"
        case .prompt: "Prompt Template"
        }
    }

    var symbol: String? {
        switch self {
        case .none: nil
        case .banking: "building.columns"
        case .work: "signature"
        case .address: "building.2"
        case .finance: "number"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .prompt: "text.quote"
        }
    }

    var tint: NoteTint {
        switch self {
        case .none, .banking, .prompt: .purple
        case .work, .developer: .blue
        case .address: .amber
        case .finance: .rose
        }
    }

    static func option(for symbol: String?) -> Self {
        allCases.first { $0.symbol == symbol } ?? .none
    }
}

private enum NoteTint: String, Codable {
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

private enum PocketStorage {
    private static let notesKey = "keeply.notes"
    private static let snippetsKey = "keeply.snippets"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func loadNotes() -> [PocketNote] {
        load([PocketNote].self, forKey: notesKey) ?? PocketNote.samples
    }

    static func saveNotes(_ notes: [PocketNote]) {
        save(notes, forKey: notesKey)
    }

    static func loadSnippets() -> [CopySnippet] {
        load([CopySnippet].self, forKey: snippetsKey) ?? CopySnippet.samples
    }

    static func saveSnippets(_ snippets: [CopySnippet]) {
        save(snippets, forKey: snippetsKey)
    }

    private static func load<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private static func save<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
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
