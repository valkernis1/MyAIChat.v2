//
//  PresetsView.swift
//  MyAIChat
//
//  Browse built-in and user presets, export current settings to JSON,
//  import JSON files, apply any preset with instant UI update.
//

import SwiftUI
import UniformTypeIdentifiers

struct PresetsView: View {
    @ObservedObject private var manager = UIPresetsManager.shared
    @Environment(\.dismiss) private var dismiss

    // Export flow
    @State private var showExportNameAlert = false
    @State private var exportName         = ""
    @State private var showShareSheet     = false
    @State private var shareURL:   URL?

    // Import flow
    @State private var showFilePicker     = false

    // Apply confirmation
    @State private var pendingPreset:     UIPreset?
    @State private var showApplyConfirm   = false
    @State private var applyBg            = false

    // Save-as-preset flow
    @State private var showSaveAlert      = false
    @State private var saveName           = ""

    // Rename flow
    @State private var renamePreset:      UIPreset?
    @State private var showRenameAlert    = false
    @State private var renameName         = ""

    var body: some View {
        NavigationStack {
            List {
                exportImportSection
                if !manager.userPresets.isEmpty {
                    userPresetsSection
                }
                builtInPresetsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Пресеты и экспорт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveName = ""
                        showSaveAlert = true
                    } label: {
                        Label("Сохранить", systemImage: "plus")
                    }
                }
            }
            // ── Export name alert ──
            .alert("Имя пресета", isPresented: $showExportNameAlert) {
                TextField("Название", text: $exportName)
                    .autocorrectionDisabled()
                Button("Экспорт") {
                    guard !exportName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    manager.exportCurrentSettings(name: exportName.trimmingCharacters(in: .whitespaces))
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Введите имя для JSON-файла настроек.")
            }
            // ── Save as preset alert ──
            .alert("Сохранить пресет", isPresented: $showSaveAlert) {
                TextField("Название пресета", text: $saveName)
                    .autocorrectionDisabled()
                Button("Сохранить") {
                    let n = saveName.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    manager.saveCurrentAsPreset(name: n)
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Текущие настройки интерфейса будут сохранены как пресет.")
            }
            // ── Rename alert ──
            .alert("Переименовать", isPresented: $showRenameAlert) {
                TextField("Новое имя", text: $renameName)
                    .autocorrectionDisabled()
                Button("Сохранить") {
                    guard let p = renamePreset else { return }
                    let n = renameName.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    manager.renamePreset(id: p.id, newName: n)
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Введите новое имя для пресета.")
            }
            // ── Apply confirmation ──
            .alert("Применить пресет?", isPresented: $showApplyConfirm) {
                Toggle("Применить настройки фона", isOn: $applyBg)
                Button("Применить") {
                    if let p = pendingPreset {
                        withAnimation(.spring(response: 0.35)) {
                            manager.apply(p, applyBackground: applyBg)
                        }
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Текущие настройки интерфейса будут заменены. Это действие нельзя отменить.")
            }
            // ── Import error ──
            .alert("Ошибка импорта", isPresented: $manager.showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(manager.importError ?? "Неизвестная ошибка")
            }
            // ── Success toast ──
            .overlay(alignment: .bottom) {
                if manager.importSuccess {
                    importSuccessToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 32)
                }
            }
            .animation(.spring(response: 0.3), value: manager.importSuccess)
            // ── File picker (import) ──
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    manager.importSettings(from: url)
                case .failure(let err):
                    manager.importError    = err.localizedDescription
                    manager.showImportError = true
                }
            }
            // ── Share sheet (export) ──
            .sheet(isPresented: $manager.showShareSheet) {
                if let url = manager.exportURL {
                    ShareSheet(url: url)
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }

    // MARK: - Sections

    private var exportImportSection: some View {
        Section {
            // Export
            Button {
                exportName = ""
                showExportNameAlert = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Экспортировать настройки")
                            .foregroundColor(.primary)
                        Text("Сохранить в JSON и поделиться")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.accentColor)
                }
            }

            // Import
            Button {
                showFilePicker = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Импортировать настройки")
                            .foregroundColor(.primary)
                        Text("Загрузить из JSON-файла")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.green)
                }
            }
        } header: {
            Label("Экспорт / Импорт", systemImage: "arrow.up.arrow.down.circle")
        } footer: {
            Text("JSON-файл содержит все настройки UI. Настройки фона (файлы медиа) в файл не включаются, только параметры эффектов.")
        }
    }

    private var userPresetsSection: some View {
        Section {
            ForEach(manager.userPresets) { preset in
                PresetRow(preset: preset) {
                    pendingPreset   = preset
                    applyBg         = false
                    showApplyConfirm = true
                } onRename: {
                    renamePreset    = preset
                    renameName      = preset.name
                    showRenameAlert  = true
                } onDelete: {
                    manager.deletePreset(id: preset.id)
                }
            }
        } header: {
            Text("Мои пресеты")
        }
    }

    private var builtInPresetsSection: some View {
        Section {
            ForEach(manager.builtInPresets) { preset in
                PresetRow(preset: preset) {
                    pendingPreset   = preset
                    applyBg         = false
                    showApplyConfirm = true
                } onRename: nil
                  onDelete: nil
            }
        } header: {
            Text("Встроенные пресеты")
        } footer: {
            Text("Встроенные пресеты нельзя удалить. Нажмите «+», чтобы сохранить текущие настройки как свой пресет.")
        }
    }

    // MARK: - Success toast

    private var importSuccessToast: some View {
        Label("Настройки применены!", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.green.gradient, in: Capsule())
    }
}

// MARK: - PresetRow

private struct PresetRow: View {
    let preset:   UIPreset
    let onApply:  () -> Void
    let onRename: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Color swatch
            presetSwatch
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name)
                    .font(.subheadline.weight(.semibold))
                if preset.isBuiltIn {
                    Text("Встроенный")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(preset.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                onApply()
            } label: {
                Text("Применить")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Удалить", systemImage: "trash")
                }
            }
            if let onRename {
                Button(action: onRename) {
                    Label("Переименовать", systemImage: "pencil")
                }
                .tint(.orange)
            }
        }
    }

    // Mini color swatch representing the preset's theme
    private var presetSwatch: some View {
        let cm = preset.bundle.customization
        return ZStack {
            cm.panel.backgroundColor.swiftUIColor
            HStack(spacing: 0) {
                cm.messageBubble.userBubbleColor.swiftUIColor
                    .frame(maxWidth: .infinity)
                cm.messageBubble.assistantBubbleColor.swiftUIColor
                    .frame(maxWidth: .infinity)
            }
            .mask(
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 4)
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .frame(height: 12)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            )
        }
        .background(cm.panel.backgroundColor.swiftUIColor)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview {
    PresetsView()
}
