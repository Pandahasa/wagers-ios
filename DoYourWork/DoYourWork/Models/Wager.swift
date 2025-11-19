import Foundation

struct Wager: Codable, Identifiable, Hashable {
    let id: Int
    let pledger_id: Int
    let referee_id: Int
    let task_description: String
    let wager_amount: Double
    let deadline: String
    let status: String
    let stripe_payment_intent_id: String
    let stripe_transfer_id: String?
    let proof_image_url: String?
    let created_at: String
    let updated_at: String

    var deadlineDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        // Don't set timezone for ISO8601DateFormatter - it handles UTC automatically
        
        if let date = formatter.date(from: deadline) {
            return date
        }
        
        // Fallback: try with fractional seconds
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: deadline) {
            return date
        }
        
        // Last resort: DateFormatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        if let date = dateFormatter.date(from: deadline) {
            return date
        }
        
        return Date()
    }

    var isExpired: Bool {
        deadlineDate < Date()
    }

    var timeRemaining: String {
        let remaining = deadlineDate.timeIntervalSince(Date())
        if remaining <= 0 {
            return "Expired"
        }

        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Wager, rhs: Wager) -> Bool {
        lhs.id == rhs.id
    }
}

struct WagerResponse: Codable {
    let wagers: [Wager]
}

struct FriendsResponse: Codable {
    let friends: [User]
}

struct PendingRequest: Codable, Identifiable {
    let requester_id: Int
    let username: String
    let email: String
    var id: Int { requester_id }
}

struct PendingResponse: Codable {
    let pending: [PendingRequest]
}

struct SearchUsersResponse: Codable {
    let users: [User]
}

struct RespondFriendRequest: Codable {
    let requester_id: Int
    let response: String
}

struct CreateWagerRequest: Codable {
    let task_description: String
    let wager_amount: Double
    let deadline: String
    let referee_id: Int
}

struct CreateWagerResponse: Codable {
    let wager_id: Int
    let client_secret: String
}

struct VerifyWagerRequest: Codable {
    let outcome: String // "success" or "failure"
}