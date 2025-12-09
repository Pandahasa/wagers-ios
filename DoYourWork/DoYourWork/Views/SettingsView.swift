import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Success Counter Card
                if let stats = viewModel.userStats {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    .linearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(stats.successful_wagers_count)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text(stats.successful_wagers_count == 1 ? "Success" : "Successes")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                        
                        Text(stats.username)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Stripe Connect onboarding section
                VStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView("Loading...")
                    } else if let status = viewModel.accountStatus {
                        if status.chargesEnabled == true && status.payoutsEnabled == true {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Payment Setup Complete")
                                    .fontWeight(.semibold)
                            }
                        } else {
                            Button {
                                Task {
                                    await viewModel.startOnboarding()
                                }
                            } label: {
                                Text(status.hasAccount ? "Complete Payment Setup" : "Set Up Payments")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    } else {
                        Button {
                            Task {
                                await viewModel.loadAccountStatus()
                            }
                        } label: {
                            Text("Check Payment Status")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal)

                NavigationLink(destination: FriendsListView()) {
                    Text("Friends")
                }

                Button(role: .destructive) {
                    authService.logout()
                } label: {
                    Text("Logout")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .sheet(isPresented: $viewModel.showOnboarding) {
                if let url = viewModel.onboardingURL {
                    SafariView(url: url)
                }
            }
            .task {
                await viewModel.loadAccountStatus()
                await viewModel.loadUserStats()
            }
        }
    }
}

#Preview {
    SettingsView()
}

