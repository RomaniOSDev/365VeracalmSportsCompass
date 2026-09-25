import StoreKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: DataStore
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhotoBanner(name: "lane_morning", height: 140)
                Text("Your sessions, routines, and logs stay on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                FillButton(title: "Rate Us", systemImage: "star") {
                    rateApp()
                }
                QuietButton(title: "Privacy", systemImage: "hand.raised") {
                    openPrivacy()
                }
                QuietButton(title: "Terms", systemImage: "doc.text") {
                    openTerms()
                }

                Button {
                    confirmReset = true
                } label: {
                    Text("Reset All Data")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.red.opacity(0.45), lineWidth: 1.5)
                        }
                        .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
                }
                .buttonStyle(PressStyle())
            }
            .padding(16)
        }
        .trackBackdrop("track_dusk")
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Reset all data?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.resetAll()
            }
        } message: {
            Text("This clears sessions, routines, and interval setups stored on this device.")
        }
    }

    private func openPrivacy() {
        if let url = URL(string: AppLinks.privacy) {
            UIApplication.shared.open(url)
        }
    }

    private func openTerms() {
        if let url = URL(string: AppLinks.terms) {
            UIApplication.shared.open(url)
        }
    }

    private func rateApp() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}
