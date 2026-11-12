import SwiftUI
import UIKit

// MARK: - User themes

struct MishTheme: Identifiable, Codable, Equatable {
    enum BackgroundMotion: String, CaseIterable, Identifiable, Codable {
        case none
        case scrolling
        case parallax

        var id: String { rawValue }

        var title: String {
            switch self {
            case .none: return "Still"
            case .scrolling: return "Slow scrolling"
            case .parallax: return "Tilt parallax"
            }
        }

        var subtitle: String {
            switch self {
            case .none: return "A stationary background"
            case .scrolling: return "The background drifts gently"
            case .parallax: return "The background responds to device movement"
            }
        }
    }

    var id: UUID
    var name: String
    var accentHex: UInt32
    var mainHex: UInt32
    var backgroundHex: UInt32
    var overlayOpacity: Double
    var blurEnabled: Bool
    var blurRadius: Double
    var overridesAlbumArtBlur: Bool
    var backgroundImageFilename: String?
    var motion: BackgroundMotion

    static var starter: MishTheme {
        MishTheme(
            id: UUID(),
            name: "Mish Default",
            accentHex: 0xA6E3A1,
            mainHex: 0xFFFFFF,
            backgroundHex: 0x101014,
            overlayOpacity: 0.22,
            blurEnabled: true,
            blurRadius: 55,
            overridesAlbumArtBlur: false,
            backgroundImageFilename: nil,
            motion: .none
        )
    }

    var accentColor: Color { Color(hex: accentHex) }
    var mainColor: Color { Color(hex: mainHex) }
    var backgroundColor: Color { Color(hex: backgroundHex) }
}

@MainActor
final class MishThemeStore: ObservableObject {
    @Published private(set) var themes: [MishTheme] = []
    @Published var activeThemeID: UUID? {
        didSet { persist() }
    }

    private let defaultsKey = "mish.customThemes.v1"
    private let activeKey = "mish.activeCustomTheme.v1"

    init() {
        load()
    }

    var activeTheme: MishTheme {
        if let id = activeThemeID,
           let theme = themes.first(where: { $0.id == id }) {
            return theme
        }
        return themes.first ?? .starter
    }

    @discardableResult
    func createTheme() -> UUID {
        var theme = MishTheme.starter
        theme.id = UUID()
        theme.name = "My Theme \(themes.count + 1)"
        themes.append(theme)
        activeThemeID = theme.id
        persist()
        return theme.id
    }

    func update(_ theme: MishTheme) {
        guard let index = themes.firstIndex(where: { $0.id == theme.id }) else { return }
        themes[index] = theme
        persist()
    }

    func select(_ id: UUID) {
        guard themes.contains(where: { $0.id == id }) else { return }
        activeThemeID = id
    }

    func delete(_ id: UUID) {
        guard themes.count > 1 else { return }
        themes.removeAll { $0.id == id }
        if activeThemeID == id {
            activeThemeID = themes.first?.id
        }
        removeBackgroundImage(for: id)
        persist()
    }

    func backgroundImageURL(for theme: MishTheme) -> URL? {
        guard let filename = theme.backgroundImageFilename else { return nil }
        let url = themeDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    @discardableResult
    func setBackgroundImage(_ data: Data, for themeID: UUID) -> Bool {
        guard let index = themes.firstIndex(where: { $0.id == themeID }),
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.92) else {
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: themeDirectory,
                withIntermediateDirectories: true
            )
            let filename = "\(themeID.uuidString).jpg"
            try jpeg.write(to: themeDirectory.appendingPathComponent(filename), options: .atomic)
            themes[index].backgroundImageFilename = filename
            persist()
            return true
        } catch {
            print("Mish theme image save failed:", error)
            return false
        }
    }

    func clearBackgroundImage(for themeID: UUID) {
        guard let index = themes.firstIndex(where: { $0.id == themeID }) else { return }
        if let filename = themes[index].backgroundImageFilename {
            try? FileManager.default.removeItem(at: themeDirectory.appendingPathComponent(filename))
        }
        themes[index].backgroundImageFilename = nil
        persist()
    }

    private var themeDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("MishThemes", isDirectory: true)
    }

    private func removeBackgroundImage(for id: UUID) {
        try? FileManager.default.removeItem(at: themeDirectory.appendingPathComponent("\(id.uuidString).jpg"))
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([MishTheme].self, from: data),
           !decoded.isEmpty {
            themes = decoded
        } else {
            themes = [.starter]
        }

        if let rawID = UserDefaults.standard.string(forKey: activeKey),
           let id = UUID(uuidString: rawID),
           themes.contains(where: { $0.id == id }) {
            activeThemeID = id
        } else {
            activeThemeID = themes.first?.id
        }
        persist()
    }

    private func persist() {
        guard !themes.isEmpty,
              let data = try? JSONEncoder().encode(themes) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
        UserDefaults.standard.set(activeThemeID?.uuidString, forKey: activeKey)
    }
}

extension Color {
    init(mishHex: UInt32) {
        self.init(
            .sRGB,
            red: Double((mishHex >> 16) & 0xFF) / 255,
            green: Double((mishHex >> 8) & 0xFF) / 255,
            blue: Double(mishHex & 0xFF) / 255,
            opacity: 1
        )
    }

    var mishHex: UInt32 {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (UInt32(red * 255) << 16)
            | (UInt32(green * 255) << 8)
            | UInt32(blue * 255)
    }
}
