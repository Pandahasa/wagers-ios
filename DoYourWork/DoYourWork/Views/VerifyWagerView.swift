import SwiftUI

struct VerifyWagerView: View {
    let wager: Wager
    let onVerificationComplete: (Bool) -> Void
    @State private var showImageFullScreen = false
    @State private var showingSuccessAlert = false
    @State private var showingFailureAlert = false
    @State private var isVerifying = false
    @State private var verificationError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Status")
                            .font(.headline)
                        Spacer()
                        Text(wager.status.capitalized)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(statusColor.opacity(0.2))
                            .foregroundColor(statusColor)
                            .cornerRadius(16)
                    }

                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.green)
                        Text("$\(String(format: "%.2f", wager.wager_amount))")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                // Task Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("Task")
                        .font(.headline)
                    Text(wager.task_description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                // Deadline
                VStack(alignment: .leading, spacing: 12) {
                    Text("Deadline")
                        .font(.headline)
                    HStack {
                        Image(systemName: wager.isExpired ? "clock.badge.exclamationmark" : "clock")
                            .foregroundColor(wager.isExpired ? .red : .blue)
                        Text(formatDate(wager.deadlineDate))
                            .font(.body)
                        Spacer()
                        Text(wager.timeRemaining)
                            .font(.subheadline)
                            .foregroundColor(wager.isExpired ? .red : .blue)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                // Proof Image
                if let proofUrl = wager.proof_image_url {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Proof of Completion")
                            .font(.headline)
                        // TODO: Display actual image from URL
                        AsyncImage(url: URL(string: proofUrl)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .clipped()
                                    .onTapGesture { showImageFullScreen = true }
                            case .failure:
                                VStack {
                                    Image(systemName: "photo")
                                    Text("Failed to load image")
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Proof of Completion")
                            .font(.headline)
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.1))
                                .frame(height: 100)
                            VStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("No proof uploaded yet")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }

                // Verification Buttons
                if wager.status == "verifying" {
                    VStack(spacing: 16) {
                        if let error = verificationError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 16) {
                            // Success Button
                            Button(action: {
                                verifyWager(success: true)
                            }) {
                                HStack {
                                    if isVerifying {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                    Text("Task Completed")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(16)
                                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isVerifying)

                            // Failure Button
                            Button(action: {
                                verifyWager(success: false)
                            }) {
                                HStack {
                                    if isVerifying {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    Text("Task Failed")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(16)
                                .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isVerifying)
                        }
                    }
                    .padding(.top)
                } else {
                    Text("This wager is not ready for verification yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Verify Wager")
        .sheet(isPresented: $showImageFullScreen) {
            if let url = URL(string: wager.proof_image_url ?? "") {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
            } else {
                Text("No image available")
            }
        }
        .alert("Verification Successful", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The wager has been verified successfully.")
        }
        .alert("Verification Failed", isPresented: $showingFailureAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Failed to verify the wager. Please try again.")
        }
    }

    private var statusColor: Color {
        switch wager.status {
        case "active": return .blue
        case "verifying": return .orange
        case "completed_success": return .green
        case "completed_failure": return .red
        case "payout_complete": return .purple
        default: return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func verifyWager(success: Bool) {
        isVerifying = true
        verificationError = nil

        Task {
            do {
                let outcome = success ? "success" : "failure"
                let _ = try await NetworkService.shared.verifyWager(wagerId: wager.id, outcome: outcome)
                await MainActor.run {
                    isVerifying = false
                    // Just complete without showing any alert
                    onVerificationComplete(success)
                }
            } catch {
                // Only show error if it's a real error, not a duplicate request
                let errorMessage = error.localizedDescription.lowercased()
                let isDuplicateRequest = errorMessage.contains("already") || errorMessage.contains("processed")
                
                await MainActor.run {
                    isVerifying = false
                    if isDuplicateRequest {
                        // Silently succeed - wager was already processed
                        onVerificationComplete(success)
                    } else {
                        // Real error - show to user
                        verificationError = "Verification failed: \(error.localizedDescription)"
                        showingFailureAlert = true
                    }
                }
            }
        }
    }
}