//
//  ConversationListView.swift
//  MyAIChat
//
//  Sidebar / sheet showing all conversations with create, rename, delete.
//

import SwiftUI

struct ConversationListView: View {
    @ObservedObject var viewModel: ConversationListViewModel
    /// Called when the user taps a conversation row (used to close the sheet on iPhone).
    var onSelect: (() -> Void)?

    @State private var renameTarget: Conversation?
    @State private var renameText: String = ""
    @State private var showRenameAlert = false

    @ObservedObject private var texts = UITextManager.shared

    var body: some View {
        List {
            if viewModel.isEmpty {
                emptyPlaceholder
            } else {
                ForEach(viewModel.conversations) { conversation in
                    conversationRow(conversation)
                }
                .onDelete { offsets in
                    viewModel.deleteConversations(at: offsets)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(texts.text("title.conversationList"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.createConversation()
                    onSelect?()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel(texts.text("button.newChat"))
            }
        }
        // Rename alert
        .alert(texts.text("title.renameAlert"), isPresented: $showRenameAlert, actions: {
            TextField(texts.text("placeholder.chatName"), text: $renameText)
                .autocorrectionDisabled()
            Button(texts.text("button.renameSave")) {
                if let target = renameTarget {
                    viewModel.rename(target, to: renameText)
                }
            }
            Button(texts.text("button.renameCancel"), role: .cancel) {}
        }, message: {
            Text(texts.text("hint.renameMessage"))
        })
    }

    // MARK: Row

    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            viewModel.select(conversation)
            onSelect?()
        } label: {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(conversation.id == viewModel.selectedConversationID
                              ? Theme.Colors.accent
                              : Color(.tertiarySystemFill))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(conversation.id == viewModel.selectedConversationID
                                         ? .white
                                         : Theme.Colors.secondaryText)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let last = conversation.lastMessage {
                        Text(last.text)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)
                    } else {
                        Text(texts.text("hint.noMessages"))
                            .font(.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }

                Spacer()

                if conversation.id == viewModel.selectedConversationID {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.delete(conversation)
            } label: {
                Label(texts.text("button.swipeDelete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                renameTarget = conversation
                renameText = conversation.title
                showRenameAlert = true
            } label: {
                Label(texts.text("button.swipeRename"), systemImage: "pencil")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button {
                renameTarget = conversation
                renameText = conversation.title
                showRenameAlert = true
            } label: {
                Label(texts.text("button.swipeRename"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.delete(conversation)
            } label: {
                Label(texts.text("button.swipeDelete"), systemImage: "trash")
            }
        }
    }

    // MARK: Empty state

    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Theme.Colors.secondaryText)
            Text(texts.text("hint.noChatsYet"))
                .font(.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
            Button(texts.text("button.newChat")) {
                viewModel.createConversation()
                onSelect?()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    NavigationStack {
        ConversationListView(viewModel: ConversationListViewModel(persistence: .shared))
    }
}
