//
//  Conversation.swift
//  MyAIChat
//
//  Model representing a chat conversation (a thread of messages).
//

import Foundation

/// A conversation thread containing an ordered list of messages.
struct Conversation: Identifiable, Codable, Equatable, Hashable {

    /// Stable unique identifier for the conversation.
    let id: UUID

    /// User-facing title for the conversation.
    var title: String

    /// Ordered messages, oldest first.
    var messages: [ChatMessage]

    /// When the conversation was created.
    let createdAt: Date

    /// When the conversation was last modified.
    var updatedAt: Date

    init(id: UUID = UUID(),
         title: String = Conversation.defaultTitle,
         messages: [ChatMessage] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Constants

extension Conversation {

    /// Default title used for a freshly created conversation.
    static let defaultTitle = "New Chat"
}

// MARK: - Derived state

extension Conversation {

    /// `true` when the conversation has no messages.
    var isEmpty: Bool { messages.isEmpty }

    /// The most recent message, if any.
    var lastMessage: ChatMessage? { messages.last }

    /// Whether the conversation has only the default, unedited title.
    var hasDefaultTitle: Bool { title == Conversation.defaultTitle }
}

// MARK: - Mutation

extension Conversation {

    /// Appends a message and refreshes `updatedAt`.
    mutating func append(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = message.timestamp
    }

    /// Removes all messages and refreshes `updatedAt`.
    mutating func clearMessages() {
        messages.removeAll()
        updatedAt = Date()
    }
}
