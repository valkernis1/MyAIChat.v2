//
//  MessageBubbleView.swift
//  MyAIChat
//
//  A single chat message bubble with full live customization support:
//  colour, opacity, corner radius, stroke, shadow, and Liquid Glass style.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    @ObservedObject private var customization = UICustomizationManager.shared
    @ObservedObject private var fontManager   = FontManager.shared
    @ObservedObject private var editing       = UIEditingManager.shared

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.small) {
            if message.isFromUser {
                Spacer(minLength: Theme.Spacing.xLarge)
            } else {
                avatar
            }

            bubbleContent

            if message.isFromUser {
                avatar
            } else {
                Spacer(minLength: Theme.Spacing.xLarge)
            }
        }
        .frame(maxWidth: .infinity,
               alignment: message.isFromUser ? .trailing : .leading)
    }

    // MARK: Bubble content

    @ViewBuilder
    private var bubbleContent: some View {
        let c = customization.messageBubble
        let label = Text(message.text)
            .textSelection(.enabled)
            .font(customization.appFont(size: c.fontSize,
                                             weight: customization.bodyText.fontWeight))
            .lineSpacing(customization.bodyText.lineSpacing)
            .foregroundColor(textColor)
            .padding(.vertical,   c.paddingV)
            .padding(.horizontal, c.paddingH)

        if c.liquidGlass {
            label
                .liquidGlass(cornerRadius: c.cornerRadius)
                .opacity(c.opacity)
                .overlay(editHighlight(for: .messageBubble))
                .onTapGesture { editing.tapElement(.messageBubble) }
        } else {
            label
                .background(bubbleBackground)
                .opacity(c.opacity)
                .shadow(color: .black.opacity(c.shadowOpacity),
                        radius: c.shadowRadius, x: 0, y: 1)
                .overlay(editHighlight(for: .messageBubble))
                .onTapGesture { editing.tapElement(.messageBubble) }
        }
    }

    // MARK: Subviews

    private var bubbleBackground: some View {
        let c = customization.messageBubble
        let bg: Color = message.isFromUser
            ? c.userBubbleColor.swiftUIColor
            : c.assistantBubbleColor.swiftUIColor
        return RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous)
            .fill(bg)
            .overlay(
                RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous)
                    .stroke(c.strokeColor.swiftUIColor, lineWidth: c.strokeWidth)
            )
    }

    private var avatar: some View {
        let c = customization.messageBubble
        let size = c.avatarSize
        return Image(systemName: message.isFromUser ? "person.fill" : "sparkles")
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundColor(message.isFromUser
                             ? c.userTextColor.swiftUIColor
                             : c.userBubbleColor.swiftUIColor)
            .frame(width: size, height: size)
            .background(
                Circle().fill(message.isFromUser
                              ? c.userBubbleColor.swiftUIColor
                              : c.assistantBubbleColor.swiftUIColor)
            )
    }

    private var textColor: Color {
        let c = customization.messageBubble
        return message.isFromUser
            ? c.userTextColor.swiftUIColor
            : c.assistantTextColor.swiftUIColor
    }
}

// MARK: - Edit highlight modifier

@ViewBuilder
func editHighlight(for element: EditableElement) -> some View {
    let editing = UIEditingManager.shared
    if editing.isEditingMode {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(
                editing.selectedElement == element
                    ? element.color
                    : element.color.opacity(0.35),
                style: StrokeStyle(lineWidth: editing.selectedElement == element ? 2.5 : 1.5,
                                   dash: [5, 3])
            )
            .animation(.easeInOut(duration: 0.2), value: editing.selectedElement)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Theme.Spacing.medium) {
            MessageBubbleView(message: .assistant("Hello! How can I help you today?"))
            MessageBubbleView(message: .user("Explain quantum computing in one sentence."))
            MessageBubbleView(message: .assistant("Quantum computing uses quantum bits that can be 0 and 1 at once, enabling certain problems to be solved far faster than classical computers."))
        }
        .padding()
    }
    .background(Theme.Colors.background)
}
