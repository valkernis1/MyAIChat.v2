//
//  ChatView.swift
//  MyAIChat
//
//  Main chat screen with UI editing mode support.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var showSettings = false
    @ObservedObject private var customization = UICustomizationManager.shared
    @ObservedObject private var fontManager   = FontManager.shared
    @ObservedObject private var editing       = UIEditingManager.shared
    @ObservedObject private var texts         = UITextManager.shared
    @ObservedObject private var bgManager     = AppBackgroundManager.shared

    var body: some View {
        VStack(spacing: 0) {
            content
            MessageInputView(
                text: $viewModel.draft,
                canSend: viewModel.canSend,
                onSend: viewModel.send
            )
        }
        .background(
            bgManager.settings.type == .none
                ? customization.panel.backgroundColor.swiftUIColor.ignoresSafeArea()
                : Color.clear.ignoresSafeArea()
        )
        .navigationTitle(viewModel.conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    // Edit mode toggle
                    Button {
                        if editing.isEditingMode {
                            editing.exitEditMode()
                        } else {
                            editing.enterEditMode()
                        }
                    } label: {
                        Image(systemName: editing.isEditingMode
                              ? "paintbrush.fill"
                              : "paintbrush")
                            .foregroundColor(editing.isEditingMode ? .orange : .primary)
                    }
                    .accessibilityLabel("Редактор интерфейса")

                    Button(action: viewModel.clearConversation) {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(viewModel.messages.isEmpty)
                    .accessibilityLabel("Clear chat")
                }
            }
        }
        .alert("Something went wrong",
               isPresented: errorAlertPresented,
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(viewModel.errorMessage ?? "") })
        .sheet(isPresented: $showSettings) { SettingsView() }
        // Edit mode element picker
        .sheet(isPresented: $editing.showElementPicker) {
            ElementPickerView()
        }
        // Edit mode banner
        .safeAreaInset(edge: .top, spacing: 0) {
            if editing.isEditingMode {
                editModeBanner
            }
        }
    }

    // MARK: Edit mode banner

    private var editModeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "paintbrush.fill")
                .foregroundColor(.white)
                .font(.system(size: 13, weight: .semibold))
            Text(texts.text("hint.editModeBanner"))
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white)
            Spacer()
            Button(texts.text("button.editModeBanner")) {
                editing.showElementPicker = true
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.25)))

            Button {
                editing.exitEditMode()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.gradient)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: editing.isEditingMode)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if viewModel.messages.isEmpty && !viewModel.isSending {
            emptyState
        } else {
            messageList
        }
    }

    private var emptyState: some View {
        let tc = customization.title
        let bc = customization.bodyText
        return VStack(spacing: Theme.Spacing.medium) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 52, weight: .semibold))
                .foregroundColor(Theme.Colors.accent)
            Text(texts.text("title.emptyState"))
                .font(customization.appFont(size: tc.fontSize, weight: tc.fontWeight))
                .foregroundColor(tc.color.swiftUIColor)
                .multilineTextAlignment(.center)
                .overlay(editHighlight(for: .title))
                .onTapGesture { editing.tapElement(.title) }
            Text(texts.text("hint.emptyBody"))
                .font(customization.appFont(size: bc.fontSize, weight: bc.fontWeight))
                .foregroundColor(Theme.Colors.secondaryText)
                .overlay(editHighlight(for: .bodyText))
                .onTapGesture { editing.tapElement(.bodyText) }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xLarge)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.medium) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                    if viewModel.isSending && !(viewModel.messages.last?.text.isEmpty ?? true) {
                        TypingIndicatorView().id("typing")
                    }
                }
                .padding(.horizontal, Theme.Spacing.medium)
                .padding(.vertical, Theme.Spacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count)      { _ in scrollToBottom(proxy) }
            .onChange(of: viewModel.isSending)           { _ in scrollToBottom(proxy) }
            .onChange(of: viewModel.messages.last?.text) { _ in scrollToBottom(proxy) }
        }
    }

    private var errorAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            if let id = viewModel.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
        }
    }
}

// MARK: - TypingIndicatorView

private struct TypingIndicatorView: View {
    @State private var animating = false
    @ObservedObject private var customization = UICustomizationManager.shared

    var body: some View {
        let c = customization.messageBubble
        return HStack(alignment: .bottom, spacing: Theme.Spacing.small) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.accent)
                .frame(width: c.avatarSize, height: c.avatarSize)
                .background(Circle().fill(c.assistantBubbleColor.swiftUIColor))

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Theme.Colors.secondaryText)
                        .frame(width: 7, height: 7)
                        .opacity(animating ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.vertical, c.paddingV)
            .padding(.horizontal, c.paddingH)
            .background(
                RoundedRectangle(cornerRadius: c.cornerRadius, style: .continuous)
                    .fill(c.assistantBubbleColor.swiftUIColor)
            )
            Spacer(minLength: Theme.Spacing.xLarge)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animating = true }
    }
}

#Preview {
    NavigationStack {
        ChatView(viewModel: ChatViewModel(conversation: Conversation()))
    }
}
