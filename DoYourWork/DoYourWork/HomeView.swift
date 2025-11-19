import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        TabView {
            MyWagersView()
                .tabItem {
                    Label("My Wagers", systemImage: "list.bullet")
                }
            
            ToVerifyView()
                .tabItem {
                    Label("To Verify", systemImage: "checkmark.circle")
                }
            
            CreateWagerView()
                .tabItem {
                    Label("Create", systemImage: "plus")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    HomeView()
}