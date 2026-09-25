import SwiftUI

enum BoardRoute: Hashable {
    case intervals
    case routines
    case progress
    case settings
    case interval(UUID)
    case runner(UUID)
    case routine(UUID)
}

struct ContentView: View {
    @StateObject private var store = DataStore()
    @State private var path = NavigationPath()

    var body: some View {
        Group {
            if store.hasSeenOnboarding {
                NavigationStack(path: $path) {
                    BoardView(path: $path)
                        .navigationDestination(for: BoardRoute.self) { route in
                            switch route {
                            case .intervals:
                                IntervalListView()
                            case .routines:
                                RoutineListView()
                            case .progress:
                                ProgressScreen()
                            case .settings:
                                SettingsView()
                            case .interval(let id):
                                IntervalDetailView(presetID: id)
                            case .runner(let id):
                                IntervalRunnerView(presetID: id)
                            case .routine(let id):
                                RoutineDetailView(routineID: id)
                            }
                        }
                }
            } else {
                OnboardingView()
            }
        }
        .environmentObject(store)
        .background {
            KeyboardTapDismiss()
                .allowsHitTesting(false)
        }
    }
}

struct BoardView: View {
    @EnvironmentObject private var store: DataStore
    @Binding var path: NavigationPath
    @State private var creatingInterval = false
    @State private var creatingRoutine = false
    @State private var showGoal = false
    @State private var draftGoal = 60
    @State private var repeatMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhotoBanner(name: "shoes_watch")
                goalBlock
                stats
                intervalBlock
                routineBlock
                weekBlock
                repeatBlock
            }
            .padding(16)
        }
        .trackBackdrop("track_dusk")
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(value: BoardRoute.settings) {
                    Image(systemName: "gearshape")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $creatingInterval) {
            NavigationStack {
                IntervalEditor(existing: nil)
            }
        }
        .sheet(isPresented: $creatingRoutine) {
            NavigationStack {
                RoutineEditor(existing: nil)
            }
        }
        .sheet(isPresented: $showGoal) {
            NavigationStack {
                Form {
                    Picker("Minutes", selection: $draftGoal) {
                        Text("No goal").tag(0)
                        ForEach([30, 45, 60, 90, 120, 150, 180, 240, 300], id: \.self) { value in
                            Text(EnglishWeek.minutes(value)).tag(value)
                        }
                    }
                }
                .navigationTitle("Weekly goal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showGoal = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.setWeeklyGoal(draftGoal)
                            showGoal = false
                        }
                    }
                }
            }
        }
    }

    private var weekMinutes: Int {
        store.weeklyTotals.reduce(0, +)
    }

    private var goalProgress: Double {
        guard store.weeklyGoalMinutes > 0 else { return 0 }
        return min(1, Double(weekMinutes) / Double(store.weeklyGoalMinutes))
    }

    private var goalBlock: some View {
        LanePlate {
            HStack(spacing: 14) {
                SplitRing(progress: goalProgress)
                    .frame(width: 64, height: 64)
                    .accessibilityLabel("Weekly goal \(Int(goalProgress * 100)) percent")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(store.weeklyGoalMinutes == 0 ? "\(EnglishWeek.minutes(weekMinutes)) logged" : "\(weekMinutes) of \(store.weeklyGoalMinutes) min")
                        .font(.headline)
                    Button(store.weeklyGoalMinutes == 0 ? "Set goal" : "Edit goal") {
                        draftGoal = store.weeklyGoalMinutes == 0 ? 60 : store.weeklyGoalMinutes
                        showGoal = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(title: "This week", value: EnglishWeek.minutes(store.weeklyTotals.reduce(0, +)))
            StatTile(title: "Sessions", value: "\(store.totalSessionsCompleted)")
            StatTile(title: "Days logged", value: "\(store.loggedDayCount())")
        }
    }

    @ViewBuilder
    private var intervalBlock: some View {
        if let preset = store.lastUsedPreset {
            LanePlate {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Next interval")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(preset.name)
                        .font(.title3.weight(.semibold))
                    Text("Work \(preset.workSeconds) sec · Rest \(preset.restSeconds) sec · \(preset.rounds) rounds")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    NavigationLink(value: BoardRoute.runner(preset.id)) {
                        Text("Start")
                            .font(.headline)
                            .foregroundStyle(Color.onBrand)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background {
                                LinearGradient(colors: [Color.brand, Color.accentLane], startPoint: .leading, endPoint: .trailing)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    HStack {
                        NavigationLink(value: BoardRoute.intervals) {
                            Text("All sessions")
                        }
                        Spacer()
                        NavigationLink(value: BoardRoute.interval(preset.id)) {
                            Text("Details")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        } else {
            LanePlate {
                VStack(alignment: .leading, spacing: 12) {
                    EmptyLane(
                        symbol: "calendar.badge.plus",
                        title: "No Interval Sessions Yet",
                        message: "Set work, rest, and rounds, then run the clock."
                    )
                    FillButton(title: "New Session", systemImage: "plus") {
                        creatingInterval = true
                    }
                }
            }
        }
    }

    private var routineBlock: some View {
        LanePlate(rail: .accentLane) {
            VStack(alignment: .leading, spacing: 10) {
                Text(EnglishWeek.name(forWeekday: Calendar.current.component(.weekday, from: Date())))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Today's routines")
                    .font(.title3.weight(.semibold))
                let today = store.routinesForToday()
                if today.isEmpty {
                    Text("No routine is assigned to this weekday.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    FillButton(title: "Add Routine", systemImage: "plus") {
                        creatingRoutine = true
                    }
                    NavigationLink(value: BoardRoute.routines) {
                        Text("Open routines")
                            .font(.subheadline.weight(.semibold))
                    }
                } else {
                    ForEach(today) { routine in
                        Button {
                            path.append(BoardRoute.routine(routine.id))
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(routine.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(progressLine(routine))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var weekBlock: some View {
        NavigationLink(value: BoardRoute.progress) {
            LanePlate {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Statistics")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    if store.sessions.isEmpty {
                        Text("Start tracking your workouts today!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let latest = store.sessions.first {
                        Text("Latest: \(latest.title) · \(EnglishWeek.minutes(latest.totalMinutes))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var repeatBlock: some View {
        if let latest = store.sessions.first {
            VStack(alignment: .leading, spacing: 8) {
                QuietButton(title: "Log again", systemImage: "arrow.clockwise") {
                    store.repeatSession(latest)
                    repeatMessage = "Logged \(latest.title) again."
                    Haptics.success()
                }
                Text(repeatMessage ?? "Same minutes and exercises as \(latest.title). The note stays blank.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func progressLine(_ routine: Routine) -> String {
        let total = routine.exercises.count
        let done = routine.exercises.filter { store.isExerciseDone($0.id) }.count
        return "\(done) of \(total) exercises marked"
    }
}
