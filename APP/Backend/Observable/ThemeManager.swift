import SwiftUI

enum AppTheme: Int, CaseIterable {
    case light
    case dark
    case system
}
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var selectedTheme: AppTheme = .system {
        didSet {
            updateUserInterfaceStyle()
        }
    }
    
    private init() {
        let savedTheme = UserDefaults.standard.integer(forKey: "selectedTheme")
        if let theme = AppTheme(rawValue: savedTheme) {
            self.selectedTheme = theme
        } else {
            self.selectedTheme = .system
        }
        updateUserInterfaceStyle()
    }
    
    var accentColor: Color {
        return .blue
    }
    
    var backgroundColor: Color {
        return selectedTheme == .dark ? ModernDarkColors.backgroundPrimary : .white
    }
    
    func updateUserInterfaceStyle() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                switch selectedTheme {
                case .light:
                    window.overrideUserInterfaceStyle = .light
                case .dark:
                    window.overrideUserInterfaceStyle = .dark
                case .system:
                    window.overrideUserInterfaceStyle = .unspecified
                }
            }
        }
        
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
        print("🎨 [ThemeManager] 主题已更新为: \(selectedTheme)")
    }
}

struct ModernDarkColors {
    static let backgroundPrimary = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let surfacePrimary = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let borderPrimary = Color(red: 0.24, green: 0.24, blue: 0.26)
}