import SwiftUI

struct IntervalListView: View {
    @EnvironmentObject private var store: DataStore
    @State private var editor: IntervalPreset?
    @State private var creating = false
    @State private var pendingDelete: IntervalPreset?

    var body: some View {
        List {
            Section {
                PhotoBanner(name: "gym_floor", height: 140)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                if store.presets.isEmpty {
                    EmptyLane(
                        symbol: "calendar.badge.plus",
                        title: "No Interval Sessions Yet",
                        message: "Save a work and rest pattern, then start the clock."
                    )
                    .listRowBackground(Color.clear)
                }
            }
            Section {
                ForEach(store.presets) { preset in
                    NavigationLink(value: BoardRoute.interval(preset.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.headline)
                            Text("Work \(preset.workSeconds) sec · Rest \(preset.restSeconds) sec · \(preset.rounds) rounds")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            pendingDelete = preset
                        }
                    }
                    .contextMenu {
                        Button("Move Up") { store.shiftPreset(id: preset.id, delta: -1) }
                        Button("Move Down") { store.shiftPreset(id: preset.id, delta: 1) }
                        Button("Edit") { editor = preset }
                        Button("Delete", role: .destructive) { pendingDelete = preset }
                    }
                }
                .onMove(perform: store.movePresets)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .trackBackdrop("track_dusk")
        .navigationTitle("Intervals")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    creating = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("New Session")
            }
        }
        .sheet(isPresented: $creating) {
            NavigationStack { IntervalEditor(existing: nil) }
        }
        .sheet(item: $editor) { preset in
            NavigationStack { IntervalEditor(existing: preset) }
        }
        .alert("Delete this session?", isPresented: deletePresented) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    store.deletePreset(id: pendingDelete.id)
                }
                pendingDelete = nil
            }
        } message: {
            Text("The saved work and rest pattern will be removed from this device.")
        }
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
}

struct IntervalDetailView: View {
    @EnvironmentObject private var store: DataStore
    let presetID: UUID
    @State private var editing = false
    @State private var confirmDelete = false

    private var preset: IntervalPreset? {
        store.presets.first(where: { $0.id == presetID })
    }

    var body: some View {
        Group {
            if let preset {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PhotoBanner(name: "gym_floor", height: 120)
                        LanePlate {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(preset.name)
                                    .font(.title2.weight(.bold))
                                readout(preset)
                            }
                        }
                        NavigationLink(value: BoardRoute.runner(preset.id)) {
                            Text("Start")
                                .font(.headline)
                                .foregroundStyle(Color.onBrand)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                                .background {
                                    LinearGradient(colors: [Color.brand, Color.accentLane], startPoint: .topLeading, endPoint: .bottomTrailing)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: Color.brand.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        QuietButton(title: "Edit", systemImage: "slider.horizontal.3") { editing = true }
                        HStack(spacing: 12) {
                            QuietButton(title: "Move Up") { store.shiftPreset(id: preset.id, delta: -1) }
                            QuietButton(title: "Move Down") { store.shiftPreset(id: preset.id, delta: 1) }
                        }
                        Button("Delete Session", role: .destructive) { confirmDelete = true }
                            .frame(minHeight: 44)
                    }
                    .padding(16)
                }
                .sheet(isPresented: $editing) {
                    NavigationStack { IntervalEditor(existing: preset) }
                }
                .alert("Delete this session?", isPresented: $confirmDelete) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        store.deletePreset(id: preset.id)
                    }
                } message: {
                    Text("The saved work and rest pattern will be removed from this device.")
                }
            } else {
                Text("This session was removed.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .trackBackdrop("track_dusk")
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func readout(_ preset: IntervalPreset) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            StatTile(title: "Work", value: "\(preset.workSeconds)s")
            StatTile(title: "Rest", value: "\(preset.restSeconds)s")
            StatTile(title: "Rounds", value: "\(preset.rounds)")
        }
    }
}

