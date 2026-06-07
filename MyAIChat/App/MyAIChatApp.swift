//
//  MyAIChatApp.swift
//  MyAIChat
//
//  App entry point. Wires the conversation list with the chat screen.
//  - iPhone: NavigationStack + slide-up sidebar sheet
//  - iPad:   NavigationSplitView with persistent sidebar
//

import SwiftUI

@main
struct MyAIChatApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(UICustomizationManager.shared)
                .environmentObject(UIEditingManager.shared)
                .environmentObject(UITextManager.shared)
                .environmentObject(FontManager.shared)
                .environmentObject(AppBackgroundManager.shared)
                .environmentObject(UIPresetsManager.shared)
        }
    }
}

// MARK: - RootView

@MainActor
struct RootView: View {
    @StateObject private var listVM  = ConversationListViewModel()
    @StateObject private var chatVM  = ChatViewModel()

    @State private var showSidebar   = false

    var body: some View {
        ZStack {
            // Global background layer — rendered behind everything
            AppBackgroundView()

            // App UI layer — transparency controlled by uiOpacity setting
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    ipadLayout
                } else {
                    iphoneLayout
                }
            }
            .appUIOpacity()
        }
        .onAppear(perform: bootstrap)
        .onChange(of: listVM.selectedConversationID) { _ in
            activateSelectedConversation()
        }
    }

    // MARK: iPhone

    private var iphoneLayout: some View {
        NavigationStack {
            ChatView(viewModel: chatVM)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { showSidebar = true } label: {
                            Image(systemName: "sidebar.left")
                        }
                        .accessibilityLabel("Chats")
                    }
                }
        }
        .sheet(isPresented: $showSidebar) {
            NavigationStack {
                ConversationListView(viewModel: listVM) {
                    showSidebar = false
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: iPad

    private var ipadLayout: some View {
        NavigationSplitView {
            ConversationListView(viewModel: listVM)
        } detail: {
            NavigationStack {
                ChatView(viewModel: chatVM)
            }
        }
    }

    // MARK: Bootstrap

    private func bootstrap() {
        wireChatVM()

        if listVM.isEmpty {
            let conv = listVM.createConversation()
            load(conv)
        } else if let conv = listVM.selectedConversation {
            load(conv)
        }
    }

    private func load(_ conv: Conversation) {
        chatVM.conversation     = conv
        chatVM.draft            = ""
        chatVM.errorMessage     = nil
    }

    private func activateSelectedConversation() {
        guard let conv = listVM.selectedConversation else { return }
        load(conv)
    }

    private func wireChatVM() {
        chatVM.onConversationChanged = { [weak listVM] updated in
            listVM?.update(updated)
        }
    }
}
