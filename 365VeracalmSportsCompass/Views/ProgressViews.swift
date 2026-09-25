import SwiftUI

enum StatsFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case intervals = "Intervals"
    case routines = "Routines"

    var id: String { rawValue }

    var kind: SessionKind? {
        switch self {
        case .all: return nil
        case .intervals: return .interval
        case .routines: return .routine
        }
    }
}

struct WeekDaySelection: Identifiable {
    let index: Int
    let offset: Int
    let kind: SessionKind?
    var id: String { "\(offset)-\(index)-\(kind?.rawValue ?? "all")" }
}

struct ProgressScreen: View {
    @EnvironmentObject private var store: DataStore
    @State private var weekOffset = 0
    @State private var filter: StatsFilter = .all
    @State private var selectedDay: WeekDaySelection?
    @State private var editing: WorkoutSession?
    @State private var pendingDelete: WorkoutSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhotoBanner(name: "lane_morning", height: 132)
                Picker("Show", selection: $filter) {
                    ForEach(StatsFilter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                summary
                chartCard
                trendCard
                weekdayCard
                if visibleSessions.isEmpty {
                    EmptyLane(
                        symbol: "chart.bar.doc.horizontal",
                        title: emptyTitle,
                        message: emptyMessage
                    )
                } else {
                    Text(filter == .all ? "All logs" : filter.rawValue)
                        .font(.headline)
                    if let latest = visibleSessions.first {
                        QuietButton(title: "Log again", systemImage: "arrow.clockwise") {
                            store.repeatSession(latest)
                            Haptics.success()
                        }
                    }
                    ForEach(visibleSessions) { session in
                        sessionRow(session)
                    }
                }
            }
            .padding(16)
        }
        .trackBackdrop("track_dusk")
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedDay) { day in
            NavigationStack {
                DayLogSheet(selection: day)
            }
        }
        .sheet(item: $editing) { session in
            NavigationStack {
                SessionEditor(session: session)
            }
        }
        .alert("Delete this log?", isPresented: deletePresented) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    store.deleteSession(id: pendingDelete.id)
                }
                pendingDelete = nil
            }
        } message: {
            Text("The minutes leave the week chart as soon as the log is removed.")
        }
    }

    private var summary: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(title: "Minutes logged", value: EnglishWeek.minutes(visibleSessions.reduce(0) { $0 + $1.totalMinutes }))
            StatTile(title: "Sessions", value: "\(visibleSessions.count)")
            if filter == .all && store.streakDays > 0 {
                StatTile(title: "Consecutive days", value: "\(store.streakDays)")
            }
        }
    }

    private var chartCard: some View {
        LanePlate {
            VStack(alignment: .leading, spacing: 12) {
                Text(weekTitle)
                    .font(.headline)
                WeekChart(totals: store.totals(forWeekOffset: weekOffset, kind: filter.kind), labels: labels) { index in
                    selectedDay = WeekDaySelection(index: index, offset: weekOffset, kind: filter.kind)
                }
                HStack(spacing: 12) {
                    QuietButton(title: "Previous") { weekOffset -= 1 }
                    QuietButton(title: "Next") { weekOffset += 1 }
                        .disabled(weekOffset >= 0)
                        .opacity(weekOffset >= 0 ? 0.45 : 1)
                }
                Text("Tap a bar for that day’s exercises.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trendCard: some View {
        LanePlate(rail: .accentLane) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last 8 weeks")
                    .font(.headline)
                TrendChart(values: trendValues, labels: trendLabels)
                Text("Each point is the total minutes logged that week.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weekdayCard: some View {
        LanePlate {
            VStack(alignment: .leading, spacing: 12) {
                Text("Minutes by weekday")
                    .font(.headline)
                WeekChart(totals: minutesByWeekday, labels: EnglishWeek.short)
                Text("All saved logs, grouped by the day they were recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var labels: [String] {
        (0..<7).map { store.dayLabel(index: $0, weekOffset: weekOffset) }
    }

    private var visibleSessions: [WorkoutSession] {
        store.sessions.filter { filter.kind == nil || $0.kind == filter.kind }
    }

    private var emptyTitle: String {
        switch filter {
        case .all: return "Start tracking your workouts today!"
        case .intervals: return "No interval logs yet"
        case .routines: return "No routine logs yet"
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .all: return "Finish an interval clock or log a routine. The charts fill from those sessions."
        case .intervals: return "Complete a timed interval session to see it here."
        case .routines: return "Log completed work from a routine to see it here."
        }
    }

    private var trendValues: [Int] {
        (-7...0).map { offset in
            store.totals(forWeekOffset: offset, kind: filter.kind).reduce(0, +)
        }
    }

    private var trendLabels: [String] {
        (-7...0).map { offset in
            monthDay(store.weekStart(offset: offset))
        }
    }

    private var minutesByWeekday: [Int] {
        var bins = Array(repeating: 0, count: 7)
        let calendar = Calendar.current
        for session in visibleSessions {
            let weekday = calendar.component(.weekday, from: session.date)
            if (1...7).contains(weekday) {
                bins[weekday - 1] += max(0, session.totalMinutes)
            }
        }
        return bins
    }

    private var weekTitle: String {
        if weekOffset == 0 { return "This week" }
        if weekOffset == -1 { return "Last week" }
        let start = store.weekStart(offset: weekOffset)
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        return "\(shortDate(start)) – \(shortDate(end))"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    private func monthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: date)
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        LanePlate {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.title)
                    .font(.headline)
                Text("\(session.kind.title) · \(EnglishWeek.stamp(session.date)) · \(EnglishWeek.minutes(session.totalMinutes))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !session.note.isEmpty {
                    Text(session.note)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let first = session.exercises.first {
                    Text(first)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Edit") { editing = session }
                    Button("Delete", role: .destructive) { pendingDelete = session }
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }
        }
        .contextMenu {
            Button("Edit") { editing = session }
            Button("Delete", role: .destructive) { pendingDelete = session }
        }
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
}

struct DayLogSheet: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let selection: WeekDaySelection
    @State private var editing: WorkoutSession?

    var body: some View {
        List {
            if sessions.isEmpty {
                Text("No exercises logged on this day.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.title)
                            .font(.headline)
                        Text(EnglishWeek.minutes(session.totalMinutes))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if !session.note.isEmpty {
                            Text(session.note)
                                .font(.subheadline)
                        }
                        ForEach(Array(session.exercises.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.subheadline)
                        }
                        Button("Edit") { editing = session }
                            .frame(minHeight: 44)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(store.dayLabel(index: selection.index, weekOffset: selection.offset))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(item: $editing) { session in
            NavigationStack {
                SessionEditor(session: session)
            }
        }
    }

    private var sessions: [WorkoutSession] {
        store.sessions(onDayIndex: selection.index, weekOffset: selection.offset, kind: selection.kind)
    }
}

struct SessionEditor: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession

    @State private var title: String
    @State private var minutes: Int
    @State private var note: String
    @State private var attempted = false
    @State private var confirmDelete = false

    init(session: WorkoutSession) {
        self.session = session
        _title = State(initialValue: session.title)
        _minutes = State(initialValue: max(1, session.totalMinutes))
        _note = State(initialValue: session.note)
    }

    var body: some View {
        Form {
            Section("Log") {
                Text(session.kind.title)
                    .foregroundStyle(.secondary)
                TextField("Title", text: $title)
                Stepper(value: $minutes, in: 1...300) {
                    Text(EnglishWeek.minutes(minutes))
                }
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(1...3)
                if attempted, let error = titleError {
                    FieldError(text: error)
                }
            }
            Section("Recorded work") {
                if session.exercises.isEmpty {
                    Text("No exercise lines were stored.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(session.exercises.enumerated()), id: \.offset) { _, line in
                        Text(line)
                    }
                }
            }
            Section {
                Button("Delete Log", role: .destructive) { confirmDelete = true }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .trackBackdrop("track_dusk")
        .navigationTitle("Edit Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .alert("Delete this log?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteSession(id: session.id)
                dismiss()
            }
        } message: {
            Text("The minutes leave the week chart as soon as the log is removed.")
        }
    }

    private var titleError: String? {
        NameCheck.trimmed(title).isEmpty ? "Enter a title." : nil
    }

    private func save() {
        attempted = true
        guard titleError == nil else { return }
        var updated = session
        updated.title = NameCheck.trimmed(title)
        updated.totalMinutes = minutes
        updated.note = String(NameCheck.trimmed(note).prefix(160))
        store.updateSession(updated)
        Haptics.success()
        dismiss()
    }
}
