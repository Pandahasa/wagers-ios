import SwiftUI
import PhotosUI
import UIKit

struct WagerDetailView: View {
    let wager: Wager
    let isReferee: Bool
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isUploading = false
    @State private var uploadMessage = ""
    @State private var localProofUrl: String? = nil
    @State private var showImageFullScreen = false

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

                // Proof Image (if available)
                let displayedProofUrl = localProofUrl ?? wager.proof_image_url
                if let proofUrl = displayedProofUrl {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Proof of Completion")
                            .font(.headline)
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
                }

                // Action Buttons (for pledgers who haven't uploaded proof yet)
                if !isReferee && wager.status == "active" && (wager.proof_image_url == nil && localProofUrl == nil) {
                    Button(action: {
                        // The PhotosPicker below will handle image selection
                    }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Upload Proof")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top)
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        Text("Select Photo")
                    }
                    .task(id: selectedItem) {
                        guard let item = selectedItem else { selectedImageData = nil; return }
                        // Prefer raw Data - PhotosPicker can provide the image as Data which we upload directly
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        } else {
                            // Unable to get Data directly — clear selection and show a message
                            selectedImageData = nil
                            uploadMessage = "Unable to read selected image; try choosing another photo or saving it as a JPEG from Photos."
                        }
                    }

                    if let selectedData = selectedImageData {
                        if let img = UIImage(data: selectedData) {
                            // Show an inline preview of the selected image before uploading
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipped()
                                .cornerRadius(12)
                        }
                        Button(action: {
                            Task {
                                guard let data = selectedImageData else { return }
                                await MainActor.run {
                                    isUploading = true
                                    uploadMessage = ""
                                }
                                print("Starting upload for wager id: \(wager.id)")
                                do {
                                    let filename = "proof_\(wager.id).jpg"
                                    let resp = try await NetworkService.shared.uploadProof(wagerId: wager.id, imageData: data, filename: filename)
                                    await MainActor.run {
                                        isUploading = false
                                        uploadMessage = resp.message
                                        if let url = resp.proof_url { localProofUrl = url }
                                    }

                                    // Notify other parts of the app (referee list) that a proof was uploaded
                                    NotificationCenter.default.post(name: .wagerProofUploaded, object: nil, userInfo: ["wagerId": wager.id])
                                    print("Upload succeeded for wager id: \(wager.id) -> \(String(describing: resp.proof_url))")
                                } catch {
                                    await MainActor.run {
                                        isUploading = false
                                        uploadMessage = "Upload failed: \(error.localizedDescription)"
                                    }
                                    print("Upload failed for wager id: \(wager.id) -> \(error)")
                                }
                            }
                        }) {
                            HStack {
                                if isUploading { ProgressView() }
                                Text("Upload Selected Photo")
                            }
                        }
                        .padding(.top)

                        if !uploadMessage.isEmpty {
                            Text(uploadMessage)
                                .font(.caption)
                                .foregroundColor(uploadMessage.lowercased().contains("failed") ? .red : .green)
                                .padding(.top, 8)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isReferee ? "Verify Wager" : "Wager Details")
        .sheet(isPresented: $showImageFullScreen) {
            if let urlString = localProofUrl ?? wager.proof_image_url,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
            } else {
                Text("No image available")
            }
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
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        
        return formatter.string(from: date)
    }
}