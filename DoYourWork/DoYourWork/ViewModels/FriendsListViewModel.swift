import SwiftUI

@MainActor
class FriendsListViewModel: ObservableObject {
    @Published var friends: [User] = []
    @Published var pending: [PendingRequest] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    func fetchFriends() async {
        DispatchQueue.main.async { self.isLoading = true }
        do {
            let response = try await NetworkService.shared.getFriends()
            DispatchQueue.main.async {
                self.friends = response.friends
                self.isLoading = false
            }
            // Also fetch pending frend requests
            await fetchPending()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load friends: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func addFriend(email: String) async -> Bool {
        do {
            _ = try await NetworkService.shared.addFriend(email: email)
            await fetchFriends()
            return true
        } catch {
            DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
            return false
        }
    }

    func fetchPending() async {
        do {
            let response = try await NetworkService.shared.getPendingFriends()
            DispatchQueue.main.async { self.pending = response.pending }
        } catch {
            DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
        }
    }

    func respondToRequest(requesterId: Int, accept: Bool) async {
        do {
            _ = try await NetworkService.shared.respondToFriend(requesterId: requesterId, response: accept ? "accepted" : "rejected")
            await fetchFriends()
        } catch {
            DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
        }
    }
}
