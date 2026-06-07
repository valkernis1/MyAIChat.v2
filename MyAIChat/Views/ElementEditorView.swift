//
//  ElementEditorView.swift
//  MyAIChat
//
//  Bottom sheet editor for the selected UI element.
//  Shows live preview + configuration controls.
//  Supports: colour, opacity, corner radius, size, stroke width/colour, Liquid Glass.
//

import SwiftUI

struct ElementEditorView: View {
    let element: EditableElement
    @ObservedObject private var customization = UICustomizationManager.shared
    @ObservedObject private var fontManager   = FontManager.shared
    @ObservedObject private var editing       = UIEditingManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                liquidGlassSection
                controlsSection
            }
            .navigationTitle(element.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Сброс", role: .destructive) { resetElement() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        editing.showEditorSheet = false
                        editing.selectedElement = nil
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Preview

    @ViewBuilder
    private var previewSection: some View {
        Section("Предпросмотр") {
            Group {
                switch element {
                case .button:        buttonPreview
                case .inputField:    inputFieldPreview
                case .title:         titlePreview
                case .bodyText:      bodyTextPreview
                case .messageBubble: messageBubblePreview
                case .panel:         panelPreview
                case .textLabels:    textLabelsPreview
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .animation(.easeInOut(duration: 0.2), value: customization.button)
            .animation(.easeInOut(duration: 0.2), value: customization.inputField)
            .animation(.easeInOut(duration: 0.2), value: customization.messageBubble)
            .animation(.easeInOut(duration: 0.2), value: customization.panel)
        }
    }

    // MARK: Liquid Glass section (global for every element)

    @ViewBuilder
    private var liquidGlassSection: some View {
        Section {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.7), .white.opacity(0.2)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ), lineWidth: 1)
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .purple, .pink],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Liquid Glass")
                        .font(.subheadline.weight(.semibold))
                    Text("Матовое стекло с бликами и переливами")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: liquidGlassBinding)
                    .labelsHidden()
            }
        } header: {
            Text("Стиль Liquid Glass")
        } footer: {
            Text("При включении поверх элемента накладывается эффект матового стекла. Остальные настройки фона при этом отходят на второй план.")
        }
    }

    private var liquidGlassBinding: Binding<Bool> {
        switch element {
        case .button:        return $customization.button.liquidGlass
        case .inputField:    return $customization.inputField.liquidGlass
        case .title:         return Binding(get: { false }, set: { _ in })  // text only
        case .bodyText:      return Binding(get: { false }, set: { _ in })
        case .messageBubble: return $customization.messageBubble.liquidGlass
        case .panel:         return $customization.panel.liquidGlass
        case .textLabels:    return Binding(get: { false }, set: { _ in })
        }
    }

    // MARK: Text labels preview (placeholder — edited in TextEditorView)

    private var textLabelsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Тексты интерфейса редактируются")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            Text("в разделе «Тексты интерфейса» — откройте его из списка элементов.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Button preview

    private var buttonPreview: some View {
        let c = customization.button
        let base = Text("Отправить")
            .font(customization.appFont(size: c.fontSize, weight: c.fontWeight))
            .foregroundColor(c.foregroundColor.swiftUIColor)
            .padding(.horizontal, c.paddingH)
            .padding(.vertical, c.paddingV)

        return Group {
            if c.liquidGlass {
                base
                    .liquidGlass(cornerRadius: c.cornerRadius)
                    .opacity(c.opacity)
            } else {
                base
                    .background(
                        RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous)
                            .fill(c.backgroundColor.swiftUIColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous)
                                    .stroke(c.strokeColor.swiftUIColor, lineWidth: c.strokeWidth)
                            )
                    )
                    .opacity(c.opacity)
                    .shadow(color: .black.opacity(c.shadowOpacity), radius: c.shadowRadius, x: 0, y: 2)
            }
        }
    }

    // MARK: Input field preview

    private var inputFieldPreview: some View {
        let c = customization.inputField
        let base = Text("Введите сообщение…")
            .font(customization.appFont(size: c.fontSize))
            .foregroundColor(c.placeholderColor.swiftUIColor)
            .padding(.horizontal, c.paddingH)
            .padding(.vertical, c.paddingV)
            .frame(maxWidth: .infinity, alignment: .leading)

        return Group {
            if c.liquidGlass {
                base
                    .liquidGlass(cornerRadius: c.cornerRadius)
                    .opacity(c.opacity)
            } else {
                base
                    .background(
                        RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous)
                            .fill(c.backgroundColor.swiftUIColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous)
                                    .stroke(c.borderColor.swiftUIColor, lineWidth: c.borderWidth)
                            )
                    )
                    .opacity(c.opacity)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Title preview

    private var titlePreview: some View {
        let c = customization.title
        return Text("Заголовок чата")
            .font(customization.appFont(size: c.fontSize, weight: c.fontWeight))
            .foregroundColor(c.color.swiftUIColor)
            .opacity(c.opacity)
    }

    // MARK: Body text preview

    private var bodyTextPreview: some View {
        let c = customization.bodyText
        return Text("Это пример текста сообщения. Здесь отображается обычный контент.")
            .font(customization.appFont(size: c.fontSize, weight: c.fontWeight))
            .foregroundColor(c.color.swiftUIColor)
            .lineSpacing(c.lineSpacing)
            .opacity(c.opacity)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
    }

    // MARK: Message bubble preview

    private var messageBubblePreview: some View {
        let c = customization.messageBubble
        return VStack(spacing: 8) {
            // Assistant bubble
            HStack(alignment: .bottom, spacing: 8) {
                Circle()
                    .fill(c.assistantBubbleColor.swiftUIColor)
                    .frame(width: c.avatarSize, height: c.avatarSize)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(c.assistantTextColor.swiftUIColor)
                    )
                bubbleView(text: "Привет! Чем могу помочь?",
                           bgColor: c.assistantBubbleColor.swiftUIColor,
                           textColor: c.assistantTextColor.swiftUIColor,
                           c: c)
                Spacer()
            }
            // User bubble
            HStack(alignment: .bottom, spacing: 8) {
                Spacer()
                bubbleView(text: "Привет!",
                           bgColor: c.userBubbleColor.swiftUIColor,
                           textColor: c.userTextColor.swiftUIColor,
                           c: c)
                Circle()
                    .fill(c.userBubbleColor.swiftUIColor)
                    .frame(width: c.avatarSize, height: c.avatarSize)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(c.userTextColor.swiftUIColor)
                    )
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func bubbleView(text: String,
                            bgColor: Color,
                            textColor: Color,
                            c: MessageBubbleCustomization) -> some View {
        let label = Text(text)
            .font(customization.appFont(size: c.fontSize))
            .foregroundColor(textColor)
            .padding(.horizontal, c.paddingH)
            .padding(.vertical, c.paddingV)

        if c.liquidGlass {
            label
                .liquidGlass(cornerRadius: c.cornerRadius)
                .opacity(c.opacity)
        } else {
            label
                .background(
                    RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous)
                        .fill(bgColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous)
                                .stroke(c.strokeColor.swiftUIColor, lineWidth: c.strokeWidth)
                        )
                )
                .opacity(c.opacity)
                .shadow(color: .black.opacity(c.shadowOpacity),
                        radius: c.shadowRadius, x: 0, y: 1)
        }
    }

    // MARK: Panel preview

    private var panelPreview: some View {
        let c = customization.panel
        return VStack(spacing: 0) {
            Rectangle()
                .fill(c.backgroundColor.swiftUIColor)
                .frame(height: 44)
                .overlay(
                    Text("Панель навигации")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                )
            Rectangle()
                .fill(c.separatorColor.swiftUIColor)
                .frame(height: 0.5)
            Rectangle()
                .fill(c.inputBarBackground.swiftUIColor)
                .frame(height: 52)
                .overlay(
                    Text("Панель ввода")
                        .font(.caption)
                        .foregroundColor(.secondary)
                )
        }
        .opacity(c.opacity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 4)
        .padding(.horizontal, 16)
    }

    // MARK: Controls router

    @ViewBuilder
    private var controlsSection: some View {
        switch element {
        case .button:        buttonControls
        case .inputField:    inputFieldControls
        case .title:         titleControls
        case .bodyText:      bodyTextControls
        case .messageBubble: messageBubbleControls
        case .panel:         panelControls
        case .textLabels:    EmptyView() // Text labels edited in TextEditorView, not here
        }
    }

    // MARK: Button controls

    private var buttonControls: some View {
        Group {
            Section("Цвета") {
                ColorPickerRow(label: "Фон кнопки",        customColor: $customization.button.backgroundColor)
                ColorPickerRow(label: "Цвет текста/иконки", customColor: $customization.button.foregroundColor)
            }
            Section("Прозрачность") {
                SliderRow(label: "Прозрачность элемента",
                          value: $customization.button.opacity,
                          range: 0...1, step: 0.01)
            }
            Section("Форма и размер") {
                SliderRow(label: "Скругление углов", value: $customization.button.cornerRadius,
                          range: 0...30, step: 1, unit: "pt")
                SliderRow(label: "Размер шрифта",    value: $customization.button.fontSize,
                          range: 10...28, step: 1, unit: "pt")
                FontWeightPickerRow(label: "Жирность", weight: $customization.button.fontWeight)
            }
            Section("Обводка") {
                SliderRow(label: "Толщина обводки", value: $customization.button.strokeWidth,
                          range: 0...8, step: 0.5, unit: "pt")
                ColorPickerRow(label: "Цвет обводки", customColor: $customization.button.strokeColor)
            }
            Section("Отступы") {
                SliderRow(label: "Горизонтальный", value: $customization.button.paddingH,
                          range: 4...32, step: 1, unit: "pt")
                SliderRow(label: "Вертикальный",   value: $customization.button.paddingV,
                          range: 4...24, step: 1, unit: "pt")
            }
            Section("Тень") {
                SliderRow(label: "Радиус тени",  value: $customization.button.shadowRadius,
                          range: 0...20, step: 0.5, unit: "pt")
                SliderRow(label: "Прозрачность", value: $customization.button.shadowOpacity,
                          range: 0...1, step: 0.01)
            }
        }
    }

    // MARK: Input field controls

    private var inputFieldControls: some View {
        Group {
            Section("Цвета") {
                ColorPickerRow(label: "Фон поля",    customColor: $customization.inputField.backgroundColor)
                ColorPickerRow(label: "Цвет текста", customColor: $customization.inputField.textColor)
                ColorPickerRow(label: "Placeholder", customColor: $customization.inputField.placeholderColor)
            }
            Section("Прозрачность") {
                SliderRow(label: "Прозрачность элемента",
                          value: $customization.inputField.opacity,
                          range: 0...1, step: 0.01)
            }
            Section("Форма и размер") {
                SliderRow(label: "Скругление углов", value: $customization.inputField.cornerRadius,
                          range: 0...30, step: 1, unit: "pt")
                SliderRow(label: "Размер шрифта",    value: $customization.inputField.fontSize,
                          range: 12...24, step: 1, unit: "pt")
            }
            Section("Обводка") {
                SliderRow(label: "Толщина обводки", value: $customization.inputField.borderWidth,
                          range: 0...6, step: 0.5, unit: "pt")
                ColorPickerRow(label: "Цвет обводки", customColor: $customization.inputField.borderColor)
            }
            Section("Отступы") {
                SliderRow(label: "Горизонтальный", value: $customization.inputField.paddingH,
                          range: 4...32, step: 1, unit: "pt")
                SliderRow(label: "Вертикальный",   value: $customization.inputField.paddingV,
                          range: 4...20, step: 1, unit: "pt")
            }
        }
    }

    // MARK: Title controls

    private var titleControls: some View {
        Group {
            Section("Стиль") {
                ColorPickerRow(label: "Цвет заголовка", customColor: $customization.title.color)
                SliderRow(label: "Прозрачность", value: $customization.title.opacity,
                          range: 0...1, step: 0.01)
                SliderRow(label: "Размер шрифта", value: $customization.title.fontSize,
                          range: 14...30, step: 1, unit: "pt")
                FontWeightPickerRow(label: "Жирность", weight: $customization.title.fontWeight)
            }
        }
    }

    // MARK: Body text controls

    private var bodyTextControls: some View {
        Group {
            Section("Стиль") {
                ColorPickerRow(label: "Цвет текста", customColor: $customization.bodyText.color)
                SliderRow(label: "Прозрачность", value: $customization.bodyText.opacity,
                          range: 0...1, step: 0.01)
                SliderRow(label: "Размер шрифта", value: $customization.bodyText.fontSize,
                          range: 12...24, step: 1, unit: "pt")
                FontWeightPickerRow(label: "Жирность", weight: $customization.bodyText.fontWeight)
                SliderRow(label: "Межстрочный интервал", value: $customization.bodyText.lineSpacing,
                          range: 0...12, step: 0.5, unit: "pt")
            }
        }
    }

    // MARK: Message bubble controls

    private var messageBubbleControls: some View {
        Group {
            Section("Пользователь") {
                ColorPickerRow(label: "Фон пузыря",  customColor: $customization.messageBubble.userBubbleColor)
                ColorPickerRow(label: "Цвет текста", customColor: $customization.messageBubble.userTextColor)
            }
            Section("Ассистент") {
                ColorPickerRow(label: "Фон пузыря",  customColor: $customization.messageBubble.assistantBubbleColor)
                ColorPickerRow(label: "Цвет текста", customColor: $customization.messageBubble.assistantTextColor)
            }
            Section("Прозрачность") {
                SliderRow(label: "Прозрачность пузырей",
                          value: $customization.messageBubble.opacity,
                          range: 0...1, step: 0.01)
            }
            Section("Форма и размер") {
                SliderRow(label: "Скругление углов", value: $customization.messageBubble.cornerRadius,
                          range: 0...30, step: 1, unit: "pt")
                SliderRow(label: "Размер шрифта",    value: $customization.messageBubble.fontSize,
                          range: 12...24, step: 1, unit: "pt")
                SliderRow(label: "Размер аватара",   value: $customization.messageBubble.avatarSize,
                          range: 20...48, step: 2, unit: "pt")
            }
            Section("Обводка") {
                SliderRow(label: "Толщина обводки", value: $customization.messageBubble.strokeWidth,
                          range: 0...6, step: 0.5, unit: "pt")
                ColorPickerRow(label: "Цвет обводки", customColor: $customization.messageBubble.strokeColor)
            }
            Section("Отступы") {
                SliderRow(label: "Горизонтальный", value: $customization.messageBubble.paddingH,
                          range: 4...32, step: 1, unit: "pt")
                SliderRow(label: "Вертикальный",   value: $customization.messageBubble.paddingV,
                          range: 4...20, step: 1, unit: "pt")
            }
            Section("Тень") {
                SliderRow(label: "Радиус тени",  value: $customization.messageBubble.shadowRadius,
                          range: 0...20, step: 0.5, unit: "pt")
                SliderRow(label: "Прозрачность", value: $customization.messageBubble.shadowOpacity,
                          range: 0...1, step: 0.01)
            }
        }
    }

    // MARK: Panel controls

    private var panelControls: some View {
        Group {
            Section("Цвета") {
                ColorPickerRow(label: "Фон панелей",      customColor: $customization.panel.backgroundColor)
                ColorPickerRow(label: "Разделитель",       customColor: $customization.panel.separatorColor)
                ColorPickerRow(label: "Фон панели ввода", customColor: $customization.panel.inputBarBackground)
            }
            Section("Прозрачность") {
                SliderRow(label: "Прозрачность панелей",
                          value: $customization.panel.opacity,
                          range: 0...1, step: 0.01)
            }
            Section("Эффекты") {
                Toggle("Размытие панели ввода", isOn: $customization.panel.inputBarBlur)
            }
        }
    }

    // MARK: Reset

    private func resetElement() {
        switch element {
        case .button:        customization.resetButton()
        case .inputField:    customization.resetInputField()
        case .title:         customization.resetTitle()
        case .bodyText:      customization.resetBodyText()
        case .messageBubble: customization.resetMessageBubble()
        case .panel:         customization.resetPanel()
        case .textLabels:    break // Text labels reset from TextEditorView
        }
    }
}
