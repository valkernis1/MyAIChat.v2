//
//  UIPresetsManager.swift
//  MyAIChat
//
//  Manages:
//    • Built-in presets (read-only)
//    • User-saved presets (stored in Documents/Presets/)
//    • Export: UISettingsBundle → JSON file (share sheet)
//    • Import: JSON file → UISettingsBundle → apply
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Preset record

struct UIPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var bundle: UISettingsBundle
    let isBuiltIn: Bool         // built-ins cannot be deleted

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: bundle.exportDate)
    }
}

// MARK: - Manager

@MainActor
final class UIPresetsManager: ObservableObject {

    static let shared = UIPresetsManager()

    // MARK: State

    @Published private(set) var builtInPresets: [UIPreset] = []
    @Published private(set) var userPresets:    [UIPreset] = []

    /// Non-nil while showing a share sheet for an exported file
    @Published var exportURL:    URL?
    @Published var showShareSheet = false

    /// Import feedback
    @Published var importError:    String?
    @Published var showImportError = false
    @Published var importSuccess   = false

    // MARK: Init

    private init() {
        builtInPresets = Self.makeBuiltIns()
        loadUserPresets()
    }

    // MARK: - Built-in presets

    private static func makeBuiltIns() -> [UIPreset] {
        [
            makePreset(name: "По умолчанию", bundle: defaultBundle()),
            makePreset(name: "Тёмная тема",  bundle: darkBundle()),
            makePreset(name: "Минимализм",   bundle: minimalBundle()),
            makePreset(name: "Ночной синий", bundle: nightBlueBundle()),
        ]
    }

    private static func makePreset(name: String, bundle: UISettingsBundle) -> UIPreset {
        UIPreset(id: UUID(), name: name, bundle: bundle, isBuiltIn: true)
    }

    // MARK: - User preset CRUD

    func saveCurrentAsPreset(name: String) {
        let bundle = UISettingsBundle(presetName: name)
        let preset = UIPreset(id: UUID(), name: name, bundle: bundle, isBuiltIn: false)
        userPresets.insert(preset, at: 0)
        persistUserPresets()
    }

    func deletePreset(id: UUID) {
        userPresets.removeAll { $0.id == id }
        persistUserPresets()
    }

    func renamePreset(id: UUID, newName: String) {
        guard let idx = userPresets.firstIndex(where: { $0.id == id }) else { return }
        userPresets[idx].name = newName
        userPresets[idx].bundle.presetName = newName
        persistUserPresets()
    }

    // MARK: - Apply preset

    func apply(_ preset: UIPreset, applyBackground: Bool = false) {
        preset.bundle.apply(applyBackground: applyBackground)
    }

    // MARK: - Export

