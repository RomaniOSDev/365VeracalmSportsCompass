import SwiftUI
import UIKit

extension Color {
    static let bg = Color("AppBackground")
    static let surface = Color("AppSurface")
    static let brand = Color("AppPrimary")
    static let accentLane = Color("AppAccent")
    static let onBrand = Color("OnPrimary")
}

extension View {
    func trackBackdrop(_ image: String) -> some View {
        modifier(TrackBackdrop(image: image))
    }
}

private struct TrackBackdrop: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var image: String

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.primary)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Color.bg
                    .overlay {
                        Image(image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                            .clipped()
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        Color.bg.opacity(0.84)
                            .allowsHitTesting(false)
                    }
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [Color.brand.opacity(colorScheme == .dark ? 0.2 : 0.07), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 220)
                        .allowsHitTesting(false)
                    }
                    .clipped()
                    .ignoresSafeArea()
            }
    }
}

enum Keyboard {
    static func hide() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct KeyboardTapDismiss: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardTapAnchor {
        KeyboardTapAnchor()
    }

    func updateUIView(_ uiView: KeyboardTapAnchor, context: Context) {}
}

final class KeyboardTapAnchor: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }
        KeyboardDismissCenter.shared.install(on: window)
    }
}

final class KeyboardDismissCenter: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissCenter()

    private var installed = false

    func install(on window: UIWindow) {
        guard !installed else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        tap.name = "lane.keyboard.dismiss"
        window.addGestureRecognizer(tap)
        installed = true
    }

    @objc private func dismiss() {
        Keyboard.hide()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView || current.conforms(to: UITextInput.self) {
                return false
            }
            let name = NSStringFromClass(type(of: current))
            if name.contains("TextField") || name.contains("TextView") {
                return false
            }
            view = current.superview
        }
        return true
    }
}

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func phase() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

extension Notification.Name {
    static let dataReset = Notification.Name("dataReset")
}
