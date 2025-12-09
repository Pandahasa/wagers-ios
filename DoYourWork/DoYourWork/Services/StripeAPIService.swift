import Foundation

/// Alternative Stripe service that uses Stripe's REST API directly
/// This avoids the need for the Stripe iOS SDK dependency
class StripeAPIService {
    static let shared = StripeAPIService()
    private let publishableKey = "pk_test_51SUP5Z17LAJNLkX4gWC6rh3ZyhDQSfGSjoVXykMtBfZVviObqmTzguxd6PZasxsTEQebX9r4yihAYOKY2ltJ0Meh00GzzYyw6N"
    
    private init() {}
    
    /// Confirms a PaymentIntent using Stripe's REST API with a test token
    /// - Parameter clientSecret: The client_secret returned from the backend
    /// - Returns: Result indicating success or failure
    func confirmPayment(clientSecret: String) async throws -> Bool {
        // Extract payment intent ID from client secret
        let components = clientSecret.components(separatedBy: "_secret_")
        guard components.count >= 1 else {
            throw StripeError.invalidClientSecret
        }
        let paymentIntentId = components[0]
        
        print("🔵 Confirming payment: \(paymentIntentId)")
        
        // Step 1: Create a token from test card using Stripe's token API
        let tokenUrl = URL(string: "https://api.stripe.com/v1/tokens")!
        var tokenRequest = URLRequest(url: tokenUrl)
        tokenRequest.httpMethod = "POST"
        tokenRequest.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create token with test card 4242424242424242
        let tokenBody = "card[number]=4242424242424242&card[exp_month]=12&card[exp_year]=34&card[cvc]=123"
        tokenRequest.httpBody = tokenBody.data(using: .utf8)
        
        let (tokenData, tokenResponse) = try await URLSession.shared.data(for: tokenRequest)
        
        guard let tokenHttpResponse = tokenResponse as? HTTPURLResponse,
              tokenHttpResponse.statusCode == 200 else {
            if let errorString = String(data: tokenData, encoding: .utf8) {
                print("❌ Token creation failed: \(errorString)")
            }
            throw StripeError.invalidResponse
        }
        
        // Extract token ID
        guard let tokenJson = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
              let tokenId = tokenJson["id"] as? String else {
            throw StripeError.invalidResponse
        }
        
        print("✅ Created token: \(tokenId)")
        
        // Step 2: Create payment method from token
        let pmUrl = URL(string: "https://api.stripe.com/v1/payment_methods")!
        var pmRequest = URLRequest(url: pmUrl)
        pmRequest.httpMethod = "POST"
        pmRequest.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        pmRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let pmBody = "type=card&card[token]=\(tokenId)"
        pmRequest.httpBody = pmBody.data(using: .utf8)
        
        let (pmData, pmResponse) = try await URLSession.shared.data(for: pmRequest)
        
        guard let pmHttpResponse = pmResponse as? HTTPURLResponse,
              pmHttpResponse.statusCode == 200 else {
            if let errorString = String(data: pmData, encoding: .utf8) {
                print("❌ Payment method creation failed: \(errorString)")
            }
            throw StripeError.invalidResponse
        }
        
        // Extract payment method ID
        guard let pmJson = try? JSONSerialization.jsonObject(with: pmData) as? [String: Any],
              let paymentMethodId = pmJson["id"] as? String else {
            throw StripeError.invalidResponse
        }
        
        print("✅ Created payment method: \(paymentMethodId)")
        
        // Step 3: Confirm the payment intent with the payment method
        let url = URL(string: "https://api.stripe.com/v1/payment_intents/\(paymentIntentId)/confirm")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Body parameters - include payment method
        let bodyString = "payment_method=\(paymentMethodId)"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StripeError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            // Parse the response to check status
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                print("✅ Payment status: \(status)")
                return status == "requires_capture" || status == "succeeded"
            }
            return true
        } else {
            // Try to parse error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ Stripe error: \(message)")
                throw StripeError.apiError(message)
            }
            print("❌ Payment failed with status: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Response: \(errorString)")
            }
            throw StripeError.confirmationFailed(httpResponse.statusCode)
        }
    }
}

enum StripeError: LocalizedError {
    case invalidClientSecret
    case invalidResponse
    case confirmationFailed(Int)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidClientSecret:
            return "Invalid payment client secret"
        case .invalidResponse:
            return "Invalid response from Stripe"
        case .confirmationFailed(let code):
            return "Payment confirmation failed with code \(code)"
        case .apiError(let message):
            return "Stripe error: \(message)"
        }
    }
}
