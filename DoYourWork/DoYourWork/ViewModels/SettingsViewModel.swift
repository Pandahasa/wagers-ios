import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var accountStatus: StripeAccountStatus?
    @Published var userStats: UserStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showOnboarding = false
    @Published var onboardingURL: URL?
    
    private let networkService = NetworkService.shared
    
    func loadAccountStatus() async {
        isLoading = true
        errorMessage = nil
        
        do {
            accountStatus = try await networkService.getStripeAccountStatus()
        } catch {
            errorMessage = "Failed to load payment status"
            print("Error loading Stripe account status: \(error)")
        }
        
        isLoading = false
    }
    
    func loadUserStats() async {
        do {
            let response = try await networkService.getUserStats()
            userStats = response.user
        } catch {
            print("Error loading user stats: \(error)")
        }
    }
    
    func startOnboarding() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await networkService.createStripeOnboardingLink()
            if let url = URL(string: response.url) {
                onboardingURL = url
                showOnboarding = true
            }
        } catch {
            errorMessage = "Failed to start payment setup"
            print("Error creating onboarding link: \(error)")
        }
        
        isLoading = false
    }
}
