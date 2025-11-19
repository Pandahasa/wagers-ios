import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showRegistration = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Do Your Work")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                TextField("Email or Username", text: $viewModel.identifier)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button("Login") {
                        Task { await viewModel.login() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.identifier.isEmpty || viewModel.password.isEmpty)
                }
                
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button("Don't have an account? Register") {
                    showRegistration = true
                }
                .font(.footnote)
            }
            .padding()
        }
        .sheet(isPresented: $showRegistration) {
            RegistrationView()
        }
    }
}

#Preview {
    LoginView()
}