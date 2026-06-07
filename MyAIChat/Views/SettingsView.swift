//
//  SettingsView.swift
//  MyAIChat
//
//  Settings screen: API key, provider selection, and model selection.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings      = SettingsManager.shared
    @ObservedObject private var texts         = UITextManager.shared
    @ObservedObject private var customization = UICustomizationManager.shared
    @ObservedObject private var fontManager   = FontManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isAPIKeyVisible       = false
    @State private var showCopiedToast       = false
    @State private var showFontPicker        = false
    @State private var showBackgroundSettings = false
    @State private var showPresetsView        = false

    var body: some View {
        NavigationStack {
            Form {
                presetsSection
                backgroundSection
                fontSection
                textScaleSection
                providerSection
                modelSection
                apiKeySection
                statusSection
            }
            .navigationTitle(texts.text("title.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(texts.text("button.settingsDone")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    toastView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 32)
                }
            }
            .animation(.spring(response: 0.3), value: showCopiedToast)
            .sheet(isPresented: $showFontPicker) {
                FontPickerView()
            }
            .sheet(isPresented: $showBackgroundSettings) {
                BackgroundSettingsView()
            }
            .sheet(isPresented: $showPresetsView) {
                PresetsView()
            }
        }
    }

    // MARK: Sections

    @ObservedObject private var bgManager     = AppBackgroundManager.shared
    @ObservedObject private var presetsManager = UIPresetsManager.shared

    private var presetsSection: some View {
        Section {
            Button {
                showPresetsView = true
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Пресеты и экспорт")
                                .foregroundColor(.primary)
                            Text(presetsManager.userPresets.isEmpty
                                 ? "Встроенные пресеты"
                                 : "\(presetsManager.userPresets.count) своих · \(presetsManager.builtInPresets.count) встроенных")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.and.arrow.up.on.square")
                            .foregroundColor(Theme.Colors.accent)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.tertiaryLabel)
                }
            }
            .foregroundColor(.primary)
        } header: {
            Label("Пресеты", systemImage: "paintpalette")
        } footer: {
            Text("Сохраняйте и восстанавливайте полные настройки интерфейса. Экспортируйте в JSON и делитесь с другими.")
        }
    }

    private var backgroundSection: some View {
        Section {
            Button {
                showBackgroundSettings = true
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Фон приложения")
                                .foregroundColor(.primary)
                            Text(bgManager.settings.type == .none
                                 ? "Не задан"
                                 : bgManager.settings.type.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundColor(Theme.Colors.accent)
                    }
                    Spacer()
                    if let img = bgManager.backgroundImage {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.tertiaryLabel)
                }
            }
            .foregroundColor(.primary)
        } header: {
            Label("Фон", systemImage: "photo.on.rectangle")
        } footer: {
            Text("Установите изображение, GIF, видео или Live Photo в качестве фона приложения.")
        }
    }

    private var fontSection: some View {
        Section {
            Button {
                showFontPicker = true
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Шрифт интерфейса")
                                .foregroundColor(.primary)
                            Text(activeFontDisplayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "textformat")
                            .foregroundColor(Theme.Colors.accent)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.tertiaryLabel)
                }
            }
            .foregroundColor(.primary)
        } header: {
            Label("Шрифт", systemImage: "character.textbox")
        } footer: {
            Text("Импортируйте .ttf/.otf и примените ко всему интерфейсу.")
        }
    }

    private var activeFontDisplayName: String {
        if let name = fontManager.activeFontName,
           let font = fontManager.installedFonts.first(where: { $0.postScriptName == name }) {
            return font.displayName
        }
        return "Системный шрифт iOS"
    }

    private var textScaleSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "textformat.size.smaller")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Slider(
                        value: $customization.textScale,
                        in: 0.7...1.5,
                        step: 0.05
                    )
                    Image(systemName: "textformat.size.larger")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }

                HStack {
                    Text("Масштаб текста")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                    Text("\(Int(customization.textScale * 100))%")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(customization.textScale == 1.0 ? .secondary : Theme.Colors.accent)
                    if customization.textScale != 1.0 {
                        Button("Сброс") {
                            withAnimation(.spring(response: 0.3)) {
                                customization.resetTextScale()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Label("Масштаб текста", systemImage: "textformat.size")
        } footer: {
            Text("Изменяет размер всех текстов интерфейса. Применяется сразу на всех экранах.")
        }
    }

    private var providerSection: some View {
        Section {
            ForEach(AIProvider.allCases) { provider in
                Button(action: { settings.switchProvider(provider) }) {
                    HStack {
                        providerIcon(provider)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.displayName)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            Text("\(provider.models.count) models")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if settings.selectedProvider == provider {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.Colors.accent)
                        }
                    }
                }
            }
        } header: {
            Text("Provider")
        } footer: {
            Text("Each provider uses its own API key stored securely in Keychain.")
        }
    }

    private var modelSection: some View {
        Section("Model") {
            Picker("Model", selection: $settings.selectedModel) {
                ForEach(settings.selectedProvider.models) { model in
                    Text(model.name)
                        .tag(model)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var apiKeySection: some View {
        Section {
            HStack {
                Group {
                    if isAPIKeyVisible {
                        TextField(texts.text("placeholder.apiKey"), text: $settings.apiKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField(texts.text("placeholder.apiKey"), text: $settings.apiKey)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Spacer(minLength: 8)

                Button {
                    withAnimation { isAPIKeyVisible.toggle() }
                } label: {
                    Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        } header: {
            HStack {
                Text("\(settings.selectedProvider.displayName) API Key")
                Spacer()
                if !settings.apiKey.isEmpty {
                    Button(texts.text("button.clearAPIKey")) {
                        settings.apiKey = ""
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stored securely in iOS Keychain. Never sent anywhere except directly to \(settings.selectedProvider.displayName).")
                Link("Get an API key →", destination: apiKeyURL)
                    .font(.footnote)
            }
        }
    }

    private var statusSection: some View {
        Section("Status") {
            HStack(spacing: 10) {
                Image(systemName: settings.isConfigured
                      ? "checkmark.circle.fill"
                      : "exclamationmark.circle.fill")
                    .foregroundColor(settings.isConfigured ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.isConfigured
                         ? texts.text("hint.statusReady")
                         : texts.text("hint.statusMissingKey"))
                        .fontWeight(.medium)
                    Text(settings.isConfigured
                         ? "\(settings.selectedProvider.displayName) · \(settings.selectedModel.name)"
                         : texts.text("hint.statusMissingKeyDetail"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Toast

    private var toastView: some View {
        Label("Copied!", systemImage: "doc.on.doc.fill")
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
    }

    // MARK: Helpers

    private var apiKeyURL: URL {
        switch settings.selectedProvider {
        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")!
        case .gemini:
            return URL(string: "https://aistudio.google.com/apikey")!
        case .openRouter:
            return URL(string: "https://openrouter.ai/keys")!
        }
    }

    @ViewBuilder
    private func providerIcon(_ provider: AIProvider) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(iconBackground(provider))
            Image(systemName: iconName(provider))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func iconBackground(_ provider: AIProvider) -> Color {
        switch provider {
        case .openAI:     return Color(red: 0.07, green: 0.68, blue: 0.42)
        case .anthropic:  return Color(red: 0.80, green: 0.35, blue: 0.14)
        case .gemini:     return Color(red: 0.26, green: 0.52, blue: 0.96)
        case .openRouter: return Color(red: 0.40, green: 0.20, blue: 0.90)
        }
    }

    private func iconName(_ provider: AIProvider) -> String {
        switch provider {
        case .openAI:     return "sparkles"
        case .anthropic:  return "brain.head.profile"
        case .gemini:     return "star.circle.fill"
        case .openRouter: return "arrow.triangle.branch"
        }
    }
}

#Preview {
    SettingsView()
}
