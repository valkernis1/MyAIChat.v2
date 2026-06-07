//
//  UIEditingManager.swift
//  MyAIChat
//
//  Controls global UI editing mode.
//  Tracks which element type is currently selected for editing.
//

import SwiftUI
import Combine

// MARK: - Editable element types

enum EditableElement: String, CaseIterable, Identifiable {
    case button        = "Кнопки"
    case inputField    = "Поле ввода"
    case title         = "Заголовки"
    case bodyText      = "Текст"
    case messageBubble = "Карточки сообщений"
    case panel         = "Панели"
    case textLabels    = "Тексты интерфейса"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .button:        return "rectangle.and.hand.point.up.left.fill"
        case .inputField:    return "text.cursor"
        case .title:         return "textformat.size"
        case .bodyText:      return "doc.text"
        case .messageBubble: return "bubble.left.and.bubble.right.fill"
        case .panel:         return "rectangle.split.3x1"
        case .textLabels:    return "character.cursor.ibeam"
        }
    }

    var color: Color {
        switch self {
        case .button:        return .blue
        case .inputField:    return .purple
        case .title:         return .orange
        case .bodyText:      return .green
        case .messageBubble: return .pink
        case .panel:         return .teal
        case .textLabels:    return .indigo
        }
    }
}

// MARK: - Manager

@MainActor
final class UIEditingManager: ObservableObject {

    static let shared = UIEditingManager()

    @Published var isEditingMode: Bool = false
    @Published var selectedElement: EditableElement? = nil
    @Published var showElementPicker: Bool = false
    @Published var showEditorSheet: Bool = false
    @Published var showTextEditor: Bool = false

    private init() {}

    // MARK: Actions

    func enterEditMode() {
        isEditingMode = true
        showElementPicker = true
    }

    func exitEditMode() {
        isEditingMode = false
        selectedElement = nil
        showElementPicker = false
        showEditorSheet = false
        showTextEditor = false
    }

    func selectElement(_ element: EditableElement) {
        if element == .textLabels {
            selectedElement = element
            showElementPicker = false
            showTextEditor = true
            return
        }
        selectedElement = element
        showElementPicker = false
        showEditorSheet = true
    }

    func tapElement(_ element: EditableElement) {
        guard isEditingMode else { return }
        selectElement(element)
    }
}
