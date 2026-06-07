//
//  ChatMessage.swift
//  MyAIChat
//
//  Model representing a single chat message.
//

import Foundation

/// The author of a chat message.
enum MessageRole: String, Codable, CaseIterable {
    case user
    case assistant
    case system
}

/// A single message within a conversation.
struct ChatMessage: Identifiable, Codable, Equatable, Hashable {

    /// Stable unique identifier for the message.
    let id: UUID

    /// Who authored the message.
    let role: MessageRole

    /// The message text content.
    var text: String

    /// When the message was created.
    let timestamp: Date

    init(id: UUID = UUID(),
         role: MessageRole,
         text: String,
         timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Convenience

extension ChatMessage {

    /// `true` when the message was sent by the user.
    var isFromUser: Bool { role == .user }

    /// `true` when the trimmed text contains no visible characters.
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Creates a user message.
    static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, text: text)
    }

    /// Creates an assistant message.
    static func assistant(_ text: String) -> ChatMessage {
        ChatMessage(role: .assistant, text: text)
    }

    /// Creates a system message.
    static func system(_ text: String) -> ChatMessage {
        ChatMessage(role: .system, text: text)
    }
}
