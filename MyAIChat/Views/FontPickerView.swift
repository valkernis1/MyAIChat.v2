//
//  FontPickerView.swift
//  MyAIChat
//
//  Full-screen sheet for managing custom fonts:
//  – Import .ttf / .otf from Files app
//  – Select active font or reset to system font
//  – Delete installed fonts
//  – Live preview of each font
//

import SwiftUI
import UniformTypeIdentifiers

struct FontPickerView: View {

    @ObservedObject private var fontManager   = FontManager.shared
    @ObservedObject private var customization = UICustomizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showDocumentPicker = false
    @State private var importError: String?
    @State private var showErrorAlert = false

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                importSection
                systemFontRow
                if !fontManager.installedFonts.isEmpty {
                    installedSection
                }
                infoSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Шрифты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(
                    allowedTypes: [
                        UTType(filenameExtension: "ttf")!,
                        UTType(filenameExtension: "otf")!
                    ]
                ) { url in
                    handleImport(url: url)
                }
            }
            .alert("Ошибка импорта", isPresented: $showErrorAlert, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(importError ?? "Неизвестная ошибка")
            })
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Import section

    private var importSection: some View {
        Section {
            Button {
                showDocumentPicker = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor)
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("Импортировать шрифт…")
                        .foregroundColor(.primary)
                }
            }
        } header: {
            Text("Добавить шрифт")
        } footer: {
            Text("Поддерживаются форматы .ttf и .otf. Шрифты импортируются из приложения Файлы.")
        }
    }

    // MARK: System font row

    private var systemFontRow: some View {
        Section("Выбранный шрифт") {
            fontRow(
                name: "Системный шрифт iOS",
                previewText: "The quick brown fox",
                postScriptName: nil
            )
        }
    }

    // MARK: Installed fonts

    private var installedSection: some View {
        Section("Установленные шрифты") {
            ForEach(fontManager.installedFonts) { font in
                fontRow(
                    name: font.displayName,
                    previewText: "Привет, мир! Hello world",
                    postScriptName: font.postScriptName,
                    userFont: font
                )
            }
        }
    }

    // MARK: Font row builder

    private func fontRow(
        name: String,
        previewText: String,
        postScriptName: String?,
        userFont: UserFont? = nil
    ) -> some View {
        let isActive = fontManager.activeFontName == postScriptName

        return HStack(spacing: 12) {
            // Checkmark
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isActive ? Theme.Colors.accent : Color(.tertiaryLabel))
                .font(.system(size: 20))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                // Live preview with actual font
                if let ps = postScriptName {
                    Text(previewText)
                        .font(.custom(ps, size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(previewText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Delete button (only for user fonts)
            if let uf = userFont {
                Button(role: .destructive) {
                    withAnimation {
                        fontManager.deleteFont(uf)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                fontManager.activeFontName = postScriptName
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Info section

    private var infoSection: some View {
        Section {
            EmptyView()
        } footer: {
            Text("Выбранный шрифт применяется ко всем текстам приложения. Если шрифт не поддерживает кириллицу, будет показан системный fallback.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: Import handler

    private func handleImport(url: URL) {
        let error = fontManager.importFont(from: url)
        if let e = error {
            importError = e
            showErrorAlert = true
        }
    }
}

// MARK: - UIDocumentPicker wrapper

private struct DocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

#Preview {
    FontPickerView()
}
