//
//  UITextManager.swift
//  MyAIChat
//
//  Stores every user-facing text string that can be customised.
//  Each string has a key, a current value, and a default value.
//  Changes are persisted immediately in UserDefaults.
//

import SwiftUI
import Combine

// MARK: - Text entry

struct UITextEntry: Codable, Equatable, Identifiable {
    let id: String          // stable key, never changes
    var value: String       // current (possibly edited) text
    let defaultValue: String
    let category: String    // "Заголовки", "Кнопки", "Подсказки", "Плейсхолдеры"
    let description: String // shown as row label in the editor

    mutating func reset() { value = defaultValue }
}

// MARK: - Manager

@MainActor
final class UITextManager: ObservableObject {

    static let shared = UITextManager()
    private static let udKey = "ui.text.customization.v1"

    // All editable text entries, keyed by id
    @Published private(set) var entries: [String: UITextEntry] = [:]

    // MARK: Default catalogue

    private static let defaults: [UITextEntry] = [

        // ── Заголовки ────────────────────────────────────────────────
        UITextEntry(id: "title.emptyState",
                    value: "How can I help you today?",
                    defaultValue: "How can I help you today?",
                    category: "Заголовки",
                    description: "Главный заголовок пустого экрана"),

        UITextEntry(id: "title.conversationList",
                    value: "Chats",
                    defaultValue: "Chats",
                    category: "Заголовки",
                    description: "Заголовок списка чатов"),

        UITextEntry(id: "title.settings",
                    value: "Settings",
                    defaultValue: "Settings",
                    category: "Заголовки",
                    description: "Заголовок экрана настроек"),

        UITextEntry(id: "title.renameAlert",
                    value: "Rename Chat",
                    defaultValue: "Rename Chat",
                    category: "Заголовки",
                    description: "Заголовок диалога переименования"),

        // ── Кнопки ───────────────────────────────────────────────────
        UITextEntry(id: "button.newChat",
                    value: "Start a new chat",
                    defaultValue: "Start a new chat",
                    category: "Кнопки",
                    description: "Кнопка создания чата (пустой экран)"),

        UITextEntry(id: "button.renameSave",
                    value: "Save",
                    defaultValue: "Save",
                    category: "Кнопки",
                    description: "Кнопка «Сохранить» в диалоге переименования"),

        UITextEntry(id: "button.renameCancel",
                    value: "Cancel",
                    defaultValue: "Cancel",
                    category: "Кнопки",
                    description: "Кнопка «Отмена» в диалоге переименования"),

        UITextEntry(id: "button.settingsDone",
                    value: "Done",
                    defaultValue: "Done",
                    category: "Кнопки",
                    description: "Кнопка «Готово» в настройках"),

        UITextEntry(id: "button.swipeDelete",
                    value: "Delete",
                    defaultValue: "Delete",
                    category: "Кнопки",
                    description: "Свайп-кнопка удаления чата"),

        UITextEntry(id: "button.swipeRename",
                    value: "Rename",
                    defaultValue: "Rename",
                    category: "Кнопки",
                    description: "Свайп-кнопка переименования чата"),

        UITextEntry(id: "button.editModeBanner",
                    value: "Открыть",
                    defaultValue: "Открыть",
                    category: "Кнопки",
                    description: "Кнопка «Открыть» в баннере режима редактирования"),

        UITextEntry(id: "button.clearAPIKey",
                    value: "Clear",
                    defaultValue: "Clear",
                    category: "Кнопки",
                    description: "Кнопка сброса API-ключа"),

        // ── Подсказки ────────────────────────────────────────────────
        UITextEntry(id: "hint.emptyBody",
                    value: "Ask me anything to get started.",
                    defaultValue: "Ask me anything to get started.",
                    category: "Подсказки",
                    description: "Подзаголовок пустого экрана чата"),

        UITextEntry(id: "hint.noChatsYet",
                    value: "No chats yet",
                    defaultValue: "No chats yet",
                    category: "Подсказки",
                    description: "Заглушка при пустом списке чатов"),

        UITextEntry(id: "hint.noMessages",
                    value: "No messages yet",
                    defaultValue: "No messages yet",
                    category: "Подсказки",
                    description: "Подпись чата без сообщений в списке"),

        UITextEntry(id: "hint.editModeBanner",
                    value: "Режим редактирования",
                    defaultValue: "Режим редактирования",
                    category: "Подсказки",
                    description: "Текст баннера режима редактирования"),

        UITextEntry(id: "hint.renameMessage",
                    value: "Enter a new name for this chat.",
                    defaultValue: "Enter a new name for this chat.",
                    category: "Подсказки",
                    description: "Сообщение в диалоге переименования"),

        UITextEntry(id: "hint.statusReady",
                    value: "Ready",
                    defaultValue: "Ready",
                    category: "Подсказки",
                    description: "Статус «Готово» в настройках"),

        UITextEntry(id: "hint.statusMissingKey",
                    value: "API key required",
                    defaultValue: "API key required",
                    category: "Подсказки",
                    description: "Статус «Нужен API-ключ» в настройках"),

        UITextEntry(id: "hint.statusMissingKeyDetail",
                    value: "Add an API key above to start chatting",
                    defaultValue: "Add an API key above to start chatting",
                    category: "Подсказки",
                    description: "Детали статуса без ключа"),

        // ── Плейсхолдеры ─────────────────────────────────────────────
        UITextEntry(id: "placeholder.messageInput",
                    value: "Message",
                    defaultValue: "Message",
                    category: "Плейсхолдеры",
                    description: "Плейсхолдер поля ввода сообщения"),

        UITextEntry(id: "placeholder.apiKey",
                    value: "Paste your API key",
                    defaultValue: "Paste your API key",
                    category: "Плейсхолдеры",
                    description: "Плейсхолдер поля API-ключа"),

        UITextEntry(id: "placeholder.chatName",
                    value: "Chat name",
                    defaultValue: "Chat name",
                    category: "Плейсхолдеры",
                    description: "Плейсхолдер поля имени в переименовании"),
    ]

