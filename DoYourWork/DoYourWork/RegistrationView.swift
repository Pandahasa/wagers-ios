import SwiftUI

struct RegistrationView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Register")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Username", text: $viewModel.username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Email", text: $viewModel.email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
            
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if viewModel.isLoading {
                ProgressView()
            } else {
                Button("Register") {
                    Task { await viewModel.register() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.username.isEmpty || viewModel.email.isEmpty || viewModel.password.isEmpty)
            }
            
            if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button("Already have an account? Login") {
                dismiss()
            }
            .font(.footnote)
        }
        .padding()
    }
}

#Preview {
    RegistrationView()
}