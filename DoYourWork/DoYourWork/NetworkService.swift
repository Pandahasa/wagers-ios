import Foundation

struct LoginResponse: Codable {
    let token: String?
    let user: User?
    let error: String?
}

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
}

struct UserStats: Codable {
    let id: Int
    let username: String
    let email: String
    let successful_wagers_count: Int
}

struct UserStatsResponse: Codable {
    let user: UserStats
}

struct ErrorResponse: Codable {
    let error: String
}

class NetworkService {
    static let shared = NetworkService()
    #if targetEnvironment(simulator)
    /// Use localhost in Simulator so requests go to host machine
    private let baseURL = "http://localhost:3000/api"
    #else
    // If running on a device, use your machine's local IP (change as-needed)
    private let baseURL = "http://10.250.93.126:3000/api"
    #endif
    
    private init() {}
    
    init(debugLog: Bool = true) {
        // Explicit initializer for tests or to print debug info
        if debugLog {
            print("NetworkService baseURL: \(baseURL)")
        }
    }
    
    //This authenticates the user to the backend server
    func login(identifier: String, password: String) async throws -> LoginResponse {
        let body = ["identifier": identifier, "password": password]
        return try await request("/users/login", method: "POST", body: body)
    }
    
    //This registers a new user to the backend server
    func register(username: String, email: String, password: String) async throws -> LoginResponse {
        let body = ["username": username, "email": email, "password": password]
        return try await request("/users/register", method: "POST", body: body)
    }
    
    //This creates a new wager on the backend server
    func createWager(taskDescription: String, wagerAmount: Double, deadline: String, refereeId: Int) async throws -> CreateWagerResponse {
        let body = CreateWagerRequest(task_description: taskDescription, wager_amount: wagerAmount, deadline: deadline, referee_id: refereeId)
        return try await request("/wagers/create", method: "POST", body: body)
    }

    //This gets the list of friends from the backend server
    func getFriends() async throws -> FriendsResponse {
        return try await request("/friends", method: "GET")
    }

    //This adds a new friend on the backend server
    func addFriend(email: String) async throws -> [String: String] {
        let body = ["email": email]
        return try await request("/friends/add", method: "POST", body: body)
    }

    //This searches for users on the backend server
    func searchUsers(query: String) async throws -> SearchUsersResponse {
        return try await request("/users/search?q=" + query, method: "GET")
    }

    //This gets the list of pending friend requests from the backend server
    func getPendingFriends() async throws -> PendingResponse {
        return try await request("/friends/pending", method: "GET")
    }

    //This responds to a friend request on the backend server
    func respondToFriend(requesterId: Int, response: String) async throws -> [String: String] {
        let body = RespondFriendRequest(requester_id: requesterId, response: response)
        return try await request("/friends/respond", method: "POST", body: body)
    }
    
    //This gets the list of active wagers from the backend server
    func getActiveWagers() async throws -> WagerResponse {
        return try await request("/wagers/active", method: "GET")
    }
    
    //This gets the list of pending wagers from the backend server
    func getPendingWagers() async throws -> WagerResponse {
        return try await request("/wagers/pending", method: "GET")
    }
    
    //This verifies a wager on the backend server
    func verifyWager(wagerId: Int, outcome: String) async throws -> [String: String] {
        let body = VerifyWagerRequest(outcome: outcome)
        return try await request("/wagers/\(wagerId)/verify", method: "POST", body: body)
    }

    struct UploadProofResponse: Codable {
        let message: String
        let proof_url: String?
    }

    func uploadProof(wagerId: Int, imageData: Data, filename: String) async throws -> UploadProofResponse {
        guard let url = URL(string: baseURL + "/wagers/\(wagerId)/proof") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Debug: show if we have a token and body length
        print("[uploadProof] hasAuthToken=\(AuthService.shared.getToken() != nil), uploadBytes=\(imageData.count)")

        // Build multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let lineBreak = "\r\n"

        body.appendString("--\(boundary)\(lineBreak)")
        body.appendString("Content-Disposition: form-data; name=\"proof\"; filename=\"")
        body.appendString(filename)
        body.appendString("\"\(lineBreak)")
        body.appendString("Content-Type: image/jpeg\(lineBreak)\(lineBreak)")
        body.append(imageData)
        body.appendString(lineBreak)
        body.appendString("--\(boundary)--\(lineBreak)")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // Debug logging to help diagnose -1011 (Bad Server Response)
        if let bodyString = String(data: data, encoding: .utf8) {
            print("[uploadProof] HTTP \(httpResponse.statusCode) response body: \(bodyString)")
        } else {
            print("[uploadProof] HTTP \(httpResponse.statusCode) response body: <non-utf8> (\(data.count) bytes)")
        }

        // If the request failed, try to decode the error body
        if !(200...299).contains(httpResponse.statusCode) {
            if let serverError = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(domain: "upload", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: serverError.error])
            } else {
                throw URLError(.badServerResponse)
            }
        }

        return try JSONDecoder().decode(UploadProofResponse.self, from: data)
    }

    // Register the device token for APNs with the backend
    func postDeviceToken(_ token: String) async throws -> [String: String] {
        let body = ["deviceToken": token]
        return try await request("/users/device-token", method: "POST", body: body)
    }
    
    // Stripe Connect: Create onboarding link for referee payouts
    func createStripeOnboardingLink() async throws -> StripeOnboardingResponse {
        return try await request("/stripe/onboard", method: "POST")
    }
    
    // Stripe Connect: Check account status
    func getStripeAccountStatus() async throws -> StripeAccountStatus {
        return try await request("/stripe/account-status", method: "GET")
    }
    
    // Generic request method for custom calls
    func makeRequest<T: Decodable>(_ endpoint: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        return try await request(endpoint, method: method, body: body)
    }
    
    private func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔐 Request to \(endpoint) with token: \(token.prefix(20))...")
        } else {
            print("⚠️ Request to \(endpoint) WITHOUT token")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📡 Response from \(endpoint): Status \(httpResponse.statusCode)")
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Error response body: \(errorString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // Debug: print response for Stripe endpoints
        if endpoint.contains("stripe") {
            if let responseString = String(data: data, encoding: .utf8) {
                print("✅ Stripe response: \(responseString)")
            }
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - User Stats
    func getUserStats() async throws -> UserStatsResponse {
        return try await makeRequest("/users/stats", method: "GET")
    }
}

fileprivate extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}