//
//  SettingsManager.swift
//  MyAIChat
//
//  Persists user settings (API key, provider, model) to UserDefaults + Keychain.
//

import Foundation
import Security

/// Observable store for all user-configurable AI settings.
///
/// API key is stored in the iOS Keychain for security.
/// Provider and model are stored in UserDefaults.
@MainActor
final class SettingsManager: ObservableObject {

    static let shared = SettingsManager()

    // MARK: Published state

    /// The currently selected AI provider.
    @Published var selectedProvider: AIProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: Keys.provider)
            // Reset to the new provider's default model if current model is invalid.
            if !selectedProvider.models.contains(selectedModel) {
                selectedModel = selectedProvider.defaultModel
            }
        }
    }

    /// The currently selected model for the active provider.
    @Published var selectedModel: AIModel {
        didSet {
            if let data = try? JSONEncoder().encode(selectedModel) {
                UserDefaults.standard.set(data, forKey: Keys.model)
            }
        }
    }

    /// The API key for the currently selected provider (read from Keychain).
    @Published var apiKey: String = "" {
        didSet { saveKeyToKeychain(apiKey, for: selectedProvider) }
    }

    // MARK: Init

    private init() {
        // Restore provider
        let providerRaw = UserDefaults.standard.string(forKey: Keys.provider) ?? ""
        let provider = AIProvider(rawValue: providerRaw) ?? .openAI
        self.selectedProvider = provider

        // Restore model
        if let data = UserDefaults.standard.data(forKey: Keys.model),
           let model = try? JSONDecoder().decode(AIModel.self, from: data),
           provider.models.contains(model) {
            self.selectedModel = model
        } else {
            self.selectedModel = provider.defaultModel
        }

        // Restore API key from Keychain
        self.apiKey = loadKeyFromKeychain(for: provider) ?? ""
    }

    // MARK: Provider switching

    /// Loads the API key for the given provider from Keychain.
    func loadAPIKey(for provider: AIProvider) -> String {
        loadKeyFromKeychain(for: provider) ?? ""
    }

    /// Switches the provider and loads its stored API key.
    func switchProvider(_ provider: AIProvider) {
        guard provider != selectedProvider else { return }
        // Save the current key before switching.
        saveKeyToKeychain(apiKey, for: selectedProvider)
        // selectedProvider.didSet may reset selectedModel to provider.defaultModel — that's correct.
        selectedProvider = provider
        // Now load the stored key for the new provider.
        apiKey = loadKeyFromKeychain(for: provider) ?? ""
    }

    // MARK: Validation

    /// `true` when an API key is present and a provider+model are configured.
    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Keychain helpers

    private func keychainKey(for provider: AIProvider) -> String {
        "com.myaichat.apikey.\(provider.rawValue.lowercased())"
    }

    private func saveKeyToKeychain(_ key: String, for provider: AIProvider) {
        let service = keychainKey(for: provider)
        let data = Data(key.utf8)

        // Try update first.
        let updateQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
        ]
        let updateAttributes: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary,
                                        updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist yet — add it.
            let addQuery: [CFString: Any] = [
                kSecClass:            kSecClassGenericPassword,
                kSecAttrService:      service,
                kSecValueData:        data,
                kSecAttrAccessible:   kSecAttrAccessibleWhenUnlocked,
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private func loadKeyFromKeychain(for provider: AIProvider) -> String? {
        let service = keychainKey(for: provider)
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecReturnData:       kCFBooleanTrue!,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    // MARK: Keys

    private enum Keys {
        static let provider = "settings.provider"
        static let model    = "settings.model"
    }
}
