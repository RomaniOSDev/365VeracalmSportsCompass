import SwiftUI

struct RoutineListView: View {
    @EnvironmentObject private var store: DataStore
    @State private var creating = false
    @State private var pendingDelete: Routine?

    var body: some View {
        List {
            Section {
                PhotoBanner(name: "lane_morning", height: 140)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                if store.routines.isEmpty {
                    EmptyLane(
                        symbol: "plus.circle",
                        title: "No Routines Yet",
                        message: "Build a weekday list of exercises and their times."
                    )
                    .listRowBackground(Color.clear)
                }
            }
            Section {
                ForEach(store.routines) { routine in
                    NavigationLink(value: BoardRoute.routine(routine.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(routine.name)
                                .font(.headline)
                            Text("\(EnglishWeek.name(forWeekday: routine.weekday)) · \(routine.exercises.count) exercises\(routine.restSeconds > 0 ? " · \(routine.restSeconds)s rest" : "")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) { pendingDelete = routine }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .trackBackdrop("track_dusk")
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    creating = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("New Routine")
            }
        }
        .sheet(isPresented: $creating) {
            NavigationStack { RoutineEditor(existing: nil) }
        }
        .alert("Delete this routine?", isPresented: deletePresented) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    store.deleteRoutine(id: pendingDelete.id)
                }
                pendingDelete = nil
            }
        } message: {
            Text("The routine and its exercise list will be removed from this device.")
        }
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
}

struct RoutineDetailView: View {
    @EnvironmentObject private var store: DataStore
    let routineID: UUID
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var logMessage: String?
    @State private var showCopy = false
    @State private var copyWeekday = 2
    @State private var copyName = ""
    @State private var copyAttempted = false
    @State private var showRest = false
    @State private var restLength = 15

    private var routine: Routine? {
        store.routines.first(where: { $0.id == routineID })
    }

    var body: some View {
        Group {
            if let routine {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(routine.name)
                                .font(.title3.weight(.bold))
                            Text(EnglishWeek.name(forWeekday: routine.weekday))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(routine.restSeconds == 0 ? "No rest between exercises" : "\(routine.restSeconds) sec rest between exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ProgressView(value: fraction(routine))
                                .tint(Color.brand)
                            Text(progressText(routine))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(rowFill)
                    }
                    Section("Exercises") {
                        if routine.exercises.isEmpty {
                            Text("Add exercises to give this routine times.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(routine.exercises) { exercise in
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.headline)
                                    Text("\(exercise.durationSeconds) sec")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(store.isExerciseDone(exercise.id) ? "Undo" : "Mark done") {
                                    mark(exercise, in: routine)
                                }
                                .font(.subheadline.weight(.semibold))
                                .frame(minHeight: 44)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button(store.isExerciseDone(exercise.id) ? "Undo" : "Done") {
                                    mark(exercise, in: routine)
                                }
                                .tint(Color.brand)
                            }
                        }
                    }
                    Section {
                        Button("Log completed work") {
                            if store.logRoutine(routine) {
                                logMessage = "Added to your week log."
                                Haptics.success()
                            } else {
                                logMessage = "Mark at least one exercise before logging."
                            }
                        }
                        .frame(minHeight: 44)
                        if let logMessage {
                            Text(logMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        NavigationLink(value: BoardRoute.progress) {
                            Text("Open week log")
                        }
                        Button("Copy to another day") {
                            prepareCopy(routine)
                        }
                        .frame(minHeight: 44)
                        Button("Edit Routine") { editing = true }
                            .frame(minHeight: 44)
                        Button("Delete Routine", role: .destructive) { confirmDelete = true }
                            .frame(minHeight: 44)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .sheet(isPresented: $editing) {
                    NavigationStack { RoutineEditor(existing: routine) }
                }
                .sheet(isPresented: $showCopy) {
                    NavigationStack {
                        Form {
                            Picker("Day", selection: $copyWeekday) {
                                ForEach(1...7, id: \.self) { day in
                                    Text(EnglishWeek.name(forWeekday: day)).tag(day)
                                }
                            }
                            TextField("Name", text: $copyName)
                            if copyAttempted, let error = copyError(for: routine) {
                                FieldError(text: error)
                            }
                        }
                        .navigationTitle("Copy routine")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showCopy = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Copy") { commitCopy(routine) }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showRest) {
                    RestClockView(seconds: restLength)
                }
                .alert("Delete this routine?", isPresented: $confirmDelete) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        store.deleteRoutine(id: routine.id)
                    }
                } message: {
                    Text("The routine and its exercise list will be removed from this device.")
                }
            } else {
                Text("This routine was removed.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .trackBackdrop("track_dusk")
        .navigationTitle("Routine")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rowFill: some View {
        LinearGradient(colors: [Color.surface, Color.surface.opacity(0.9)], startPoint: .top, endPoint: .bottom)
    }

    private func fraction(_ routine: Routine) -> Double {
        guard !routine.exercises.isEmpty else { return 0 }
        let done = routine.exercises.filter { store.isExerciseDone($0.id) }.count
        return Double(done) / Double(routine.exercises.count)
    }

    private func progressText(_ routine: Routine) -> String {
        let done = routine.exercises.filter { store.isExerciseDone($0.id) }.count
        return "\(done) of \(routine.exercises.count) marked"
    }

    private func mark(_ exercise: ExerciseItem, in routine: Routine) {
        let wasDone = store.isExerciseDone(exercise.id)
        store.toggleExercise(exercise.id)
        guard !wasDone else { return }
        Haptics.success()
        guard routine.restSeconds > 0 else { return }
        guard let index = routine.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        guard index < routine.exercises.count - 1 else { return }
        restLength = routine.restSeconds
        showRest = true
    }

    private func prepareCopy(_ routine: Routine) {
        let next = routine.weekday == 7 ? 1 : routine.weekday + 1
        copyWeekday = next
        copyName = store.availableRoutineName(routine.name, weekday: next)
        copyAttempted = false
        showCopy = true
    }

    private func copyError(for routine: Routine) -> String? {
        let clean = NameCheck.trimmed(copyName)
        if clean.isEmpty { return "Enter a routine name." }
        let others = store.routines.filter { $0.weekday == copyWeekday }.map(\.name)
        if let suggestion = NameCheck.duplicateSuggestion(name: clean, existing: others) {
            return "That name is already used on this day. \(suggestion)"
        }
        if copyWeekday == routine.weekday && clean.compare(routine.name, options: .caseInsensitive) == .orderedSame {
            return "Pick another day or change the name."
        }
        return nil
    }

    private func commitCopy(_ routine: Routine) {
        copyAttempted = true
        guard copyError(for: routine) == nil else { return }
        store.copyRoutine(routine, to: copyWeekday, name: copyName)
        Haptics.success()
        showCopy = false
        logMessage = "Copied to \(EnglishWeek.name(forWeekday: copyWeekday))."
    }
}

struct RoutineEditor: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let existing: Routine?

    @State private var name: String
    @State private var weekday: Int
    @State private var restSeconds: Int
    @State private var exercises: [ExerciseItem]
    @State private var attempted = false

    init(existing: Routine?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        let today = Calendar.current.component(.weekday, from: Date())
        _weekday = State(initialValue: existing?.weekday ?? today)
        _restSeconds = State(initialValue: IntervalRules.snap(existing?.restSeconds ?? 0, to: IntervalRules.restChoices))
        let seed = existing?.exercises ?? [ExerciseItem(id: UUID(), name: "", durationSeconds: 30)]
        _exercises = State(initialValue: seed.map { item in
            var copy = item
            copy.durationSeconds = IntervalRules.snap(item.durationSeconds, to: IntervalRules.exerciseDurations)
            return copy
        })
    }

    var body: some View {
        Form {
            Section("Routine") {
                TextField("Routine name", text: $name)
                    .textInputAutocapitalization(.words)
                Picker("Day", selection: $weekday) {
                    ForEach(1...7, id: \.self) { day in
                        Text(EnglishWeek.name(forWeekday: day)).tag(day)
                    }
                }
                Picker("Rest between", selection: $restSeconds) {
                    ForEach(IntervalRules.restChoices, id: \.self) { value in
                        Text(value == 0 ? "No rest" : "\(value) sec").tag(value)
                    }
                }
                if attempted, let error = routineNameError {
                    FieldError(text: error)
                }
            }
            Section("Exercises") {
                ForEach($exercises) { $exercise in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Exercise name", text: $exercise.name)
                        Picker("Duration", selection: $exercise.durationSeconds) {
                            ForEach(IntervalRules.exerciseDurations, id: \.self) { value in
                                Text("\(value) sec").tag(value)
                            }
                        }
                        if attempted, let error = exerciseError(exercise) {
                            FieldError(text: error)
                        }
                        HStack {
                            Button("Move Up") { shift(exercise.id, by: -1) }
                            Button("Move Down") { shift(exercise.id, by: 1) }
                            Spacer()
                            Button("Remove", role: .destructive) {
                                exercises.removeAll { $0.id == exercise.id }
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                    }
                    .padding(.vertical, 4)
                }
                Button("Add Exercise") {
                    exercises.append(ExerciseItem(id: UUID(), name: "", durationSeconds: 30))
                }
                .frame(minHeight: 44)
                if attempted && exercises.isEmpty {
                    FieldError(text: "Add at least one exercise.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .trackBackdrop("track_dusk")
        .navigationTitle(existing == nil ? "New Routine" : "Edit Routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
    }

    private var routineNameError: String? {
        let clean = NameCheck.trimmed(name)
        if clean.isEmpty { return "Enter a routine name." }
        let others = store.routines.filter { $0.id != existing?.id && $0.weekday == weekday }.map(\.name)
        if let suggestion = NameCheck.duplicateSuggestion(name: clean, existing: others) {
            return "That name is already used. \(suggestion)"
        }
        return nil
    }

    private func exerciseError(_ exercise: ExerciseItem) -> String? {
        let clean = NameCheck.trimmed(exercise.name)
        if clean.isEmpty { return "Enter an exercise name." }
        let others = exercises.filter { $0.id != exercise.id }.map(\.name)
        if let suggestion = NameCheck.duplicateSuggestion(name: clean, existing: others) {
            return "Duplicate name. \(suggestion)"
        }
        if !IntervalRules.exerciseDurations.contains(exercise.durationSeconds) {
            return "Choose a duration from the list."
        }
        return nil
    }

    private func shift(_ id: UUID, by delta: Int) {
        guard let index = exercises.firstIndex(where: { $0.id == id }) else { return }
        let target = index + delta
        guard exercises.indices.contains(target) else { return }
        exercises.swapAt(index, target)
    }

    private func save() {
        attempted = true
        guard routineNameError == nil else { return }
        guard !exercises.isEmpty else { return }
        guard exercises.allSatisfy({ exerciseError($0) == nil }) else { return }
        let routine = Routine(
            id: existing?.id ?? UUID(),
            name: NameCheck.trimmed(name),
            weekday: weekday,
            exercises: exercises.map {
                ExerciseItem(id: $0.id, name: NameCheck.trimmed($0.name), durationSeconds: $0.durationSeconds)
            },
            restSeconds: restSeconds
        )
        store.saveRoutine(routine, isNew: existing == nil)
        Haptics.success()
        dismiss()
    }
}

struct RestClockView: View {
    let seconds: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var clock = SecondClock()
    @State private var remaining: Int
    @State private var endsAt: Date?
    @State private var running = false
    @State private var warned = false
    @State private var finished = false

    init(seconds: Int) {
        let length = max(1, seconds)
        self.seconds = length
        _remaining = State(initialValue: length)
    }

    private var finalStretch: Bool {
        running && seconds > 3 && remaining <= 3 && remaining > 0
    }

    private var progress: Double {
        Double(max(0, seconds - remaining)) / Double(seconds)
    }

    var body: some View {
        VStack(spacing: 18) {
            SplitRing(progress: finished ? 1 : progress, tint: finalStretch ? .orange : .brand)
                .frame(width: 200, height: 200)
            Text(finished ? "Done" : EnglishWeek.clock(remaining))
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
            Text(finalStretch ? "Get ready" : "REST")
                .font(.headline)
            Text("Rest before the next exercise. The clock pauses if you leave the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !finished {
                FillButton(title: running ? "Pause" : "Resume", systemImage: running ? "pause.fill" : "play.fill") {
                    if running {
                        pause(now: Date())
                    } else {
                        resume(now: Date())
                    }
                }
            }
            QuietButton(title: "Skip rest") { dismiss() }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trackBackdrop("track_dusk")
        .onAppear { resume(now: Date()) }
        .onDisappear { clock.stop() }
        .onChange(of: clock.now) { date in
            sync(now: date)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                pause(now: Date())
            }
        }
    }

    private func resume(now: Date) {
        guard !finished else { return }
        endsAt = now.addingTimeInterval(TimeInterval(max(remaining, 1)))
        running = true
        clock.start()
    }

    private func pause(now: Date) {
        guard running, let endsAt else { return }
        let left = endsAt.timeIntervalSince(now)
        if left <= 0 {
            complete()
            return
        }
        remaining = max(1, Int(ceil(left)))
        running = false
        self.endsAt = nil
        clock.stop()
    }

    private func sync(now: Date) {
        guard running, !finished, let endsAt else { return }
        if now < endsAt {
            let next = max(1, Int(ceil(endsAt.timeIntervalSince(now))))
            guard next != remaining else { return }
            remaining = next
            if finalStretch && !warned {
                warned = true
                Haptics.phase()
            }
            return
        }
        complete()
    }

    private func complete() {
        guard !finished else { return }
        finished = true
        running = false
        remaining = 0
        endsAt = nil
        clock.stop()
        Haptics.success()
        dismiss()
    }
}
