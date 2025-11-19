import SwiftUI

struct CreateWagerView: View {
    @StateObject private var viewModel = CreateWagerViewModel()
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Task Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What do you need to do?")
                                .font(.headline)
                            TextField("Enter your task...", text: $viewModel.taskDescription)
                                .textFieldStyle(.roundedBorder)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .submitLabel(.next)
                        }

                        // Wager Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How much is the wager?")
                                .font(.headline)
                            HStack {
                                Text("$")
                                    .font(.title)
                                    .foregroundColor(.green)
                                TextField("0.00", text: $viewModel.wagerAmount)
                                    .keyboardType(.decimalPad)
                                    .font(.title)
                                    .multilineTextAlignment(.leading)
                                    .submitLabel(.done)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }

                        // Deadline
                        VStack(alignment: .leading, spacing: 8) {
                            Text("When does it need to be done?")
                                .font(.headline)
                            DatePicker("Select deadline", selection: $viewModel.deadline, in: Date()...)
                                .datePickerStyle(.compact)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        }

                        // Friend Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Who will verify completion?")
                                .font(.headline)
                            if viewModel.friends.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("No friends yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Add someone in Settings > Friends and accept the request before you can choose them to verify a wager.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    NavigationLink("Add Friends", destination: FriendsListView())
                                }
                            } else {
                                Picker("Select a friend", selection: $viewModel.selectedFriendId) {
                                    Text("Choose a friend...").tag(nil as Int?)
                                    ForEach(viewModel.friends) { friend in
                                        Text(friend.username).tag(friend.id as Int?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                        }

                        // Create Button
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                        } else {
                            Button(action: {
                                Task {
                                    await viewModel.createWager()
                                }
                            }) {
                                Text("Create Wager")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(viewModel.taskDescription.isEmpty ||
                                     viewModel.wagerAmount.isEmpty ||
                                     viewModel.selectedFriendId == nil)
                            .opacity(viewModel.taskDescription.isEmpty ||
                                    viewModel.wagerAmount.isEmpty ||
                                    viewModel.selectedFriendId == nil ? 0.6 : 1.0)
                        }

                        // Success Message
                        if !viewModel.successMessage.isEmpty {
                            Text(viewModel.successMessage)
                                .font(.headline)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Wager")
            .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
                Button("OK") {
                    viewModel.errorMessage = ""
                }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchFriends()
            }
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .padding(.bottom, keyboardHeight)
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}