struct IntervalEditor: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let existing: IntervalPreset?

    @State private var name: String
    @State private var workSeconds: Int
    @State private var restSeconds: Int
    @State private var rounds: Int
    @State private var attempted = false

    init(existing: IntervalPreset?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _workSeconds = State(initialValue: IntervalRules.snap(existing?.workSeconds ?? 30, to: IntervalRules.workChoices))
        _restSeconds = State(initialValue: IntervalRules.snap(existing?.restSeconds ?? 15, to: IntervalRules.restChoices))
        _rounds = State(initialValue: IntervalRules.snap(existing?.rounds ?? 8, to: IntervalRules.roundChoices))
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Session name", text: $name)
                    .textInputAutocapitalization(.words)
                if attempted, let error = nameError {
                    FieldError(text: error)
                }
            }
            Section("Pattern") {
                Picker("Work", selection: $workSeconds) {
                    ForEach(IntervalRules.workChoices, id: \.self) { value in
                        Text("\(value) sec").tag(value)
                    }
                }
                Picker("Rest", selection: $restSeconds) {
                    ForEach(IntervalRules.restChoices, id: \.self) { value in
                        Text(value == 0 ? "No rest" : "\(value) sec").tag(value)
                    }
                }
                Picker("Rounds", selection: $rounds) {
                    ForEach(IntervalRules.roundChoices, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .trackBackdrop("track_dusk")
        .navigationTitle(existing == nil ? "New Session" : "Edit Session")
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

    private var nameError: String? {
        let clean = NameCheck.trimmed(name)
        if clean.isEmpty { return "Enter a session name." }
        let others = store.presets.filter { $0.id != existing?.id }.map(\.name)
        if let suggestion = NameCheck.duplicateSuggestion(name: clean, existing: others) {
            return "That name is already used. \(suggestion)"
        }
        return nil
    }

    private func save() {
        attempted = true
        guard nameError == nil else { return }
        let preset = IntervalPreset(
            id: existing?.id ?? UUID(),
            name: NameCheck.trimmed(name),
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            rounds: rounds
        )
        store.savePreset(preset, isNew: existing == nil)
        Haptics.success()
        dismiss()
    }
}

final class SecondClock: ObservableObject {
    @Published private(set) var now = Date()
    private var timer: Timer?
    private var lastSecond = -1

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let next = Date()
            let second = Int(next.timeIntervalSinceReferenceDate)
            guard second != self.lastSecond else { return }
            self.lastSecond = second
            self.now = next
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastSecond = -1
    }

    deinit {
        timer?.invalidate()
    }
}

struct RunnerClock {
    enum Phase: Equatable { case work, rest, finished }

    var preset: IntervalPreset
    var round = 1
    var phase: Phase = .work
    var remaining: Int
    var running = false
    var segmentEndsAt: Date?
    var didWarnPhase = false
    var pendingWarn = false

    var isFinalStretch: Bool {
        running && phase != .finished && phaseLength > 3 && remaining <= 3 && remaining > 0
    }

    init(preset: IntervalPreset) {
        self.preset = preset
        remaining = max(1, preset.workSeconds)
    }

    var phaseLength: Int {
        switch phase {
        case .work: return max(1, preset.workSeconds)
        case .rest: return max(1, preset.restSeconds)
        case .finished: return 1
        }
    }

    var progress: Double {
        Double(phaseLength - remaining) / Double(phaseLength)
    }

    var workElapsed: Int {
        switch phase {
        case .finished:
            return preset.workSeconds * preset.rounds
        case .rest:
            return preset.workSeconds * min(round, preset.rounds)
        case .work:
            let doneRounds = max(0, round - 1)
            let into = max(0, preset.workSeconds - remaining)
            return doneRounds * preset.workSeconds + into
        }
    }

    mutating func applyRunning(_ isRunning: Bool, now: Date) {
        guard phase != .finished, isRunning != running else { return }
        if isRunning {
            segmentEndsAt = now.addingTimeInterval(TimeInterval(max(remaining, 1)))
            running = true
            return
        }
        if let end = segmentEndsAt, end.timeIntervalSince(now) <= 0 {
            advance(now: now, keepRunning: false)
            return
        }
        if let end = segmentEndsAt {
            remaining = max(1, Int(ceil(end.timeIntervalSince(now))))
        }
        running = false
        segmentEndsAt = nil
    }

    mutating func sync(now: Date) -> Bool {
        pendingWarn = false
        guard running, phase != .finished, let end = segmentEndsAt else { return false }
        if now < end {
            let next = max(1, Int(ceil(end.timeIntervalSince(now))))
            let changed = next != remaining
            remaining = next
            let warned = markWarning()
            return changed || warned
        }
        advance(now: now, keepRunning: true)
        if phase != .finished {
            _ = markWarning()
        }
        return true
    }

    mutating func markWarning() -> Bool {
        guard isFinalStretch, !didWarnPhase else { return false }
        didWarnPhase = true
        pendingWarn = true
        return true
    }

    mutating func advance(now: Date, keepRunning: Bool) {
        switch phase {
        case .work:
            if round < preset.rounds && preset.restSeconds > 0 {
                phase = .rest
                remaining = preset.restSeconds
            } else if round < preset.rounds {
                round += 1
                phase = .work
                remaining = preset.workSeconds
            } else {
                finish()
                return
            }
        case .rest:
            if round < preset.rounds {
                round += 1
                phase = .work
                remaining = preset.workSeconds
            } else {
                finish()
                return
            }
        case .finished:
            finish()
            return
        }
        didWarnPhase = false
        pendingWarn = false
        running = keepRunning
        segmentEndsAt = keepRunning ? now.addingTimeInterval(TimeInterval(remaining)) : nil
    }

    mutating func finish() {
        phase = .finished
        running = false
        remaining = 0
        segmentEndsAt = nil
    }
}

struct IntervalRunnerView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let presetID: UUID

    @StateObject private var clock = SecondClock()
    @State private var runner: RunnerClock?
    @State private var didLog = false
    @State private var askClose = false

    private var preset: IntervalPreset? {
        store.presets.first(where: { $0.id == presetID })
    }

    var body: some View {
        Group {
            if let preset {
                runnerBody(preset)
            } else {
                Text("This session was removed.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .trackBackdrop("track_dusk")
        .navigationTitle("Clock")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") { attemptClose() }
            }
        }
        .onAppear {
            if runner == nil, let preset {
                runner = RunnerClock(preset: preset)
                store.markPresetUsed(preset.id)
            }
        }
        .onChange(of: clock.now) { date in
            sync(now: date)
        }
        .onDisappear {
            setRunning(false)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                setRunning(false)
            }
        }
        .alert("Leave this clock?", isPresented: $askClose) {
            Button("Keep Going", role: .cancel) {}
            Button("Save Partial") {
                commit(finished: false)
                dismiss()
            }
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("You can save the work already counted, or leave without a log.")
        }
    }

    private func runnerBody(_ preset: IntervalPreset) -> some View {
        let clock = runner ?? RunnerClock(preset: preset)
        return ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    SplitRing(progress: clock.phase == .finished ? 1 : clock.progress, tint: clock.isFinalStretch ? .orange : (clock.phase == .rest ? .orange : .brand))
                        .frame(width: 230, height: 230)
                    VStack(spacing: 4) {
                        Text(clock.phase == .finished ? "Done" : EnglishWeek.clock(clock.remaining))
                            .font(.largeTitle.weight(.bold))
                            .monospacedDigit()
                        Text(clock.isFinalStretch ? "Get ready" : phaseTitle(clock))
                            .font(.headline)
                    }
                }
                .padding(.top, 12)
                LanePlate(rail: clock.phase == .rest ? .orange : .brand) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(preset.name)
                            .font(.headline)
                        Text("Round \(min(clock.round, preset.rounds)) of \(preset.rounds)")
                            .font(.subheadline)
                        Text("Work \(preset.workSeconds) sec · Rest \(preset.restSeconds) sec")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("The clock pauses if you leave the app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if clock.phase == .finished {
                    Text("Logged to this week.")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    NavigationLink(value: BoardRoute.progress) {
                        Text("Open week log")
                            .font(.headline)
                            .foregroundStyle(Color.onBrand)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background {
                                LinearGradient(colors: [Color.brand, Color.accentLane], startPoint: .leading, endPoint: .trailing)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    FillButton(
                        title: runTitle(clock),
                        systemImage: clock.running ? "pause.fill" : "play.fill"
                    ) {
                        setRunning(!(runner?.running ?? false))
                    }
                    QuietButton(title: "Stop", systemImage: "stop.fill") {
                        setRunning(false)
                        if (runner?.workElapsed ?? 0) > 0 {
                            askClose = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .padding(16)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: clock.phase)
    }

    private func phaseTitle(_ clock: RunnerClock) -> String {
        switch clock.phase {
        case .work: return "WORK"
        case .rest: return "REST"
        case .finished: return "COMPLETE"
        }
    }

    private func runTitle(_ clock: RunnerClock) -> String {
        if clock.running { return "Pause" }
        if clock.phase == .work && clock.round == 1 && clock.remaining == max(1, clock.preset.workSeconds) {
            return "Start"
        }
        return "Resume"
    }

    private func sync(now: Date) {
        guard var current = runner, current.running else { return }
        let beforePhase = current.phase
        guard current.sync(now: now) else { return }
        let finishedNow = current.phase == .finished && beforePhase != .finished
        let warn = current.pendingWarn
        runner = current
        if warn {
            Haptics.phase()
        } else if current.phase != beforePhase {
            Haptics.phase()
        }
        if finishedNow {
            commit(finished: true)
        }
        if !current.running {
            clock.stop()
        }
    }

    private func commit(finished: Bool) {
        guard !didLog, var clock = runner, clock.workElapsed > 0 else { return }
        didLog = true
        clock.running = false
        if finished {
            clock.phase = .finished
            clock.remaining = 0
        }
        runner = clock
        store.logInterval(preset: clock.preset, workSecondsElapsed: clock.workElapsed, finished: finished)
        Haptics.success()
    }

    private func setRunning(_ isRunning: Bool) {
        if runner == nil, let preset {
            runner = RunnerClock(preset: preset)
            store.markPresetUsed(preset.id)
        }
        guard var current = runner else { return }
        current.applyRunning(isRunning, now: Date())
        runner = current
        if current.running {
            clock.start()
        } else {
            clock.stop()
        }
    }

    private func attemptClose() {
        if didLog || runner?.phase == .finished {
            dismiss()
            return
        }
        setRunning(false)
        if (runner?.workElapsed ?? 0) > 0 {
            askClose = true
        } else {
            dismiss()
        }
    }
}
