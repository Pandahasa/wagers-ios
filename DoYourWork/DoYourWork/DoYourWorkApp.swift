import SwiftUI

@main
struct DoYourWorkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var authService = AuthService.shared

    var body: some Scene {
        WindowGroup {
            // Restore proper authentication flow
            if authService.isAuthenticated {
                HomeView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
}