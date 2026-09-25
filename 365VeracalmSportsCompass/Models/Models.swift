import Foundation

struct IntervalPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var workSeconds: Int
    var restSeconds: Int
    var rounds: Int
}

struct ExerciseItem: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var durationSeconds: Int
}

struct Routine: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var weekday: Int
    var exercises: [ExerciseItem]
    var restSeconds: Int

    init(id: UUID, name: String, weekday: Int, exercises: [ExerciseItem], restSeconds: Int = 0) {
        self.id = id
        self.name = name
        self.weekday = weekday
        self.exercises = exercises
        self.restSeconds = restSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        weekday = try container.decode(Int.self, forKey: .weekday)
        exercises = try container.decode([ExerciseItem].self, forKey: .exercises)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 0
    }
}

enum SessionKind: String, Codable {
    case interval
    case routine

    var title: String {
        switch self {
        case .interval: return "Interval"
        case .routine: return "Routine"
        }
    }
}

struct WorkoutSession: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var title: String
    var exercises: [String]
    var totalMinutes: Int
    var note: String
    var kind: SessionKind

    init(id: UUID, date: Date, title: String, exercises: [String], totalMinutes: Int, note: String = "", kind: SessionKind) {
        self.id = id
        self.date = date
        self.title = title
        self.exercises = exercises
        self.totalMinutes = totalMinutes
        self.note = note
        self.kind = kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        title = try container.decode(String.self, forKey: .title)
        exercises = try container.decode([String].self, forKey: .exercises)
        totalMinutes = try container.decode(Int.self, forKey: .totalMinutes)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        if let stored = try container.decodeIfPresent(SessionKind.self, forKey: .kind) {
            kind = stored
        } else if exercises.contains(where: { $0.contains("Rounds planned") }) {
            kind = .interval
        } else {
            kind = .routine
        }
    }
}

enum IntervalRules {
    static let workChoices = [10, 15, 20, 30, 40, 45, 60, 90, 120]
    static let restChoices = [0, 5, 10, 15, 20, 30, 45, 60]
    static let roundChoices = Array(1...12)
    static let exerciseDurations = [15, 20, 30, 45, 60, 90, 120, 180, 300]

    static func snap(_ value: Int, to options: [Int]) -> Int {
        options.min(by: { abs($0 - value) < abs($1 - value) }) ?? options[0]
    }
}

enum NameCheck {
    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func duplicateSuggestion(name: String, existing: [String]) -> String? {
        let clean = trimmed(name)
        guard !clean.isEmpty else { return nil }
        let lowered = existing.map { trimmed($0).lowercased() }.filter { !$0.isEmpty }
        guard lowered.contains(clean.lowercased()) else { return nil }
        var index = 2
        var candidate = "\(clean) \(index)"
        while lowered.contains(candidate.lowercased()) && index < 40 {
            index += 1
            candidate = "\(clean) \(index)"
        }
        return "Try \"\(candidate)\"."
    }
}

enum EnglishWeek {
    static let full = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let short = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static func name(forWeekday weekday: Int) -> String {
        guard (1...7).contains(weekday) else { return full[0] }
        return full[weekday - 1]
    }

    static func clock(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    static func minutes(_ value: Int) -> String {
        value == 1 ? "1 min" : "\(value) min"
    }

    static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum MinuteMath {
    static func roundedUp(from seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        return max(1, Int((Double(seconds) / 60.0).rounded(.up)))
    }
}
