import SwiftUI

/// Alternative CreateWagerViewModel that uses StripeAPIService (no SDK required)
class CreateWagerViewModelAlt: ObservableObject {
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
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let deadlineString = formatter.string(from: deadline)
            
            let response = try await NetworkService.shared.createWager(
                taskDescription: taskDescription,
                wagerAmount: amount,
                deadline: deadlineString,
                refereeId: refereeId
            )
            
            // Confirm the payment with Stripe using the API service (no SDK needed)
            print("Confirming payment with Stripe API...")
            let paymentConfirmed = try await StripeAPIService.shared.confirmPayment(clientSecret: response.client_secret)
            
            if paymentConfirmed {
                await MainActor.run {
                    self.successMessage = "Wager created and payment authorized!"
                    self.isLoading = false
                    // Reset form
                    self.taskDescription = ""
                    self.wagerAmount = ""
                    self.deadline = Date().addingTimeInterval(86400)
                    self.selectedFriendId = nil
                }
            } else {
                throw NSError(domain: "StripeAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Payment confirmation failed"])
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create wager: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
