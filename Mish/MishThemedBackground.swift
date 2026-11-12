import SwiftUI
import CoreMotion

/// Renders a user's selected background. A theme can replace album-art blur,
/// while the original background settings remain in control when override is off.
struct MishThemedBackground: View {
    let artwork: UIImage?
    let fallbackTheme: MishBaseTheme
    let albumBlurEnabled: Bool
    let albumBlurRadius: Double
    @EnvironmentObject private var themeStore: MishThemeStore

    @StateObject private var motion = MishDeviceMotion()
    @State private var scrollPhase = false

    private var theme: MishTheme { themeStore.activeTheme }
    private var customImageURL: URL? { themeStore.backgroundImageURL(for: theme) }

    private var effectiveBlurEnabled: Bool {
        theme.overridesAlbumArtBlur ? theme.blurEnabled : albumBlurEnabled
    }

    private var effectiveBlurRadius: Double {
        theme.overridesAlbumArtBlur ? theme.blurRadius : albumBlurRadius
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                theme.backgroundColor

                if let url = customImageURL,
                   let image = UIImage(contentsOfFile: url.path) {
                    backgroundImage(
                        image,
                        size: geometry.size,
                        blurEnabled: theme.blurEnabled,
                        blurRadius: theme.blurRadius
                    )
                } else if let artwork, fallbackTheme != .amoled {
                    backgroundImage(
                        artwork,
                        size: geometry.size,
                        blurEnabled: effectiveBlurEnabled,
                        blurRadius: effectiveBlurRadius
                    )
                } else {
                    fallbackGradient
                }

                if customImageURL == nil && artwork == nil {
                    theme.backgroundColor.opacity(theme.overlayOpacity * 0.35)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            if theme.motion == .scrolling {
                withAnimation(.linear(duration: 34).repeatForever(autoreverses: false)) {
                    scrollPhase = true
                }
            }
            if theme.motion == .parallax { motion.start() }
        }
        .onChange(of: theme.motion) { _, newValue in
            scrollPhase = false
            motion.stop()
            if newValue == .scrolling {
                withAnimation(.linear(duration: 34).repeatForever(autoreverses: false)) {
                    scrollPhase = true
                }
            } else if newValue == .parallax {
                motion.start()
            }
        }
        .onDisappear { motion.stop() }
    }

    @ViewBuilder
    private func backgroundImage(
        _ image: UIImage,
        size: CGSize,
        blurEnabled: Bool,
        blurRadius: Double
    ) -> some View {
        let scale: CGFloat = theme.motion == .none ? 1.04 : 1.22
        let offsetX: CGFloat = theme.motion == .parallax
            ? CGFloat(motion.roll) * 24
            : (theme.motion == .scrolling && scrollPhase ? -22 : 22)
        let offsetY: CGFloat = theme.motion == .parallax
            ? CGFloat(motion.pitch) * 24
            : (theme.motion == .scrolling && scrollPhase ? 18 : -18)

        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(scale)
            .offset(x: offsetX, y: offsetY)
            .blur(radius: blurEnabled ? blurRadius : 0)
            .overlay(theme.backgroundColor.opacity(theme.overlayOpacity))
            .clipped()
            .animation(.easeOut(duration: 0.18), value: motion.roll)
            .animation(.easeOut(duration: 0.18), value: motion.pitch)
    }

    @ViewBuilder
    private var fallbackGradient: some View {
        switch fallbackTheme {
        case .smoked:
            LinearGradient(
                colors: [Color(white: 0.17), theme.backgroundColor],
                startPoint: .top,
                endPoint: .bottom
            )
        case .amoled:
            Color.black
        case .clear:
            LinearGradient(
                colors: [theme.accentColor.opacity(0.3), theme.backgroundColor, .purple.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(.ultraThinMaterial)
        }
    }
}

@MainActor
private final class MishDeviceMotion: ObservableObject {
    @Published private(set) var roll: Double = 0
    @Published private(set) var pitch: Double = 0

    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            self?.roll = min(max(data.attitude.roll, -0.7), 0.7)
            self?.pitch = min(max(data.attitude.pitch, -0.7), 0.7)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
