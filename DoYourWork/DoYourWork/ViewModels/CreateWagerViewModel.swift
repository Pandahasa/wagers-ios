import SwiftUI

class CreateWagerViewModel: ObservableObject {
    @Published var taskDescription = ""
    @Published var wagerAmount = ""
    @Published var deadline = Date().addingTimeInterval(86400) // Tomorrow
    @Published var selectedFriendId: Int?
    @Published var friends: [User] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""

    func fetchFriends() async {
        // Fetch accepted friends from the server
        do {
            let response = try await NetworkService.shared.getFriends()
            await MainActor.run {
                self.friends = response.friends
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch friends: \(error.localizedDescription)"
            }
        }
    }

    func createWager() async {
        guard let refereeId = selectedFriendId,
              let amount = Double(wagerAmount),
              !taskDescription.isEmpty else {
            await MainActor.run { self.errorMessage = "Please fill in all fields and select a friend" }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = ""
            self.successMessage = ""
        }

        do {
            // Convert the selected deadline to UTC before sending
            // Use ISO8601 with fractional seconds to match server formatting
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let deadlineString = formatter.string(from: deadline)
            let response = try await NetworkService.shared.createWager(
                taskDescription: taskDescription,
                wagerAmount: amount,
                deadline: deadlineString,
                refereeId: refereeId
            )
            // The server returns a client_secret for the PaymentIntent; in a real app
            // the next step would be to call Stripe SDK to confirm the payment using this secret.
            // We'll print it for now so you can use it in testing.
            print("PaymentIntent client_secret:", response.client_secret)

            // TODO: Confirm payment with Stripe using client_secret
            // For now, just show success
            await MainActor.run {
                self.successMessage = "Wager created successfully!"
                self.isLoading = false
                // Reset form
                self.taskDescription = ""
                self.wagerAmount = ""
                self.deadline = Date().addingTimeInterval(86400)
                self.selectedFriendId = nil
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create wager: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}