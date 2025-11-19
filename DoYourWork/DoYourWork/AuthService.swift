import Foundation

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    private let keychainKey = "jwtToken"
    
    private init() {
        // Check for existing token on app launch
        if let _ = getToken() {
            isAuthenticated = true
        }
    }
    
    func saveToken(_ token: String) {
        // TODO: Use Keychain for secure storage (replace UserDefaults for production)
        UserDefaults.standard.set(token, forKey: keychainKey)
        isAuthenticated = true
    }
    
    func getToken() -> String? {
        // Read token from secure storage (UserDefaults for now)
        return UserDefaults.standard.string(forKey: keychainKey)
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: keychainKey)
        isAuthenticated = false
    }
}