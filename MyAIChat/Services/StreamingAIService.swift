//
//  StreamingAIService.swift
//  MyAIChat
//
//  Real AI backend with streaming support.
//  Supports OpenRouter, OpenAI, Anthropic, and Gemini (OpenAI-compat endpoint).
//

import Foundation

// MARK: - Streaming protocol extension

/// Extends `AIService` with a streaming variant that delivers incremental tokens.
protocol StreamingAIService: AIService {
    /// Streams tokens for an assistant reply; calls `onToken` for each chunk.
    /// Returns the final assembled `ChatMessage`.
    func streamMessage(
        _ messages: [ChatMessage],
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> ChatMessage
}

// MARK: - LiveAIService

/// Production implementation that routes requests to the configured provider.
final class LiveAIService: StreamingAIService {

    private let settings: SettingsManager

    init(settings: SettingsManager = .shared) {
        self.settings = settings
    }

    // MARK: AIService (non-streaming fallback)

    func sendMessage(_ messages: [ChatMessage]) async throws -> ChatMessage {
        var assembled = ""
        return try await streamMessage(messages) { token in
            assembled += token
        }
    }

    // MARK: StreamingAIService

    func streamMessage(
        _ messages: [ChatMessage],
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> ChatMessage {
        guard !messages.isEmpty else { throw AIServiceError.emptyConversation }

        let apiKey = await settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw AIServiceError.requestFailed("API key not configured. Open Settings to add one.")
        }

        let provider = await settings.selectedProvider
        let model    = await settings.selectedModel

        switch provider {
        case .anthropic:
            return try await streamAnthropic(messages: messages,
                                             model: model.id,
                                             apiKey: apiKey,
                                             onToken: onToken)
        case .openAI, .openRouter, .gemini:
            return try await streamOpenAICompat(messages: messages,
                                                model: model.id,
                                                apiKey: apiKey,
                                                baseURL: provider.baseURL,
                                                provider: provider,
                                                onToken: onToken)
        }
    }

    // MARK: - OpenAI-compatible streaming (OpenAI / OpenRouter / Gemini)

    private func streamOpenAICompat(
        messages: [ChatMessage],
        model: String,
        apiKey: String,
        baseURL: URL,
        provider: AIProvider,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> ChatMessage {

        let payload = OpenAIRequest(
            model: model,
            messages: messages.compactMap { msg -> OpenAIMessage? in
                guard msg.role != .system else {
                    return OpenAIMessage(role: "system", content: msg.text)
                }
                return OpenAIMessage(
                    role: msg.role == .user ? "user" : "assistant",
                    content: msg.text
                )
            },
            stream: true,
            maxTokens: 2048
        )

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // OpenRouter extras
        if provider == .openRouter {
            request.setValue("MyAIChat iOS", forHTTPHeaderField: "X-Title")
            request.setValue("https://github.com/myaichat", forHTTPHeaderField: "HTTP-Referer")
        }

        request.httpBody = try JSONEncoder().encode(payload)

        let (stream, response) = try await URLSession.shared.bytes(for: request)

        try validateHTTP(response)

        var fullText = ""

        for try await line in stream.lines {
            if Task.isCancelled { break }
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            if jsonString == "[DONE]" { break }

            if let data = jsonString.data(using: .utf8),
               let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: data),
               let delta = chunk.choices.first?.delta.content {
                fullText += delta
                onToken(delta)
            }
        }

        return .assistant(fullText.isEmpty ? "(no response)" : fullText)
    }

    // MARK: - Anthropic streaming

    private func streamAnthropic(
        messages: [ChatMessage],
        model: String,
        apiKey: String,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> ChatMessage {

        let anthropicMessages = messages.filter { $0.role != .system }.map { msg in
            AnthropicMessage(
                role: msg.role == .user ? "user" : "assistant",
                content: msg.text
            )
        }

        let systemPrompt = messages.first(where: { $0.role == .system })?.text

        let payload = AnthropicRequest(
            model: model,
            maxTokens: 2048,
            system: systemPrompt,
            messages: anthropicMessages,
            stream: true
        )

        var request = URLRequest(url: AIProvider.anthropic.baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json",       forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,                   forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",             forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(payload)

        let (stream, response) = try await URLSession.shared.bytes(for: request)

        try validateHTTP(response)

        var fullText = ""

        for try await line in stream.lines {
            if Task.isCancelled { break }
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))

            if let data = jsonString.data(using: .utf8),
               let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data) {
                switch event.type {
                case "content_block_delta":
                    if let delta = event.delta?.text {
                        fullText += delta
                        onToken(delta)
                    }
                case "message_stop":
                    break
                default:
                    break
                }
            }
        }

        return .assistant(fullText.isEmpty ? "(no response)" : fullText)
    }

    // MARK: - Helpers

    private func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw AIServiceError.requestFailed(
                "HTTP \(http.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))"
            )
        }
    }
}

// MARK: - OpenAI request/response types

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let stream: Bool
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, stream
        case maxTokens = "max_tokens"
    }
}

private struct OpenAIMessage: Encodable {
    let role: String
    let content: String
}

private struct OpenAIStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }
        let delta: Delta
    }
    let choices: [Choice]
}

// MARK: - Anthropic request/response types

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [AnthropicMessage]
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, system, messages, stream
        case maxTokens = "max_tokens"
    }
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

private struct AnthropicStreamEvent: Decodable {
    struct Delta: Decodable {
        let type: String?
        let text: String?
    }
    let type: String
    let delta: Delta?
}
