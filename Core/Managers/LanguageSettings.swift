import Foundation
import SwiftUI
import ObjectiveC

private var languageBundleKey: UInt8 = 0

private final class LocalizedBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &languageBundleKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }

        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case en = "en"
    case ar = "ar"
    case ur = "ur"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    public var id: String { rawValue }

    public var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        default:
            return rawValue
        }
    }

    public var isRTL: Bool {
        switch self {
        case .ar, .ur:
            return true
        default:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .en: return "English"
        case .ar: return "Arabic"
        case .ur: return "Urdu"
        case .zhHans: return "Chinese (Simplified)"
        case .zhHant: return "Chinese (Traditional)"
        }
    }
}

public enum LanguageSettings {
    public static let selectedLanguageKey = "AppSelectedLanguage"
    public static let appleLanguagesKey = "AppleLanguages"

     public static func current() -> AppLanguage {
         currentLanguage()
     }

     public static func set(_ language: AppLanguage) {
         setLanguage(language)
     }

    public static func currentLanguage() -> AppLanguage {
        let stored = UserDefaults.standard.string(forKey: selectedLanguageKey)
        return AppLanguage(rawValue: stored ?? AppLanguage.system.rawValue) ?? .system
    }

    public static func setLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: selectedLanguageKey)

        if language == .system {
            UserDefaults.standard.removeObject(forKey: appleLanguagesKey)
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: appleLanguagesKey)
        }

        UserDefaults.standard.synchronize()

        applyRuntimeLanguage()
        NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
    }

    public static func applyRuntimeLanguage() {
        object_setClass(Bundle.main, LocalizedBundle.self)

        if currentLanguage() == .system {
            objc_setAssociatedObject(Bundle.main, &languageBundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }

        let langBundle = bundle()
        objc_setAssociatedObject(Bundle.main, &languageBundleKey, langBundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    public static func bundle() -> Bundle {
        let lang = currentLanguage()
        guard lang != .system else { return .main }

        if let path = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        if let basePath = Bundle.main.path(forResource: "Base", ofType: "lproj"),
           let baseBundle = Bundle(path: basePath) {
            return baseBundle
        }

        return .main
    }

    public static func isUsingSystemLanguage() -> Bool {
        currentLanguage() == .system
    }
}

public extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("app.language.didChange")
}

public extension String {
    var localized: String {
        NSLocalizedString(self, tableName: nil, bundle: .main, value: self, comment: "")
    }

    func localized(tableName: String? = nil, bundle: Bundle = .main) -> String {
        NSLocalizedString(self, tableName: tableName, bundle: bundle, value: self, comment: "")
    }
}

 public struct LanguagePickerView: View {
     @State private var selected = LanguageSettings.current()
     @State private var showRestartAlert = false

     public init() {}

     public var body: some View {
         Form {
             Section(header: Text("settings.language".localized)) {
                 ForEach(AppLanguage.allCases) { lang in
                     Button {
                         apply(lang)
                     } label: {
                         HStack {
                             Text(displayName(for: lang))
                             Spacer()
                             if selected == lang {
                                 Image(systemName: "checkmark")
                             }
                         }
                     }
                 }
             }
         }
         .alert("language.restart.title".localized, isPresented: $showRestartAlert) {
             Button("common.ok".localized, role: .cancel) { }
         } message: {
             Text("language.restart.message".localized)
         }
     }

     private func apply(_ lang: AppLanguage) {
         guard lang != selected else { return }
         selected = lang
         LanguageSettings.set(lang)
         showRestartAlert = true
     }

     private func displayName(for lang: AppLanguage) -> String {
         lang.displayName
     }
 }
