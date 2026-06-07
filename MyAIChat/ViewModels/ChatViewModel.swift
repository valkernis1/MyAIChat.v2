//
//  ChatViewModel.swift
//  MyAIChat
//
//  Drives a single chat: streaming replies + notifies list of changes.
//

import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: Published state

    @Published var conversation: Conversation
    @Published var draft: String = ""
    @Published private(set) var isSending: Bool = false
    @Published var errorMessage: String?

    // MARK: Callback

    /// Called whenever the conversation mutates so the list can persist it.
    var onConversationChanged: ((Conversation) -> Void)?

    // MARK: Private

    private let aiService: StreamingAIService
    private var streamingTask: Task<Void, Never>?

    // MARK: Init

    init(conversation: Conversation = Conversation(),
         aiService: StreamingAIService = LiveAIService()) {
        self.conversation = conversation
        self.aiService = aiService
    }

    // MARK: Derived

    var messages: [ChatMessage] { conversation.messages }

    var canSend: Bool { !isSending && !trimmedDraft.isEmpty }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Intents

    /// Sends the draft and starts streaming a reply.
    func send() {
        guard canSend else { return }
        let text = trimmedDraft
        draft = ""
        conversation.append(.user(text))

        // Auto-title from first user message
        if conversation.hasDefaultTitle {
            let words = text.split(separator: " ").prefix(5).joined(separator: " ")
            conversation.title = words.isEmpty ? text : words
        }

        notifyChanged()
        // Cancel any in-flight request before starting a new one
        streamingTask?.cancel()
        streamingTask = Task { await generateStreamingReply() }
    }

    /// Clears messages (keeps title).
    func clearConversation() {
        streamingTask?.cancel()
        streamingTask = nil
        conversation.clearMessages()
        conversation.title = Conversation.defaultTitle
        notifyChanged()
        errorMessage = nil
    }

    // MARK: Private — streaming

    private func generateStreamingReply() async {
        isSending = true
        errorMessage = nil
        defer {
            isSending = false
            notifyChanged()
        }

        var assistantMessage = ChatMessage.assistant("")
        conversation.append(assistantMessage)
        let assistantIndex = conversation.messages.count - 1

        do {
            _ = try await aiService.streamMessage(Array(conversation.messages.dropLast())) { [weak self] token in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    assistantMessage.text += token
                    self.conversation.messages[assistantIndex] = assistantMessage
                }
            }
        } catch is CancellationError {
            // Leave partial text as-is
        } catch let error as AIServiceError {
            if conversation.messages[assistantIndex].text.isEmpty {
                conversation.messages.remove(at: assistantIndex)
            }
            errorMessage = Self.localizedMessage(for: error)
        } catch {
            if conversation.messages[assistantIndex].text.isEmpty {
                conversation.messages.remove(at: assistantIndex)
            }
            errorMessage = error.localizedDescription
        }
    }

    private func notifyChanged() {
        onConversationChanged?(conversation)
    }

    private static func localizedMessage(for error: AIServiceError) -> String {
        switch error {
        case .emptyConversation:     return "There's nothing to send yet."
        case .requestFailed(let r):  return r
        }
    }
}
