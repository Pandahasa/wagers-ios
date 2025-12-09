import SwiftUI

@MainActor
class MyWagersViewModel: ObservableObject {
    @Published var wagers: [Wager] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    func fetchWagers() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = ""
        }

        do {
            let response = try await NetworkService.shared.getActiveWagers()
            DispatchQueue.main.async {
                self.wagers = response.wagers
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load wagers: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}