//
//  AIProvider.swift
//  MyAIChat
//
//  Supported AI providers and their available models.
//

import Foundation

/// A supported AI provider.
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openRouter = "OpenRouter"
    case openAI     = "OpenAI"
    case anthropic  = "Anthropic"
    case gemini     = "Gemini"

    var id: String { rawValue }

    /// Human-readable display name.
    var displayName: String { rawValue }

    /// Base URL for chat-completions endpoint.
    var baseURL: URL {
        switch self {
        case .openRouter: return URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        case .openAI:     return URL(string: "https://api.openai.com/v1/chat/completions")!
        case .anthropic:  return URL(string: "https://api.anthropic.com/v1/messages")!
        case .gemini:     return URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")!
        }
    }

    /// Available models for this provider.
    var models: [AIModel] {
        switch self {
        case .openRouter:
            return [
                AIModel(id: "openai/gpt-4o",                  name: "GPT-4o"),
                AIModel(id: "openai/gpt-4o-mini",             name: "GPT-4o Mini"),
                AIModel(id: "anthropic/claude-sonnet-4-5",    name: "Claude Sonnet 4.5"),
                AIModel(id: "anthropic/claude-opus-4",        name: "Claude Opus 4"),
                AIModel(id: "google/gemini-2.0-flash-001",    name: "Gemini 2.0 Flash"),
                AIModel(id: "meta-llama/llama-3.3-70b-instruct", name: "Llama 3.3 70B"),
                AIModel(id: "deepseek/deepseek-r1",           name: "DeepSeek R1"),
                AIModel(id: "mistralai/mistral-small-3.2-24b-instruct:free", name: "Mistral Small 3.2 (Free)"),
            ]
        case .openAI:
            return [
                AIModel(id: "gpt-4o",       name: "GPT-4o"),
                AIModel(id: "gpt-4o-mini",  name: "GPT-4o Mini"),
                AIModel(id: "gpt-4.1",      name: "GPT-4.1"),
                AIModel(id: "gpt-4.1-mini", name: "GPT-4.1 Mini"),
                AIModel(id: "o4-mini",      name: "o4-mini"),
                AIModel(id: "o3",           name: "o3"),
            ]
        case .anthropic:
            return [
                AIModel(id: "claude-sonnet-4-5-20251001",  name: "Claude Sonnet 4.5"),
                AIModel(id: "claude-opus-4-20250514",      name: "Claude Opus 4"),
                AIModel(id: "claude-haiku-4-5-20251001",   name: "Claude Haiku 4.5"),
                AIModel(id: "claude-3-7-sonnet-20250219",  name: "Claude 3.7 Sonnet"),
                AIModel(id: "claude-3-5-haiku-20241022",   name: "Claude 3.5 Haiku"),
            ]
        case .gemini:
            return [
                AIModel(id: "gemini-2.0-flash",         name: "Gemini 2.0 Flash"),
                AIModel(id: "gemini-2.0-flash-lite",    name: "Gemini 2.0 Flash Lite"),
                AIModel(id: "gemini-2.5-pro-preview-06-05", name: "Gemini 2.5 Pro Preview"),
                AIModel(id: "gemini-2.5-flash-preview-05-20", name: "Gemini 2.5 Flash Preview"),
            ]
        }
    }

    /// Default (first) model for this provider.
    var defaultModel: AIModel { models[0] }
}

/// A single model offered by a provider.
struct AIModel: Codable, Equatable, Hashable, Identifiable {
    /// API model identifier.
    let id: String
    /// User-facing name.
    let name: String
}
