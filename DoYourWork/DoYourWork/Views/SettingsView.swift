import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)

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

                NavigationLink(destination: FriendsListView()) {
                    Text("Friends")
                }

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    SettingsView()
}