    // MARK: Init

    private init() {
        var base: [String: UITextEntry] = Dictionary(
            uniqueKeysWithValues: Self.defaults.map { ($0.id, $0) }
        )
        if let saved = Self.loadSaved() {
            for (key, saved) in saved {
                base[key]?.value = saved
            }
        }
        entries = base
    }

    // MARK: Public API

    /// Current value for a key, falls back to default if missing
    func text(_ id: String) -> String {
        entries[id]?.value ?? (Self.defaults.first { $0.id == id }?.defaultValue ?? id)
    }

    /// Update a single entry value
    func set(id: String, value: String) {
        guard entries[id] != nil else { return }
        entries[id]!.value = value
        persist()
    }

    /// Reset a single entry to its default
    func reset(id: String) {
        guard let def = Self.defaults.first(where: { $0.id == id }) else { return }
        entries[id]?.value = def.defaultValue
        persist()
    }

    /// Reset all entries to defaults
    func resetAll() {
        for key in entries.keys {
            if let def = Self.defaults.first(where: { $0.id == key }) {
                entries[key]?.value = def.defaultValue
            }
        }
        persist()
    }

    /// Grouped entries for display
    var groupedByCategory: [(category: String, entries: [UITextEntry])] {
        let order = ["Заголовки", "Кнопки", "Подсказки", "Плейсхолдеры"]
        var groups: [String: [UITextEntry]] = [:]
        for entry in entries.values { groups[entry.category, default: []].append(entry) }
        return order.compactMap { cat in
            guard let items = groups[cat], !items.isEmpty else { return nil }
            return (cat, items.sorted { $0.description < $1.description })
        }
    }

    // MARK: Persistence

    private func persist() {
        let dict = entries.mapValues { $0.value }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: Self.udKey)
        }
    }

    private static func loadSaved() -> [String: String]? {
        guard let data = UserDefaults.standard.data(forKey: udKey) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }
}
