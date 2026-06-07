//
//  UISettingsBundle.swift
//  MyAIChat
//
//  A single Codable snapshot of every user-facing setting:
//  UI customisation, text strings, background, font selection.
//
//  Version history (schemaVersion):
//    1 – initial (CustomFonts release)
//    2 – added AppBackgroundSettings, uiOpacity (Background release)
//    3 – added UISettingsBundle itself (Export/Import release)
//

import Foundation

// MARK: - Bundle

struct UISettingsBundle: Codable {

    // ── Schema ──────────────────────────────────────────────────────
    static let currentSchemaVersion: Int = 3
    var schemaVersion: Int = currentSchemaVersion

    // ── Metadata ────────────────────────────────────────────────────
    var presetName: String              // user-visible label
    var exportDate: Date
    var appVersion: String              // CFBundleShortVersionString at export time

    // ── Payload ─────────────────────────────────────────────────────
    var customization: UICustomizationSnapshot
    var textEntries:   [String: String]         // id → current value
    var background:    AppBackgroundSettings
    var activeFontName: String?                 // PostScript name, nil = system

    // MARK: - Init from live managers

    @MainActor
    init(presetName: String) {
        self.presetName    = presetName
        self.exportDate    = Date()
        self.appVersion    = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        self.customization = UICustomizationSnapshot(from: UICustomizationManager.shared)
        self.textEntries   = UITextManager.shared.entries.mapValues { $0.value }
        self.background    = AppBackgroundManager.shared.settings
        self.activeFontName = FontManager.shared.activeFontName
    }

    // MARK: - Apply to live managers

    @MainActor
    func apply(applyBackground: Bool = false) {
        let cm = UICustomizationManager.shared
        cm.button        = customization.button
        cm.inputField    = customization.inputField
        cm.title         = customization.title
        cm.bodyText      = customization.bodyText
        cm.messageBubble = customization.messageBubble
        cm.panel         = customization.panel
        cm.textScale     = customization.textScale

        let tm = UITextManager.shared
        for (key, value) in textEntries {
            tm.set(id: key, value: value)
        }

        if applyBackground {
            // Only apply non-media settings; media file itself stays as-is
            var bg = AppBackgroundManager.shared.settings
            bg.loopMode   = background.loopMode
            bg.dimAmount  = background.dimAmount
            bg.blurRadius = background.blurRadius
            bg.uiOpacity  = background.uiOpacity
            bg.contentMode = background.contentMode
            // Preserve type/file only if bundle has no media (none)
            if background.type == .none {
                bg.type = .none
                AppBackgroundManager.shared.clearBackground()
            }
            AppBackgroundManager.shared.settings = bg
        }

        FontManager.shared.activeFontName = activeFontName
    }
}

// MARK: - Snapshot of UICustomizationManager (all Codable fields)

struct UICustomizationSnapshot: Codable {
    var button:        ButtonCustomization
    var inputField:    InputFieldCustomization
    var title:         TitleCustomization
    var bodyText:      BodyTextCustomization
    var messageBubble: MessageBubbleCustomization
    var panel:         PanelCustomization
    var textScale:     Double

    @MainActor
    init(from m: UICustomizationManager) {
        button        = m.button
        inputField    = m.inputField
        title         = m.title
        bodyText      = m.bodyText
        messageBubble = m.messageBubble
        panel         = m.panel
        textScale     = m.textScale
    }
}
