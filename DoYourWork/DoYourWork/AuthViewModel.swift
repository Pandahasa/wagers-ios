import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var identifier = ""
    @Published var email = ""  // For registration
    @Published var password = ""
    @Published var username = ""  // For registration
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    func login() async {
        guard !identifier.isEmpty, !password.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "Please fill in all fields"
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = ""
        }
        
        do {
            let response = try await NetworkService.shared.login(identifier: identifier, password: password)
            DispatchQueue.main.async {
                if let error = response.error {
                    self.errorMessage = error
                } else if let token = response.token {
                    AuthService.shared.saveToken(token)
                } else {
                    self.errorMessage = "Unexpected response from server"
                }
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Login failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func register() async {
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "Please fill in all fields"
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = ""
        }
        
        do {
            let response = try await NetworkService.shared.register(username: username, email: email, password: password)
            DispatchQueue.main.async {
                if let error = response.error {
                    self.errorMessage = error
                } else if let token = response.token {
                    AuthService.shared.saveToken(token)
                } else {
                    self.errorMessage = "Unexpected response from server"
                }
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Registration failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}