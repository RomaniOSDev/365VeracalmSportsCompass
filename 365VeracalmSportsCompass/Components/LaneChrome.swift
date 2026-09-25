import SwiftUI

struct PhotoBanner: View {
    let name: String
    var height: CGFloat = 156

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                GeometryReader { proxy in
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                .allowsHitTesting(false)
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.38), Color.white.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 10, y: 6)
            .accessibilityHidden(true)
    }
}

struct LanePlate<Content: View>: View {
    var rail: Color = .brand
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [rail, Color.accentLane.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 8)
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            LinearGradient(
                colors: [Color.surface, Color.surface.opacity(0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 8, y: 4)
    }
}

struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.brand)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            LinearGradient(
                colors: [Color.surface, Color.bg.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 6, y: 3)
    }
}

struct FillButton: View {
    let title: String
    var systemImage: String?
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(Color.onBrand)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background {
                LinearGradient(
                    colors: [Color.brand, Color.accentLane],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.brand.opacity(enabled ? 0.3 : 0), radius: 8, y: 4)
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

struct QuietButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.brand.opacity(0.45), lineWidth: 1.5)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.84 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
    }
}

struct EmptyLane: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(Color.brand)
                .frame(width: 68, height: 68)
                .background {
                    LinearGradient(
                        colors: [Color.brand.opacity(0.22), Color.accentLane.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipShape(Circle())
                .shadow(color: Color.brand.opacity(0.22), radius: 8, y: 3)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct SplitRing: View {
    var progress: Double
    var tint: Color = .brand

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 14)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(
                    LinearGradient(colors: [tint, Color.accentLane], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .shadow(color: tint.opacity(0.22), radius: 8, y: 3)
        .accessibilityHidden(true)
    }
}

struct WeekChart: View {
    let totals: [Int]
    let labels: [String]
    var onSelect: ((Int) -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let safe = totals.count == 7 ? totals : Array(repeating: 0, count: 7)
        let peak = max(safe.max() ?? 0, 1)
        VStack(spacing: 8) {
            GeometryReader { geo in
                let gap: CGFloat = 8
                let barWidth = max(10, (geo.size.width - gap * 6) / 7)
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(0..<7, id: \.self) { index in
                        let ratio = CGFloat(safe[index]) / CGFloat(peak)
                        let height = max(8, (geo.size.height - 2) * (safe[index] == 0 ? 0.08 : ratio))
                        Button {
                            onSelect?(index)
                        } label: {
                            barColumn(width: barWidth, height: height)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(labels[index]), \(EnglishWeek.minutes(safe[index]))")
                    }
                }
            }
            .frame(height: 150)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: safe)

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    Text(labels.indices.contains(index) ? labels[index] : "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                }
            }
        }
    }

    private func barColumn(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Path { path in
                path.addRoundedRect(
                    in: CGRect(x: 0, y: 0, width: width, height: height),
                    cornerSize: CGSize(width: 4, height: 4)
                )
            }
            .fill(
                LinearGradient(
                    colors: [Color.brand, Color.accentLane],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)
        }
    }
}

struct TrendChart: View {
    let values: [Int]
    let labels: [String]

    var body: some View {
        let series = values.isEmpty ? [0] : values
        let peak = max(series.max() ?? 0, 1)
        VStack(spacing: 8) {
            Canvas { context, size in
                guard series.count > 1 else { return }
                var line = Path()
                var fill = Path()
                let step = size.width / CGFloat(series.count - 1)
                for index in series.indices {
                    let x = CGFloat(index) * step
                    let y = size.height - (CGFloat(series[index]) / CGFloat(peak)) * (size.height - 6) - 3
                    let point = CGPoint(x: x, y: y)
                    if index == 0 {
                        line.move(to: point)
                        fill.move(to: CGPoint(x: x, y: size.height))
                        fill.addLine(to: point)
                    } else {
                        line.addLine(to: point)
                        fill.addLine(to: point)
                    }
                }
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.closeSubpath()
                context.fill(fill, with: .linearGradient(
                    Gradient(colors: [Color.brand.opacity(0.35), Color.brand.opacity(0.02)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
                context.stroke(line, with: .color(Color.brand), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 140)
            HStack(spacing: 4) {
                ForEach(labels.indices, id: \.self) { index in
                    Text(labels[index])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(series))
    }

    private func accessibilityText(_ series: [Int]) -> String {
        let total = series.reduce(0, +)
        return "Last \(series.count) weeks, \(EnglishWeek.minutes(total))"
    }
}

struct FieldError: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.circle")
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
