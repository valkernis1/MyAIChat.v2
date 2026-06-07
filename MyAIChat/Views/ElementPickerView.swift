//
//  ElementPickerView.swift
//  MyAIChat
//
//  Sheet shown when edit mode is active — lets the user
//  pick which UI element type to configure.
//

import SwiftUI

struct ElementPickerView: View {
    @ObservedObject private var editing       = UIEditingManager.shared
    @ObservedObject private var customization = UICustomizationManager.shared
    @ObservedObject private var textManager   = UITextManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Выберите элемент для настройки. Изменения применяются мгновенно.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section("Элементы интерфейса") {
                    ForEach(EditableElement.allCases) { element in
                        Button {
                            editing.selectElement(element)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(element.color.gradient)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: element.systemImage)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(element.rawValue)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                        if liquidGlassEnabled(element) {
                                            LiquidGlassBadge()
                                        }
                                        if element == .textLabels && hasModifiedTexts {
                                            ModifiedTextsBadge(count: modifiedTextsCount)
                                        }
                                    }
                                    Text(elementDescription(element))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        customization.resetAll()
                        textManager.resetAll()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Сбросить все настройки")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } footer: {
                    Text("Сброс восстановит стандартный вид и тексты всех элементов.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Редактор интерфейса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        editing.exitEditMode()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $editing.showEditorSheet) {
            if let element = editing.selectedElement {
                ElementEditorView(element: element)
            }
        }
        .sheet(isPresented: $editing.showTextEditor) {
            TextEditorView()
        }
    }

    // MARK: Helpers

    private func elementDescription(_ element: EditableElement) -> String {
        switch element {
        case .button:        return "Цвет, прозрачность, радиус, размер, обводка"
        case .inputField:    return "Фон, граница, шрифт, прозрачность, обводка"
        case .title:         return "Цвет, прозрачность, размер, жирность"
        case .bodyText:      return "Цвет, прозрачность, размер, интервал"
        case .messageBubble: return "Цвет, прозрачность, радиус, обводка, тень"
        case .panel:         return "Фон, прозрачность, разделитель, размытие"
        case .textLabels:    return "Заголовки, кнопки, подсказки, плейсхолдеры"
        }
    }

    private func liquidGlassEnabled(_ element: EditableElement) -> Bool {
        switch element {
        case .button:        return customization.button.liquidGlass
        case .inputField:    return customization.inputField.liquidGlass
        case .messageBubble: return customization.messageBubble.liquidGlass
        case .panel:         return customization.panel.liquidGlass
        default:             return false
        }
    }

    private var hasModifiedTexts: Bool { modifiedTextsCount > 0 }

    private var modifiedTextsCount: Int {
        textManager.entries.values.filter { $0.value != $0.defaultValue }.count
    }
}

// MARK: - Liquid Glass badge

private struct LiquidGlassBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text("Glass")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(
            LinearGradient(
                colors: [.cyan, .purple],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.cyan.opacity(0.6), .purple.opacity(0.6)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
    }
}

// MARK: - Modified texts badge

private struct ModifiedTextsBadge: View {
    let count: Int
    var body: some View {
        Text("\(count) изм.")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.indigo))
    }
}
