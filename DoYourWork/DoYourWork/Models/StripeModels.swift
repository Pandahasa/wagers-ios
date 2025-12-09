import Foundation

// Response from Stripe onboarding link creation
struct StripeOnboardingResponse: Codable {
    let url: String
}

// Response from Stripe account status check
struct StripeAccountStatus: Codable {
    let hasAccount: Bool
    let chargesEnabled: Bool?
    let payoutsEnabled: Bool?
    let detailsSubmitted: Bool?
}
