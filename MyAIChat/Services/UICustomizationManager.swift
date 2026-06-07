//
//  UICustomizationManager.swift
//  MyAIChat
//
//  Stores all UI customization settings in UserDefaults.
//  Provides dynamic theme tokens that override the static Theme enum.
//

import SwiftUI
import Combine

// MARK: - Customizable Color wrapper

struct CustomColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(_ color: Color) {
        // Convert to sRGB explicitly to handle P3, grayscale, extended sRGB
        // and any other colorspace that UIColor might use.
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        if !uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            // getRed fails on non-RGB colorspaces — convert through sRGB
            let srgb = uiColor.cgColor.converted(
                to: CGColorSpace(name: CGColorSpace.sRGB)!,
                intent: .defaultIntent,
                options: nil
            )
            let comps = srgb?.components ?? [0, 0, 0, 1]
            r = comps.count > 0 ? comps[0] : 0
            g = comps.count > 1 ? comps[1] : 0
            b = comps.count > 2 ? comps[2] : 0
            a = comps.count > 3 ? comps[3] : 1
        }
        self.red     = Double(r)
        self.green   = Double(g)
        self.blue    = Double(b)
        self.opacity = Double(a)
    }

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red     = red
        self.green   = green
        self.blue    = blue
        self.opacity = opacity
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - Settings Structs

struct ButtonCustomization: Codable, Equatable {
    var backgroundColor: CustomColor
    var foregroundColor: CustomColor
    var opacity: Double
    var cornerRadius: Double
    var fontSize: Double
    var fontWeight: String     // "regular","medium","semibold","bold"
    var paddingH: Double
    var paddingV: Double
    var shadowRadius: Double
    var shadowOpacity: Double
    var strokeWidth: Double
    var strokeColor: CustomColor
    var liquidGlass: Bool

    static let `default` = ButtonCustomization(
        backgroundColor: CustomColor(red: 0.0, green: 0.478, blue: 1.0),
        foregroundColor: CustomColor(red: 1, green: 1, blue: 1),
        opacity: 1.0,
        cornerRadius: 17,
        fontSize: 16,
        fontWeight: "bold",
        paddingH: 14,
        paddingV: 10,
        shadowRadius: 4,
        shadowOpacity: 0.08,
        strokeWidth: 0,
        strokeColor: CustomColor(red: 1, green: 1, blue: 1, opacity: 0.5),
        liquidGlass: false
    )
}

struct InputFieldCustomization: Codable, Equatable {
    var backgroundColor: CustomColor
    var textColor: CustomColor
    var placeholderColor: CustomColor
    var opacity: Double
    var borderColor: CustomColor
    var borderWidth: Double
    var cornerRadius: Double
    var fontSize: Double
    var paddingH: Double
    var paddingV: Double
    var liquidGlass: Bool

    static let `default` = InputFieldCustomization(
        backgroundColor: CustomColor(red: 0.95, green: 0.95, blue: 0.97),
        textColor: CustomColor(red: 0, green: 0, blue: 0),
        placeholderColor: CustomColor(red: 0.6, green: 0.6, blue: 0.6),
        opacity: 1.0,
        borderColor: CustomColor(red: 0.78, green: 0.78, blue: 0.8),
        borderWidth: 1.0,
        cornerRadius: 20,
        fontSize: 16,
        paddingH: 12,
        paddingV: 10,
        liquidGlass: false
    )
}

struct TitleCustomization: Codable, Equatable {
    var color: CustomColor
    var opacity: Double
    var fontSize: Double
    var fontWeight: String

    static let `default` = TitleCustomization(
        color: CustomColor(red: 0, green: 0, blue: 0),
        opacity: 1.0,
        fontSize: 17,
        fontWeight: "semibold"
    )
}

struct BodyTextCustomization: Codable, Equatable {
    var color: CustomColor
    var opacity: Double
    var fontSize: Double
    var fontWeight: String
    var lineSpacing: Double

    static let `default` = BodyTextCustomization(
        color: CustomColor(red: 0, green: 0, blue: 0),
        opacity: 1.0,
        fontSize: 16,
        fontWeight: "regular",
        lineSpacing: 2
    )
}

struct MessageBubbleCustomization: Codable, Equatable {
    var userBubbleColor: CustomColor
    var userTextColor: CustomColor
    var assistantBubbleColor: CustomColor
    var assistantTextColor: CustomColor
    var opacity: Double
    var cornerRadius: Double
    var fontSize: Double
    var paddingH: Double
    var paddingV: Double
    var shadowRadius: Double
    var shadowOpacity: Double
    var avatarSize: Double
    var strokeWidth: Double
    var strokeColor: CustomColor
    var liquidGlass: Bool

