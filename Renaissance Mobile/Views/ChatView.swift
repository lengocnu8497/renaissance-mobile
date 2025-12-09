//
//  ChatView.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//

import SwiftUI
import PhotosUI

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showImagePicker = false

    var initialMessage: String?
    var onBackButtonTapped: (() -> Void)?

    init(initialMessage: String? = nil, onBackButtonTapped: (() -> Void)? = nil) {
        self.initialMessage = initialMessage
        self.onBackButtonTapped = onBackButtonTapped
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            messagesList
            disclaimer
            messageInput
        }
        .navigationBarHidden(true)
        .onAppear {
            handleInitialMessage()
        }
    }

    // MARK: - Initial Message Handler
    private func handleInitialMessage() {
        guard let initialMessage = initialMessage, !initialMessage.isEmpty else { return }

        // Auto-send the initial message through the ViewModel
        Task {
            await viewModel.sendMessage(initialMessage)
        }
    }

    // MARK: - Actions
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedImageData != nil else { return }

        // Clear the input fields
        let imageData = selectedImageData
        messageText = ""
        selectedImageData = nil
        selectedImage = nil

        // Send message through ViewModel
        Task {
            await viewModel.sendMessage(text.isEmpty ? "What do you think about this photo?" : text, imageData: imageData)
        }
    }

    // MARK: - Subviews
    private var chatHeader: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                Button(action: {
                    if let onBackButtonTapped = onBackButtonTapped {
                        onBackButtonTapped()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Theme.Colors.textChatPrimary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Your Concierge")
                        .font(Theme.Typography.chatHeader)
                        .foregroundColor(Theme.Colors.textChatPrimary)

                    Text("Online")
                        .font(Theme.Typography.statusText)
                        .foregroundColor(Theme.Colors.online)
                }

                Spacer()

                // Spacer for symmetry
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Colors.backgroundChat)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    dateDivider

                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    if viewModel.isTyping {
                        TypingIndicatorView()
                            .id("typing")
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
                .onChange(of: viewModel.messages.count) { _, _ in
                    // Auto-scroll to the latest message
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isTyping) { _, isTyping in
                    // Auto-scroll when typing indicator appears
                    if isTyping {
                        withAnimation {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }
            .background(Theme.Colors.backgroundChat)
        }
    }

    private var dateDivider: some View {
        Text("Today")
            .font(Theme.Typography.dateDivider)
            .foregroundColor(Theme.Colors.textChatSecondary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(Theme.CornerRadius.medium)
            .padding(.top, Theme.Spacing.lg)
    }

    private var disclaimer: some View {
        Text("AI can make mistakes. Always consult with a board-certified plastic surgeon for medical advice.")
            .font(.caption2)
            .foregroundColor(Theme.Colors.textChatSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.backgroundChat)
    }

    private var messageInput: some View {
        VStack(spacing: 0) {
            // Error message banner
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Color.orange.opacity(0.1))
            }

            // Image preview
            if let imageData = selectedImageData,
               let uiImage = UIImage(data: imageData) {
                HStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                        .overlay(
                            Button(action: {
                                selectedImageData = nil
                                selectedImage = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .offset(x: 5, y: -5),
                            alignment: .topTrailing
                        )
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.backgroundChat)
            }

            HStack(spacing: Theme.Spacing.md) {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: Theme.IconSize.medium))
                        .foregroundColor(Theme.Colors.textChatSecondary)
                }
                .onChange(of: selectedImage) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        }
                    }
                }

                HStack {
                    TextField("Type your message...", text: $messageText)
                        .font(Theme.Typography.inputText)
                        .foregroundColor(Theme.Colors.textChatPrimary)
                        .disabled(viewModel.isLoading)
                        .onSubmit {
                            sendMessage()
                        }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Theme.Colors.inputBackground)
                .cornerRadius(Theme.CornerRadius.xlarge)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.xlarge)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .frame(width: 48, height: 48)
                        .background((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil) ? Color.gray.opacity(0.3) : Theme.Colors.primaryChat)
                        .clipShape(Circle())
                }
                .disabled((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil) || viewModel.isLoading)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.backgroundChat)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.2)),
                alignment: .top
            )
        }
    }

}

#Preview {
    ChatView()
}
