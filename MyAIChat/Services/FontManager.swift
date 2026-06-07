//
//  FontManager.swift
//  MyAIChat
//
//  Manages custom user fonts:
//  – Import .ttf / .otf from the Files app via UIDocumentPickerViewController
//  – Persist font files to Application Support/UserFonts/
//  – Dynamically register fonts with CoreText so they're available to SwiftUI
//  – Select / deselect the active font (persisted in UserDefaults)
//  – Delete custom fonts (removes file + unregisters)
//  – Fallback to system font when nothing is selected or registration fails
//

import SwiftUI
import CoreText
import UniformTypeIdentifiers

// MARK: - Font record

struct UserFont: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String     // e.g. "MyFont-Regular.ttf"
    let postScriptName: String  // CoreText name used in Font(name:size:)

    var displayName: String {
        // Strip extension for display
        (fileName as NSString).deletingPathExtension
    }
}

// MARK: - Manager

@MainActor
final class FontManager: ObservableObject {

    static let shared = FontManager()

    // MARK: Published state

    /// All successfully imported user fonts.
    @Published private(set) var installedFonts: [UserFont] = []

    /// PostScript name of the currently active font, or nil = system font.
    @Published var activeFontName: String? {
        didSet { persistActiveFontName() }
    }

    // MARK: Init

    private init() {
        // Ensure storage directory exists
        try? FileManager.default.createDirectory(
            at: Self.fontsDirectory,
            withIntermediateDirectories: true
        )

        // Load persisted list and re-register every font
        installedFonts = loadInstalledFonts()
        installedFonts.forEach { registerFont($0) }

        // Restore active selection
        activeFontName = UserDefaults.standard.string(forKey: Keys.activeFont)
        // Validate – active font must still be installed
        if let name = activeFontName,
           !installedFonts.contains(where: { $0.postScriptName == name }) {
            activeFontName = nil
        }
    }

    // MARK: - Storage directory

    static var fontsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UserFonts", isDirectory: true)
    }

    // MARK: - Import

    /// Copies font data from a temporary URL (from UIDocumentPicker), registers it,
    /// and adds it to the installed list.
    /// Returns an error string if something went wrong, nil on success.
    @discardableResult
    func importFont(from sourceURL: URL) -> String? {
        let fileName = sourceURL.lastPathComponent
        let destURL  = Self.fontsDirectory.appendingPathComponent(fileName)

        // Copy file (overwrite if already exists)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            // Access security-scoped resource if needed
            let secured = sourceURL.startAccessingSecurityScopedResource()
            defer { if secured { sourceURL.stopAccessingSecurityScopedResource() } }

            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            return "Не удалось скопировать файл: \(error.localizedDescription)"
        }

        // Register with CoreText and get PostScript name
        guard let postScriptName = registerFontFile(at: destURL) else {
            try? FileManager.default.removeItem(at: destURL)
            return "Не удалось зарегистрировать шрифт. Убедитесь, что файл .ttf/.otf не повреждён."
        }

        // Avoid duplicates
        if installedFonts.contains(where: { $0.postScriptName == postScriptName }) {
            return nil  // already installed, no error
        }

        let record = UserFont(id: UUID(), fileName: fileName, postScriptName: postScriptName)
        installedFonts.append(record)
        saveInstalledFonts()
        return nil
    }

    // MARK: - Delete

    func deleteFont(_ font: UserFont) {
        // Deactivate if it's the current font
        if activeFontName == font.postScriptName {
            activeFontName = nil
        }

        // Unregister from CoreText
        let fileURL = Self.fontsDirectory.appendingPathComponent(font.fileName)
        unregisterFontFile(at: fileURL)

        // Remove from disk
        try? FileManager.default.removeItem(at: fileURL)

        // Remove from list
        installedFonts.removeAll { $0.id == font.id }
        saveInstalledFonts()
    }

    // MARK: - Font resolution (used by views)

    /// Returns a SwiftUI Font using the active custom font, falling back to system.
    func font(size: Double, weight: Font.Weight = .regular) -> Font {
        if let name = activeFontName, !name.isEmpty {
            // Custom font doesn't support weight variants natively unless the family
            // has dedicated files; we use the single registered file.
            return Font.custom(name, size: size)
        }
        return Font.system(size: size, weight: weight)
    }

    /// Same as font(size:weight:) but accepts the String-based weight the project uses.
    func font(size: Double, weightString: String) -> Font {
        font(size: size, weight: weightString.swiftUIFontWeight)
    }

    // MARK: - CoreText registration helpers

    @discardableResult
    private func registerFont(_ record: UserFont) -> Bool {
        let url = Self.fontsDirectory.appendingPathComponent(record.fileName)
        return registerFontFile(at: url) != nil
    }

    /// Registers font file at URL with CoreText. Returns PostScript name on success.
    private func registerFontFile(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) as CFData,
              let provider = CGDataProvider(data: data),
              let cgFont = CGFont(provider) else { return nil }

        var error: Unmanaged<CFError>?
        // Register (ignore error if already registered)
        CTFontManagerRegisterGraphicsFont(cgFont, &error)

        // Extract PostScript name regardless
        if let psName = cgFont.postScriptName as String? {
            return psName
        }
        return nil
    }

    private func unregisterFontFile(at url: URL) {
        guard let data = try? Data(contentsOf: url) as CFData,
              let provider = CGDataProvider(data: data),
              let cgFont = CGFont(provider) else { return }
        var error: Unmanaged<CFError>?
        CTFontManagerUnregisterGraphicsFont(cgFont, &error)
    }

    // MARK: - Persistence

    private enum Keys {
        static let installedFonts = "font.manager.installedFonts.v1"
        static let activeFont     = "font.manager.activeFont"
    }

    private func saveInstalledFonts() {
        if let data = try? JSONEncoder().encode(installedFonts) {
            UserDefaults.standard.set(data, forKey: Keys.installedFonts)
        }
    }

    private func loadInstalledFonts() -> [UserFont] {
        guard let data = UserDefaults.standard.data(forKey: Keys.installedFonts),
              let fonts = try? JSONDecoder().decode([UserFont].self, from: data) else {
            return []
        }
        // Filter to only fonts whose files still exist on disk
        return fonts.filter {
            FileManager.default.fileExists(
                atPath: Self.fontsDirectory.appendingPathComponent($0.fileName).path
            )
        }
    }

    private func persistActiveFontName() {
        if let name = activeFontName {
            UserDefaults.standard.set(name, forKey: Keys.activeFont)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.activeFont)
        }
    }
}
