//
//  AIService.swift
//  MyAIChat
//
//  Abstraction over the AI chat backend, plus a mock implementation.
//

import Foundation

/// Errors that an `AIService` can throw.
enum AIServiceError: Error, Equatable {
    /// The provided message list contained nothing to respond to.
    case emptyConversation
    /// The request failed for an underlying reason.
    case requestFailed(String)
}

/// Defines the contract for generating assistant replies from a conversation.
///
/// Concrete implementations (mock, OpenAI-compatible, on-device, ...) conform
/// to this so they can be injected and swapped without touching the UI layer.
protocol AIService {

    /// Generates a single assistant reply for the given message history.
    ///
    /// - Parameter messages: The conversation so far, oldest first.
    /// - Returns: A new assistant `ChatMessage`.
    func sendMessage(_ messages: [ChatMessage]) async throws -> ChatMessage
}

/// A mock `AIService` that returns canned replies without any networking.
///
/// Useful for previews, tests, and developing the UI before a real backend
/// is wired up.
final class MockAIService: AIService {

    /// Artificial delay (in seconds) used to simulate network latency.
    private let responseDelay: TimeInterval

    /// Canned replies cycled through on each call.
    private let cannedReplies: [String]

    /// Index of the next canned reply to return.
    private var nextReplyIndex = 0

    init(responseDelay: TimeInterval = 0.6,
         cannedReplies: [String] = MockAIService.defaultReplies) {
        self.responseDelay = responseDelay
        self.cannedReplies = cannedReplies.isEmpty ? MockAIService.defaultReplies : cannedReplies
    }

    func sendMessage(_ messages: [ChatMessage]) async throws -> ChatMessage {
        // There must be at least one non-empty message to respond to.
        guard messages.contains(where: { !$0.isEmpty }) else {
            throw AIServiceError.emptyConversation
        }

        // Simulate network latency (cancellation-aware).
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }

        let reply = cannedReplies[nextReplyIndex % cannedReplies.count]
        nextReplyIndex += 1
        return .assistant(reply)
    }
}

// MARK: - Defaults

extension MockAIService {

    /// Default set of placeholder replies for the mock service.
    static let defaultReplies: [String] = [
        "Hello! I'm a mock assistant. How can I help you today?",
        "That's interesting — tell me more.",
        "Here's a placeholder response while the real backend is wired up.",
        "I'm not connected to a real model yet, but I'm listening!"
    ]
}
