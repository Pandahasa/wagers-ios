import SwiftUI

struct FriendsListView: View {
    @StateObject private var viewModel = FriendsListViewModel()
    @State private var emailToAdd = ""
    @State private var searchQuery = ""
    @State private var searchResults: [User] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    // Search for users by username or email
                    TextField("Search by username or email", text: $searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    Button("Search") {
                        Task {
                            do {
                                let resp = try await NetworkService.shared.searchUsers(query: searchQuery)
                                searchResults = resp.users
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
                .padding(.horizontal)

                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.friends.isEmpty {
                    Text("No friends yet")
                        .foregroundColor(.secondary)
                } else {
                    List(viewModel.friends) { friend in
                        VStack(alignment: .leading) {
                            Text(friend.username)
                            Text(friend.email)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                if !searchResults.isEmpty {
                    Section(header: Text("Search Results")) {
                        ForEach(searchResults) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.username)
                                    Text(user.email).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Button("Send Request") {
                                    Task {
                                        _ = await viewModel.addFriend(email: user.email)
                                        // optionally clear results and query
                                        searchResults = []
                                        searchQuery = ""
                                    }
                                }
                            }
                        }
                    }
                }

                if !viewModel.pending.isEmpty {
                    Section(header: Text("Pending Requests")) {
                        ForEach(viewModel.pending) { p in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(p.username)
                                    Text(p.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Button("Accept") {
                                    Task { await viewModel.respondToRequest(requesterId: p.requester_id, accept: true) }
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Reject") {
                                    Task { await viewModel.respondToRequest(requesterId: p.requester_id, accept: false) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Friends")
            .task { await viewModel.fetchFriends() }
            .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
                Button("OK") {
                    viewModel.errorMessage = ""
                }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

#Preview {
    FriendsListView()
}