    static let `default` = MessageBubbleCustomization(
        userBubbleColor: CustomColor(red: 0.0, green: 0.478, blue: 1.0),
        userTextColor: CustomColor(red: 1, green: 1, blue: 1),
        assistantBubbleColor: CustomColor(red: 0.95, green: 0.95, blue: 0.97),
        assistantTextColor: CustomColor(red: 0, green: 0, blue: 0),
        opacity: 1.0,
        cornerRadius: 18,
        fontSize: 16,
        paddingH: 12,
        paddingV: 10,
        shadowRadius: 4,
        shadowOpacity: 0.08,
        avatarSize: 28,
        strokeWidth: 0,
        strokeColor: CustomColor(red: 1, green: 1, blue: 1, opacity: 0.4),
        liquidGlass: false
    )
}

struct PanelCustomization: Codable, Equatable {
    var backgroundColor: CustomColor
    var separatorColor: CustomColor
    var inputBarBackground: CustomColor
    var opacity: Double
    var inputBarBlur: Bool
    var liquidGlass: Bool

    static let `default` = PanelCustomization(
        backgroundColor: CustomColor(red: 1, green: 1, blue: 1),
        separatorColor: CustomColor(red: 0.78, green: 0.78, blue: 0.8),
        inputBarBackground: CustomColor(red: 1, green: 1, blue: 1),
        opacity: 1.0,
        inputBarBlur: false,
        liquidGlass: false
    )
}

// MARK: - Manager

@MainActor
final class UICustomizationManager: ObservableObject {

    static let shared = UICustomizationManager()

    // MARK: Published settings

    @Published var button: ButtonCustomization      { didSet { save(\button,    key: .button) } }
    @Published var inputField: InputFieldCustomization { didSet { save(\inputField, key: .inputField) } }
    @Published var title: TitleCustomization        { didSet { save(\title,     key: .title) } }
    @Published var bodyText: BodyTextCustomization  { didSet { save(\bodyText,  key: .bodyText) } }
    @Published var messageBubble: MessageBubbleCustomization { didSet { save(\messageBubble, key: .messageBubble) } }
    @Published var panel: PanelCustomization        { didSet { save(\panel,     key: .panel) } }

    /// Global text scale multiplier. 1.0 = default, 0.7 = min, 1.5 = max.
    @Published var textScale: Double {
        didSet {
            UserDefaults.standard.set(textScale, forKey: Keys.textScale.rawValue)
        }
    }

    // MARK: Text scale helper

    /// Returns `baseSize` multiplied by the current global `textScale`.
    func scaled(_ baseSize: Double) -> Double {
        baseSize * textScale
    }

    // MARK: Font builder

    /// Returns the correct SwiftUI Font for the given base size and weight string,
    /// applying both the global text scale and the active custom font (if any).
    func appFont(size baseSize: Double, weight: String = "regular") -> Font {
        let finalSize = scaled(baseSize)
        return FontManager.shared.font(size: finalSize, weightString: weight)
    }

    /// Variant accepting Font.Weight directly.
    func appFont(size baseSize: Double, weight: Font.Weight) -> Font {
        let finalSize = scaled(baseSize)
        return FontManager.shared.font(size: finalSize, weight: weight)
    }

    // MARK: Init

    private init() {
        button       = Self.load(key: .button)       ?? .default
        inputField   = Self.load(key: .inputField)   ?? .default
        title        = Self.load(key: .title)        ?? .default
        bodyText     = Self.load(key: .bodyText)     ?? .default
        messageBubble = Self.load(key: .messageBubble) ?? .default
        panel        = Self.load(key: .panel)        ?? .default

        let saved = UserDefaults.standard.double(forKey: Keys.textScale.rawValue)
        textScale = saved > 0 ? saved : 1.0
    }

    // MARK: Reset

    func resetAll() {
        button        = .default
        inputField    = .default
        title         = .default
        bodyText      = .default
        messageBubble = .default
        panel         = .default
        textScale     = 1.0
    }

    func resetTextScale() { textScale = 1.0 }

    func resetButton()       { button = .default }
    func resetInputField()   { inputField = .default }
    func resetTitle()        { title = .default }
    func resetBodyText()     { bodyText = .default }
    func resetMessageBubble(){ messageBubble = .default }
    func resetPanel()        { panel = .default }

    // MARK: Persistence

    private enum Keys: String {
        case button        = "ui.customization.button"
        case inputField    = "ui.customization.inputField"
        case title         = "ui.customization.title"
        case bodyText      = "ui.customization.bodyText"
        case messageBubble = "ui.customization.messageBubble"
        case panel         = "ui.customization.panel"
        case textScale     = "ui.customization.textScale"
    }

    private func save<T: Encodable>(_ keyPath: KeyPath<UICustomizationManager, T>, key: Keys) {
        let value = self[keyPath: keyPath]
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key.rawValue)
        }
    }

    private static func load<T: Decodable>(key: Keys) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Font weight helpers

extension String {
    var swiftUIFontWeight: Font.Weight {
        switch self {
        case "ultralight":  return .ultraLight
        case "thin":        return .thin
        case "light":       return .light
        case "regular":     return .regular
        case "medium":      return .medium
        case "semibold":    return .semibold
        case "bold":        return .bold
        case "heavy":       return .heavy
        case "black":       return .black
        default:            return .regular
        }
    }
}
