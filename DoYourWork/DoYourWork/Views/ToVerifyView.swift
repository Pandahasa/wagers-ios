import SwiftUI

struct ToVerifyView: View {
    @StateObject private var viewModel = ToVerifyViewModel()
    @State private var selectedWager: Wager?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading wagers to verify...")
                } else if viewModel.wagers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No wagers to verify")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Wagers you need to judge will appear here")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List(viewModel.wagers) { wager in
                        WagerCard(wager: wager)
                            .onTapGesture {
                                selectedWager = wager
                            }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("To Verify")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task { await viewModel.fetchWagers() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            .navigationDestination(item: $selectedWager) { wager in
                VerifyWagerView(wager: wager) { success in
                    Task {
                        await viewModel.verifyWager(wagerId: wager.id, success: success)
                        selectedWager = nil // Dismiss the detail view
                    }
                }
            }
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
                await viewModel.fetchWagers()
            }
        }
    }
}