    /// Creates a JSON file, populates exportURL, triggers share sheet
    func exportCurrentSettings(name: String) {
        let bundle = UISettingsBundle(presetName: name)

        let encoder         = JSONEncoder()
        encoder.outputFormatting     = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(bundle) else {
            showError("Не удалось закодировать настройки.")
            return
        }

        let dir = exportDirectory()
        let safe = name
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "-_ ")).inverted)
            .joined()
        let fileName = "\(safe.isEmpty ? "preset" : safe)_\(dateStamp()).json"
        let url = dir.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
            exportURL     = url
            showShareSheet = true
        } catch {
            showError("Ошибка записи: \(error.localizedDescription)")
        }
    }

    // MARK: - Import

    /// Parses a JSON file and applies the settings
    func importSettings(from url: URL, applyBackground: Bool = false) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            showError("Не удалось прочитать файл.")
            return
        }
        importFromData(data, applyBackground: applyBackground)
    }

    func importFromData(_ data: Data, applyBackground: Bool = false) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let bundle = try? decoder.decode(UISettingsBundle.self, from: data) else {
            showError("Файл повреждён или несовместим с текущей версией.")
            return
        }

        guard bundle.schemaVersion <= UISettingsBundle.currentSchemaVersion else {
            showError("Файл создан новой версией приложения (v\(bundle.schemaVersion)). Обновите приложение.")
            return
        }

        bundle.apply(applyBackground: applyBackground)

        // Auto-save to user presets — update existing if same name, insert if new
        let preset = UIPreset(id: UUID(), name: bundle.presetName, bundle: bundle, isBuiltIn: false)
        if let existing = userPresets.firstIndex(where: { $0.name == bundle.presetName }) {
            userPresets[existing] = UIPreset(id: userPresets[existing].id,
                                             name: bundle.presetName,
                                             bundle: bundle,
                                             isBuiltIn: false)
        } else {
            userPresets.insert(preset, at: 0)
        }
        persistUserPresets()

        importSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.importSuccess = false
        }
    }

    // MARK: - Persistence (user presets)

    private func persistUserPresets() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(userPresets) {
            try? data.write(to: presetsFileURL(), options: .atomic)
        }
    }

    private func loadUserPresets() {
        let url = presetsFileURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        userPresets = (try? decoder.decode([UIPreset].self, from: data)) ?? []
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        importError = message
        showImportError = true
    }

    private func presetsFileURL() -> URL {
        presetsDirectory().appendingPathComponent("user_presets.json")
    }

    private func presetsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("Presets", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func exportDirectory() -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("UIExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    private func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }
}

// MARK: - Built-in preset definitions

private func defaultBundle() -> UISettingsBundle {
    var b = UISettingsBundle.__empty()
    b.customization = UICustomizationSnapshot.__default()
    b.background    = .default
    b.textEntries   = [:]
    return b
}

private func darkBundle() -> UISettingsBundle {
    var b = UISettingsBundle.__empty()
    var c = UICustomizationSnapshot.__default()

    let dark   = CustomColor(red: 0.12, green: 0.12, blue: 0.14)
    let darker = CustomColor(red: 0.08, green: 0.08, blue: 0.10)
    let white  = CustomColor(red: 1, green: 1, blue: 1)
    let lightGray = CustomColor(red: 0.7, green: 0.7, blue: 0.72)
    let accent = CustomColor(red: 0.20, green: 0.60, blue: 1.0)

    c.panel.backgroundColor  = darker
    c.panel.inputBarBackground = dark
    c.panel.separatorColor   = CustomColor(red: 0.25, green: 0.25, blue: 0.28)

    c.messageBubble.userBubbleColor      = accent
    c.messageBubble.assistantBubbleColor = dark
    c.messageBubble.assistantTextColor   = white
    c.messageBubble.userTextColor        = white

    c.inputField.backgroundColor = dark
    c.inputField.textColor       = white
    c.inputField.borderColor     = CustomColor(red: 0.3, green: 0.3, blue: 0.35)

    c.button.backgroundColor = accent
    c.title.color    = white
    c.bodyText.color = lightGray

    b.customization = c
    b.background    = .default
    b.textEntries   = [:]
    return b
}

private func minimalBundle() -> UISettingsBundle {
    var b = UISettingsBundle.__empty()
    var c = UICustomizationSnapshot.__default()

    let offWhite = CustomColor(red: 0.98, green: 0.98, blue: 0.98)
    let subtle   = CustomColor(red: 0.92, green: 0.92, blue: 0.92)
    let inkBlack = CustomColor(red: 0.10, green: 0.10, blue: 0.10)
    let gray     = CustomColor(red: 0.50, green: 0.50, blue: 0.50)

    c.panel.backgroundColor   = .init(red: 1, green: 1, blue: 1)
    c.panel.inputBarBackground = offWhite
    c.panel.separatorColor    = subtle

    c.messageBubble.userBubbleColor      = inkBlack
    c.messageBubble.assistantBubbleColor = subtle
    c.messageBubble.assistantTextColor   = inkBlack
    c.messageBubble.shadowRadius  = 0
    c.messageBubble.shadowOpacity = 0
    c.messageBubble.cornerRadius  = 8

    c.inputField.backgroundColor = offWhite
    c.inputField.borderWidth     = 0
    c.inputField.cornerRadius    = 8

    c.button.backgroundColor = inkBlack
    c.button.cornerRadius    = 8
    c.button.shadowRadius    = 0
    c.button.shadowOpacity   = 0

    c.title.fontWeight    = "regular"
    c.bodyText.color      = gray
    c.textScale           = 0.95

    b.customization = c
    b.background    = .default
    b.textEntries   = [:]
    return b
}

private func nightBlueBundle() -> UISettingsBundle {
    var b = UISettingsBundle.__empty()
    var c = UICustomizationSnapshot.__default()

    let navy   = CustomColor(red: 0.05, green: 0.10, blue: 0.22)
    let blue   = CustomColor(red: 0.08, green: 0.16, blue: 0.34)
    let bright = CustomColor(red: 0.36, green: 0.72, blue: 1.0)
    let white  = CustomColor(red: 1, green: 1, blue: 1)
    let soft   = CustomColor(red: 0.75, green: 0.85, blue: 1.0)

    c.panel.backgroundColor   = navy
    c.panel.inputBarBackground = blue
    c.panel.separatorColor    = CustomColor(red: 0.15, green: 0.25, blue: 0.45)

    c.messageBubble.userBubbleColor      = bright
    c.messageBubble.assistantBubbleColor = blue
    c.messageBubble.assistantTextColor   = white
    c.messageBubble.userTextColor        = navy
    c.messageBubble.shadowRadius  = 6
    c.messageBubble.shadowOpacity = 0.25

    c.inputField.backgroundColor = navy
    c.inputField.textColor       = white
    c.inputField.borderColor     = CustomColor(red: 0.2, green: 0.35, blue: 0.6)

    c.button.backgroundColor = bright
    c.button.foregroundColor = navy

    c.title.color    = white
    c.bodyText.color = soft

    b.customization = c
    b.background    = .default
    b.textEntries   = [:]
    return b
}

// MARK: - UISettingsBundle helpers for preset factories

extension UISettingsBundle {
    static func __empty() -> UISettingsBundle {
        UISettingsBundle(
            schemaVersion: UISettingsBundle.currentSchemaVersion,
            presetName: "",
            exportDate: Date(),
            appVersion: "",
            customization: UICustomizationSnapshot.__default(),
            textEntries: [:],
            background: .default,
            activeFontName: nil
        )
    }

    // Internal memberwise init used only by preset factories
    init(schemaVersion: Int, presetName: String, exportDate: Date, appVersion: String,
         customization: UICustomizationSnapshot, textEntries: [String: String],
         background: AppBackgroundSettings, activeFontName: String?) {
        self.schemaVersion  = schemaVersion
        self.presetName     = presetName
        self.exportDate     = exportDate
        self.appVersion     = appVersion
        self.customization  = customization
        self.textEntries    = textEntries
        self.background     = background
        self.activeFontName = activeFontName
    }
}

extension UICustomizationSnapshot {
    static func __default() -> UICustomizationSnapshot {
        UICustomizationSnapshot(
            button:        .default,
            inputField:    .default,
            title:         .default,
            bodyText:      .default,
            messageBubble: .default,
            panel:         .default,
            textScale:     1.0
        )
    }
}
