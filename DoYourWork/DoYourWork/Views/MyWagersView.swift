import SwiftUI

struct MyWagersView: View {
    @StateObject private var viewModel = MyWagersViewModel()
    @State private var selectedWager: Wager?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading wagers...")
                } else if viewModel.wagers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No active wagers")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Create your first wager to get started!")
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
            .navigationTitle("My Wagers")
            .navigationDestination(item: $selectedWager) { wager in
                WagerDetailView(wager: wager, isReferee: false)
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

struct WagerCard: View {
    let wager: Wager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(wager.task_description)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text("$\(String(format: "%.2f", wager.wager_amount))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(wager.isExpired ? .red : .blue)
                Text(wager.timeRemaining)
                    .font(.subheadline)
                    .foregroundColor(wager.isExpired ? .red : .blue)
            }

            // Add formatted deadline for debugging
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.gray)
                Text(formatDateForCard(wager.deadlineDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Text("Status: \(wager.status.capitalized)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func formatDateForCard(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        
        return formatter.string(from: date)
    }
}