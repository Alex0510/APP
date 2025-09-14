import Foundation
import UIKit

extension Bundle {
    var name: String? {
        if let displayName = object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !displayName.isEmpty {
            return displayName
        }
        return object(forInfoDictionaryKey: "CFBundleName") as? String
    }
    
    var version: String? {
        if let shortVersion = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            if let buildVersion = object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                return "\(shortVersion) (\(buildVersion))"
            }
            return shortVersion
        }
        return nil
    }
    
    var exec: String {
        return object(forInfoDictionaryKey: "CFBundleExecutable") as? String ?? ""
    }
    
    var iconFileName: String? {
        guard let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let lastIcon = iconFiles.last else {
            return nil
        }
        
        return lastIcon
    }
}