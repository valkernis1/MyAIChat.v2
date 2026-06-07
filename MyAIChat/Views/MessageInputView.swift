//
//  MessageInputView.swift
//  MyAIChat
//
//  Bottom input bar with full live customization:
//  colour, opacity, corner radius, stroke, shadow, and Liquid Glass style.
//

import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    var canSend: Bool = true
    var onSend: () -> Void

    @FocusState private var isFocused: Bool
    @ObservedObject private var customization = UICustomizationManager.shared
    @ObservedObject private var fontManager   = FontManager.shared
    @ObservedObject private var editing       = UIEditingManager.shared
    @ObservedObject private var texts         = UITextManager.shared

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.small) {
            inputField
            sendButton
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.vertical, Theme.Spacing.small)
        .background(panelBackground)
    }

    // MARK: Input field

    @ViewBuilder
    private var inputField: some View {
        let c = customization.inputField
        let field = TextField(texts.text("placeholder.messageInput"), text: $text, axis: .vertical)
            .lineLimit(1...5)
            .focused($isFocused)
            .font(customization.appFont(size: c.fontSize))
            .foregroundColor(c.textColor.swiftUIColor)
            .padding(.vertical,   c.paddingV)
            .padding(.horizontal, c.paddingH)

        if c.liquidGlass {
            field
                .liquidGlass(cornerRadius: c.cornerRadius)
                .opacity(c.opacity)
                .overlay(editHighlight(for: .inputField))
                .onTapGesture { editing.tapElement(.inputField) }
        } else {
            field
                .background(
                    RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous)
                        .fill(c.backgroundColor.swiftUIColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous)
                                .stroke(c.borderColor.swiftUIColor, lineWidth: c.borderWidth)
                        )
                )
                .opacity(c.opacity)
                .overlay(editHighlight(for: .inputField))
                .onTapGesture { editing.tapElement(.inputField) }
        }
    }

    // MARK: Send button

    @ViewBuilder
    private var sendButton: some View {
        let c = customization.button
        let icon = Image(systemName: "arrow.up")
            .font(customization.appFont(size: c.fontSize * 0.8, weight: c.fontWeight))
            .foregroundColor(c.foregroundColor.swiftUIColor)
            .frame(width: 34, height: 34)

        Button(action: submit) {
            if c.liquidGlass {
                icon
                    .liquidGlass(cornerRadius: 17)
                    .opacity(c.opacity)
            } else {
                icon
                    .background(
                        Circle().fill(canSend
                                      ? c.backgroundColor.swiftUIColor
                                      : Theme.Colors.secondaryText.opacity(0.35))
                            .overlay(
                                Circle().stroke(c.strokeColor.swiftUIColor, lineWidth: c.strokeWidth)
                            )
                    )
                    .opacity(canSend ? c.opacity : c.opacity * 0.5)
                    .shadow(color: .black.opacity(canSend ? c.shadowOpacity : 0),
                            radius: c.shadowRadius, x: 0, y: 1)
            }
        }
        .disabled(!canSend)
        .animation(.easeInOut(duration: 0.15), value: canSend)
        .overlay(editHighlight(for: .button))
        .onTapGesture { editing.tapElement(.button) }
    }

    // MARK: Panel background

    @ViewBuilder
    private var panelBackground: some View {
        let c = customization.panel
        if c.liquidGlass {
            Color.clear
                .liquidGlass(cornerRadius: 0, intensity: 0.7)
                .opacity(c.opacity)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(c.separatorColor.swiftUIColor)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
                .overlay(editHighlight(for: .panel))
                .onTapGesture { editing.tapElement(.panel) }
        } else if c.inputBarBlur {
            Color.clear
                .background(.regularMaterial)
                .opacity(c.opacity)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(c.separatorColor.swiftUIColor)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
                .overlay(editHighlight(for: .panel))
                .onTapGesture { editing.tapElement(.panel) }
        } else {
            c.inputBarBackground.swiftUIColor
                .opacity(c.opacity)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(c.separatorColor.swiftUIColor)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
                .overlay(editHighlight(for: .panel))
                .onTapGesture { editing.tapElement(.panel) }
        }
    }

    // MARK: Actions

    private func submit() {
        guard canSend else { return }
        onSend()
        isFocused = false
    }
}

#Preview {
    VStack {
        Spacer()
        MessageInputView(text: .constant("Hello"), canSend: true, onSend: {})
    }
    .background(Theme.Colors.background)
}
