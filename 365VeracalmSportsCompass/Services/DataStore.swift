import Combine
import Foundation

@MainActor
final class DataStore: ObservableObject {
    @Published var hasSeenOnboarding: Bool
    @Published private(set) var presets: [IntervalPreset]
    @Published private(set) var lastUsedPresetId: UUID?
    @Published private(set) var routines: [Routine]
    @Published private(set) var completedExerciseIDs: Set<String>
    @Published private(set) var sessions: [WorkoutSession]
    @Published private(set) var weeklyTotals: [Int]
    @Published private(set) var totalSessionsCompleted: Int
    @Published private(set) var totalMinutesUsed: Int
    @Published private(set) var streakDays: Int
    @Published private(set) var lastActivityDate: Date?
    @Published private(set) var weeklyGoalMinutes: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let decoder = JSONDecoder()
        hasSeenOnboarding = defaults.bool(forKey: Key.onboarding)
        presets = Self.read([IntervalPreset].self, key: Key.presets, defaults: defaults, decoder: decoder) ?? []
        if let raw = defaults.string(forKey: Key.lastPreset) {
            lastUsedPresetId = UUID(uuidString: raw)
        } else {
            lastUsedPresetId = nil
        }
        routines = Self.read([Routine].self, key: Key.routines, defaults: defaults, decoder: decoder) ?? []
        completedExerciseIDs = Set(Self.read([String].self, key: Key.completed, defaults: defaults, decoder: decoder) ?? [])
        sessions = Self.read([WorkoutSession].self, key: Key.sessions, defaults: defaults, decoder: decoder) ?? []
        let storedWeek = Self.read([Int].self, key: Key.weekly, defaults: defaults, decoder: decoder) ?? []
        weeklyTotals = storedWeek.count == 7 ? storedWeek : Array(repeating: 0, count: 7)
        totalSessionsCompleted = defaults.integer(forKey: Key.totalSessions)
        totalMinutesUsed = defaults.integer(forKey: Key.totalMinutes)
        streakDays = defaults.integer(forKey: Key.streak)
        let stamp = defaults.double(forKey: Key.lastActivity)
        lastActivityDate = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
        weeklyGoalMinutes = defaults.integer(forKey: Key.weeklyGoal)
        weeklyTotals = totals(forWeekOffset: 0)
        recomputeStreak()
        persist()
    }

    var lastUsedPreset: IntervalPreset? {
        guard let lastUsedPresetId else { return presets.first }
        return presets.first(where: { $0.id == lastUsedPresetId }) ?? presets.first
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
        defaults.set(true, forKey: Key.onboarding)
    }

    func savePreset(_ preset: IntervalPreset, isNew: Bool) {
        if isNew {
            presets.append(preset)
        } else if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        lastUsedPresetId = preset.id
        persist()
    }

    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        if lastUsedPresetId == id {
            lastUsedPresetId = presets.first?.id
        }
        persist()
    }

    func movePresets(from source: IndexSet, to destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func shiftPreset(id: UUID, delta: Int) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        let target = index + delta
        guard presets.indices.contains(target) else { return }
        presets.swapAt(index, target)
        persist()
    }

    func markPresetUsed(_ id: UUID) {
        lastUsedPresetId = id
        persist()
    }

    func saveRoutine(_ routine: Routine, isNew: Bool) {
        if isNew {
            routines.append(routine)
        } else if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            let previous = Set(routines[index].exercises.map(\.id.uuidString))
            let current = Set(routine.exercises.map(\.id.uuidString))
            completedExerciseIDs.subtract(previous.subtracting(current))
            routines[index] = routine
        } else {
            routines.append(routine)
        }
        persist()
    }

    func availableRoutineName(_ base: String, weekday: Int) -> String {
        let taken = Set(routines.filter { $0.weekday == weekday }.map { NameCheck.trimmed($0.name).lowercased() })
        let clean = NameCheck.trimmed(base)
        if !taken.contains(clean.lowercased()) { return clean }
        var index = 2
        var candidate = "\(clean) \(index)"
        while taken.contains(candidate.lowercased()) && index < 40 {
            index += 1
            candidate = "\(clean) \(index)"
        }
        return candidate
    }

    func copyRoutine(_ source: Routine, to weekday: Int, name: String) {
        let clean = NameCheck.trimmed(name)
        guard !clean.isEmpty, (1...7).contains(weekday) else { return }
        let copy = Routine(
            id: UUID(),
            name: clean,
            weekday: weekday,
            exercises: source.exercises.map {
                ExerciseItem(id: UUID(), name: $0.name, durationSeconds: $0.durationSeconds)
            },
            restSeconds: source.restSeconds
        )
        routines.append(copy)
        persist()
    }

    func deleteRoutine(id: UUID) {
        if let routine = routines.first(where: { $0.id == id }) {
            let ids = Set(routine.exercises.map(\.id.uuidString))
            completedExerciseIDs.subtract(ids)
        }
        routines.removeAll { $0.id == id }
        persist()
    }

    func shiftExercise(routineID: UUID, exerciseID: UUID, delta: Int) {
        guard let index = routines.firstIndex(where: { $0.id == routineID }) else { return }
        guard let exerciseIndex = routines[index].exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let target = exerciseIndex + delta
        guard routines[index].exercises.indices.contains(target) else { return }
        routines[index].exercises.swapAt(exerciseIndex, target)
        persist()
    }

    func toggleExercise(_ id: UUID) {
        let key = id.uuidString
        if completedExerciseIDs.contains(key) {
            completedExerciseIDs.remove(key)
        } else {
            completedExerciseIDs.insert(key)
        }
        persist()
    }

    func isExerciseDone(_ id: UUID) -> Bool {
        completedExerciseIDs.contains(id.uuidString)
    }

    @discardableResult
    func logRoutine(_ routine: Routine) -> Bool {
        let done = routine.exercises.filter { isExerciseDone($0.id) }
        guard !done.isEmpty else { return false }
        let seconds = done.reduce(0) { $0 + $1.durationSeconds }
        let minutes = MinuteMath.roundedUp(from: seconds)
        addSession(
            title: routine.name,
            exercises: done.map { "\($0.name) · \($0.durationSeconds) sec" },
            minutes: minutes,
            kind: .routine
        )
        return true
    }

    func logInterval(preset: IntervalPreset, workSecondsElapsed: Int, finished: Bool) {
        let seconds = max(0, workSecondsElapsed)
        guard seconds > 0 else { return }
        let minutes = MinuteMath.roundedUp(from: seconds)
        let status = finished ? "Full session" : "Partial session"
        addSession(
            title: preset.name,
            exercises: [
                status,
                "Work \(preset.workSeconds) sec",
                "Rest \(preset.restSeconds) sec",
                "Rounds planned \(preset.rounds)",
                "Work logged \(seconds) sec"
            ],
            minutes: minutes,
            kind: .interval
        )
        lastUsedPresetId = preset.id
        persist()
    }

    func repeatSession(_ session: WorkoutSession) {
        addSession(
            title: session.title,
            exercises: session.exercises,
            minutes: session.totalMinutes,
            kind: session.kind
        )
    }

    func setWeeklyGoal(_ minutes: Int) {
        weeklyGoalMinutes = max(0, minutes)
        defaults.set(weeklyGoalMinutes, forKey: Key.weeklyGoal)
    }

    func updateSession(_ session: WorkoutSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        let previous = sessions[index]
        sessions[index] = session
        totalMinutesUsed = max(0, totalMinutesUsed - previous.totalMinutes + session.totalMinutes)
        sessions.sort { $0.date > $1.date }
        weeklyTotals = totals(forWeekOffset: 0)
        persist()
    }

    func deleteSession(id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let previous = sessions.remove(at: index)
        totalSessionsCompleted = max(0, totalSessionsCompleted - 1)
        totalMinutesUsed = max(0, totalMinutesUsed - previous.totalMinutes)
        recomputeStreak()
        weeklyTotals = totals(forWeekOffset: 0)
        persist()
    }

    func totals(forWeekOffset offset: Int, kind: SessionKind? = nil, now: Date = Date()) -> [Int] {
        let calendar = Calendar.current
        let start = weekStart(offset: offset, now: now)
        var bins = Array(repeating: 0, count: 7)
        for session in sessions where kind == nil || session.kind == kind {
            let day = calendar.startOfDay(for: session.date)
            let delta = calendar.dateComponents([.day], from: start, to: day).day ?? -1
            if (0..<7).contains(delta) {
                bins[delta] += max(0, session.totalMinutes)
            }
        }
        return bins
    }

    func weekStart(offset: Int, now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let start = calendar.date(from: parts) ?? calendar.startOfDay(for: now)
        return calendar.date(byAdding: .weekOfYear, value: offset, to: start) ?? start
    }

    func dayLabel(index: Int, weekOffset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: index, to: weekStart(offset: weekOffset)) ?? Date()
        let weekday = calendar.component(.weekday, from: date)
        return EnglishWeek.short[weekday - 1]
    }

    func sessions(onDayIndex index: Int, weekOffset: Int, kind: SessionKind? = nil) -> [WorkoutSession] {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: index, to: weekStart(offset: weekOffset)) else { return [] }
        return sessions
            .filter { calendar.isDate($0.date, inSameDayAs: day) && (kind == nil || $0.kind == kind) }
            .sorted { $0.date > $1.date }
    }

    func routinesForToday(now: Date = Date()) -> [Routine] {
        let weekday = Calendar.current.component(.weekday, from: now)
        return routines.filter { $0.weekday == weekday }
    }

    func loggedDayCount(weekOffset: Int = 0) -> Int {
        totals(forWeekOffset: weekOffset).filter { $0 > 0 }.count
    }

    func resetAll() {
        Key.all.forEach { defaults.removeObject(forKey: $0) }
        presets = []
        lastUsedPresetId = nil
        routines = []
        completedExerciseIDs = []
        sessions = []
        weeklyTotals = Array(repeating: 0, count: 7)
        totalSessionsCompleted = 0
        totalMinutesUsed = 0
        streakDays = 0
        lastActivityDate = nil
        weeklyGoalMinutes = 0
        hasSeenOnboarding = true
        defaults.set(true, forKey: Key.onboarding)
        NotificationCenter.default.post(name: .dataReset, object: nil)
    }

    private func addSession(title: String, exercises: [String], minutes: Int, kind: SessionKind, note: String = "", date: Date = Date()) {
        let safeMinutes = max(1, minutes)
        let session = WorkoutSession(
            id: UUID(),
            date: date,
            title: title,
            exercises: exercises,
            totalMinutes: safeMinutes,
            note: note,
            kind: kind
        )
        sessions.insert(session, at: 0)
        totalSessionsCompleted += 1
        totalMinutesUsed += safeMinutes
        touchStreak(on: date)
        weeklyTotals = totals(forWeekOffset: 0)
        persist()
    }

    private func touchStreak(on date: Date) {
        let calendar = Calendar.current
        if let last = lastActivityDate {
            if calendar.isDate(last, inSameDayAs: date) {
                lastActivityDate = date
            } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)),
                      calendar.isDate(last, inSameDayAs: yesterday) {
                streakDays += 1
                lastActivityDate = date
            } else {
                streakDays = 1
                lastActivityDate = date
            }
        } else {
            streakDays = 1
            lastActivityDate = date
        }
    }

    private func recomputeStreak() {
        let calendar = Calendar.current
        let days = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else {
            streakDays = 0
            lastActivityDate = nil
            return
        }
        lastActivityDate = sessions.map(\.date).max()
        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor), days.contains(yesterday) else {
                streakDays = 0
                return
            }
            cursor = yesterday
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        streakDays = count
    }

    private func persist() {
        defaults.set(hasSeenOnboarding, forKey: Key.onboarding)
        write(presets, key: Key.presets)
        if let lastUsedPresetId {
            defaults.set(lastUsedPresetId.uuidString, forKey: Key.lastPreset)
        } else {
            defaults.removeObject(forKey: Key.lastPreset)
        }
        write(routines, key: Key.routines)
        write(Array(completedExerciseIDs), key: Key.completed)
        write(sessions, key: Key.sessions)
        write(weeklyTotals, key: Key.weekly)
        defaults.set(totalSessionsCompleted, forKey: Key.totalSessions)
        defaults.set(totalMinutesUsed, forKey: Key.totalMinutes)
        defaults.set(streakDays, forKey: Key.streak)
        if let lastActivityDate {
            defaults.set(lastActivityDate.timeIntervalSince1970, forKey: Key.lastActivity)
        } else {
            defaults.removeObject(forKey: Key.lastActivity)
        }
    }

    private func write<T: Encodable>(_ value: T, key: String) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func read<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults, decoder: JSONDecoder) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private enum Key {
        static let onboarding = "hasSeenOnboarding"
        static let presets = "intervalPresets"
        static let lastPreset = "lastUsedPresetId"
        static let routines = "routines"
        static let completed = "completedExercises"
        static let sessions = "workoutSessions"
        static let weekly = "weeklyTotals"
        static let totalSessions = "totalSessionsCompleted"
        static let totalMinutes = "totalMinutesUsed"
        static let streak = "streakDays"
        static let lastActivity = "lastActivityDate"
        static let weeklyGoal = "weeklyGoalMinutes"
        static let all = [onboarding, presets, lastPreset, routines, completed, sessions, weekly, totalSessions, totalMinutes, streak, lastActivity, weeklyGoal]
    }
}
