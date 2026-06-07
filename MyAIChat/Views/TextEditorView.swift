//
//  TextEditorView.swift
//  MyAIChat
//
//  Lets the user rename every visible text string in the UI:
//  headings, buttons, hints, and placeholders.
//  Changes are saved immediately to UserDefaults.
//

import SwiftUI

struct TextEditorView: View {

    @ObservedObject private var textManager = UITextManager.shared
    @Environment(\.dismiss) private var dismiss

    // The entry currently being edited in the inline alert
    @State private var editingEntry: UITextEntry?
    @State private var editingValue: String = ""
    @State private var showEditAlert = false

    var body: some View {
        NavigationStack {
            List {
                introSection

                ForEach(textManager.groupedByCategory, id: \.category) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            TextEntryRow(entry: entry) {
                                editingEntry = entry
                                editingValue = entry.value
                                showEditAlert = true
                            } onReset: {
                                textManager.reset(id: entry.id)
                            }
                        }
                    } header: {
                        categoryHeader(group.category)
                    }
                }

                resetAllSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Тексты интерфейса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Изменить текст", isPresented: $showEditAlert, presenting: editingEntry) { entry in
                TextField(entry.defaultValue, text: $editingValue)
                    .autocorrectionDisabled()
                Button("Сохранить") {
                    let trimmed = editingValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    textManager.set(id: entry.id, value: trimmed.isEmpty ? entry.defaultValue : trimmed)
                }
                Button("Отмена", role: .cancel) {}
            } message: { entry in
                Text(entry.description)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Intro section

    private var introSection: some View {
        Section {
            Text("Нажмите на любую строку, чтобы изменить текст. Нажмите и удерживайте (или смахните влево), чтобы сбросить к значению по умолчанию.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    // MARK: Reset all

    private var resetAllSection: some View {
        Section {
            Button(role: .destructive) {
                textManager.resetAll()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Сбросить все тексты")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        } footer: {
            Text("Восстановит все тексты к исходным значениям.")
        }
    }

    // MARK: Category header

    @ViewBuilder
    private func categoryHeader(_ category: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: categoryIcon(category))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(categoryColor(category))
            Text(category)
        }
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "Заголовки":    return "textformat.size"
        case "Кнопки":       return "rectangle.and.hand.point.up.left.fill"
        case "Подсказки":    return "info.circle"
        case "Плейсхолдеры": return "text.cursor"
        default:             return "text.quote"
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "Заголовки":    return .orange
        case "Кнопки":       return .blue
        case "Подсказки":    return .green
        case "Плейсхолдеры": return .purple
        default:             return .secondary
        }
    }
}

// MARK: - Text entry row

private struct TextEntryRow: View {

    let entry: UITextEntry
    let onEdit: () -> Void
    let onReset: () -> Void

    private var isModified: Bool { entry.value != entry.defaultValue }

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.description)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        if isModified {
                            modifiedBadge
                        }
                    }
                    Text(entry.value)
                        .font(.caption)
                        .foregroundColor(isModified ? .accentColor : .secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isModified {
                Button(role: .destructive, action: onReset) {
                    Label("Сбросить", systemImage: "arrow.counterclockwise")
                }
                .tint(.orange)
            }
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Изменить", systemImage: "pencil")
            }
            if isModified {
                Button(role: .destructive, action: onReset) {
                    Label("Сбросить к стандартному", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    private var modifiedBadge: some View {
        Text("изм.")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.accentColor))
    }
}

#Preview {
    TextEditorView()
}
