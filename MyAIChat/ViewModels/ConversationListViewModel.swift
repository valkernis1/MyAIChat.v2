//
//  ConversationListViewModel.swift
//  MyAIChat
//
//  Drives the conversation list: CRUD + persistence + auto-save.
//

import Foundation
import Combine

@MainActor
final class ConversationListViewModel: ObservableObject {

    // MARK: Published state

    /// All conversations, newest first.
    @Published private(set) var conversations: [Conversation] = []

    /// The id of the currently selected conversation.
    @Published var selectedConversationID: Conversation.ID?

    // MARK: Private

    private let persistence: JSONPersistenceService
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    init(persistence: JSONPersistenceService = .shared) {
        self.persistence = persistence
        loadFromDisk()
        setupAutosave()
    }

    // MARK: Derived

    var selectedConversation: Conversation? {
        guard let id = selectedConversationID else { return nil }
        return conversations.first { $0.id == id }
    }

    var isEmpty: Bool { conversations.isEmpty }

    // MARK: Intents

    /// Creates a new conversation, inserts it at the top, selects it.
    @discardableResult
    func createConversation() -> Conversation {
        let c = Conversation()
        conversations.insert(c, at: 0)
        selectedConversationID = c.id
        // autosave debounce in setupAutosave() will persist this change
        return c
    }

    /// Selects the given conversation.
    func select(_ conversation: Conversation) {
        selectedConversationID = conversation.id
    }

    /// Called by ChatViewModel whenever the active conversation changes
    /// (new messages, title update, etc.).
    func update(_ conversation: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx] = conversation
        // Bubble to top if it has messages
        if !conversation.messages.isEmpty && idx != 0 {
            conversations.move(fromOffsets: IndexSet(integer: idx), toOffset: 0)
        }
        saveToDisk()
    }

    /// Renames a conversation.
    func rename(_ conversation: Conversation, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].title = trimmed
        saveToDisk()
    }

    /// Deletes conversations at the given offsets (swipe-to-delete).
    func deleteConversations(at offsets: IndexSet) {
        let removedIDs = Set(offsets.map { conversations[$0].id })
        for index in offsets.sorted(by: >) {
            conversations.remove(at: index)
        }
        if let selected = selectedConversationID, removedIDs.contains(selected) {
            selectedConversationID = conversations.first?.id
        }
        saveToDisk()
    }

    /// Deletes a single conversation by id.
    func delete(_ conversation: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        deleteConversations(at: IndexSet(integer: idx))
    }

    // MARK: Persistence

    private func loadFromDisk() {
        let loaded = (try? persistence.loadConversations()) ?? []
        conversations = loaded
        selectedConversationID = loaded.first?.id
    }

    private func saveToDisk() {
        persistence.saveAsync(conversations)
    }

    /// Debounced autosave when conversations array changes.
    private func setupAutosave() {
        $conversations
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] convs in
                self?.persistence.saveAsync(convs)
            }
            .store(in: &cancellables)
    }
}
