import SwiftUI

@MainActor
class ToVerifyViewModel: ObservableObject {
    @Published var wagers: [Wager] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private var proofObserver: NSObjectProtocol?

    init() {
        // Listen for new proof uploads and refresh automatically
        proofObserver = NotificationCenter.default.addObserver(forName: .wagerProofUploaded, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.fetchWagers() }
        }
    }

    deinit {
        if let obs = proofObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func fetchWagers() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = ""
        }

        do {
            let response = try await NetworkService.shared.getPendingWagers()
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

    func verifyWager(wagerId: Int, success: Bool) async {
        do {
            let outcome = success ? "success" : "failure"
            let _ = try await NetworkService.shared.verifyWager(wagerId: wagerId, outcome: outcome)
            // Refresh the list after verification
            await fetchWagers()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to verify wager: \(error.localizedDescription)"
            }
        }
    }
}