import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: DataStore
    @State private var page = 0

    private let pages: [(image: String, title: String, message: String)] = [
        ("shoes_watch", "Plan Your Workouts", "Quickly set up your exercise schedule with customizable days."),
        ("gym_floor", "Track Exercise Durations", "Allocate specific times for each exercise within your routine for precision training."),
        ("lane_morning", "Begin Training", "Start your scheduled session by initiating your first timed exercise routine.")
    ]

    var body: some View {
        TabView(selection: $page) {
            ForEach(pages.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 18) {
                    PhotoBanner(name: pages[index].image, height: 220)
                    Text(pages[index].title)
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(pages[index].message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .tint(Color.brand)
        .trackBackdrop("track_dusk")
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                Button("Skip") {
                    store.completeOnboarding()
                }
                .font(.headline)
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 20)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                QuietButton(title: "Back") {
                    page = max(0, page - 1)
                }
                .disabled(page == 0)
                .opacity(page == 0 ? 0.45 : 1)
                FillButton(title: page == pages.count - 1 ? "Start" : "Next", systemImage: "arrow.right") {
                    if page == pages.count - 1 {
                        store.completeOnboarding()
                    } else {
                        page += 1
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color.bg.opacity(0.94))
        }
    }
}
