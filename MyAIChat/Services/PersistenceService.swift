//
//  PersistenceService.swift
//  MyAIChat
//
//  Local persistence for conversations using FileManager + JSON.
//

import Foundation

/// Defines the contract for loading and saving conversations locally.
protocol PersistenceService {
    func loadConversations() throws -> [Conversation]
    func saveConversations(_ conversations: [Conversation]) throws
}

// MARK: - JSON file implementation

/// Stores conversations as a JSON file in the app's Documents directory.
/// Thread-safe: all I/O happens on a dedicated serial queue.
final class JSONPersistenceService: PersistenceService {

    static let shared = JSONPersistenceService()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.myaichat.persistence", qos: .utility)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("conversations.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadConversations() throws -> [Conversation] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([Conversation].self, from: data)
    }

    func saveConversations(_ conversations: [Conversation]) throws {
        let data = try encoder.encode(conversations)
        // Atomic write to avoid corruption on crash
        try data.write(to: fileURL, options: .atomicWrite)
    }

    /// Async fire-and-forget save (doesn't block caller).
    func saveAsync(_ conversations: [Conversation]) {
        let snapshot = conversations
        queue.async { [weak self] in
            try? self?.saveConversations(snapshot)
        }
    }
}

// MARK: - Legacy stub (kept for tests / previews)

final class InMemoryPersistenceService: PersistenceService {
    func loadConversations() throws -> [Conversation] { [] }
    func saveConversations(_ conversations: [Conversation]) throws {}
}
