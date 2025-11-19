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

struct ErrorResponse: Codable {
    let error: String
}

class NetworkService {
    static let shared = NetworkService()
    private let baseURL = "http://192.168.68.113:3000/api"  // Use local IP for iOS simulator
    
    private init() {}
    
    func login(identifier: String, password: String) async throws -> LoginResponse {
        let body = ["identifier": identifier, "password": password]
        return try await request("/users/login", method: "POST", body: body)
    }
    
    func register(username: String, email: String, password: String) async throws -> LoginResponse {
        let body = ["username": username, "email": email, "password": password]
        return try await request("/users/register", method: "POST", body: body)
    }
    
    func createWager(taskDescription: String, wagerAmount: Double, deadline: String, refereeId: Int) async throws -> CreateWagerResponse {
        let body = CreateWagerRequest(task_description: taskDescription, wager_amount: wagerAmount, deadline: deadline, referee_id: refereeId)
        return try await request("/wagers/create", method: "POST", body: body)
    }

    func getFriends() async throws -> FriendsResponse {
        return try await request("/friends", method: "GET")
    }

    func addFriend(email: String) async throws -> [String: String] {
        let body = ["email": email]
        return try await request("/friends/add", method: "POST", body: body)
    }

    func searchUsers(query: String) async throws -> SearchUsersResponse {
        return try await request("/users/search?q=" + query, method: "GET")
    }

    func getPendingFriends() async throws -> PendingResponse {
        return try await request("/friends/pending", method: "GET")
    }

    func respondToFriend(requesterId: Int, response: String) async throws -> [String: String] {
        let body = RespondFriendRequest(requester_id: requesterId, response: response)
        return try await request("/friends/respond", method: "POST", body: body)
    }
    
    func getActiveWagers() async throws -> WagerResponse {
        return try await request("/wagers/active", method: "GET")
    }
    
    func getPendingWagers() async throws -> WagerResponse {
        return try await request("/wagers/pending", method: "GET")
    }
    
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
    
    private func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

fileprivate extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}