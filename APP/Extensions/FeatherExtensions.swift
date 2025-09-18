import Foundation
import UIKit
import SwiftUI

public extension FileManager {
    func isFileFromFileProvider(at url: URL) -> Bool {
        if let resourceValues = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .fileResourceIdentifierKey]),
           resourceValues.isUbiquitousItem == true {
            return true
        }
        
        let path = url.path
        if path.contains("/Library/CloudStorage/") || path.contains("/File Provider Storage/") {
            return true
        }
        
        return false
    }
    
    func decodeAndWrite(base64: String, pathComponent: String) -> URL? {
        let raw = base64.replacingOccurrences(of: " ", with: "+")
        guard let data = Data(base64Encoded: raw) else { return nil }
        let dir = self.temporaryDirectory.appendingPathComponent(UUID().uuidString + pathComponent)
        try? data.write(to: dir)
        return dir
    }
}

public extension URL {
    func validatedScheme(after marker: String) -> String? {
        guard let range = absoluteString.range(of: marker) else { return nil }
        let path = String(absoluteString[range.upperBound...])
        guard path.hasPrefix("https://") else { return nil }
        return path
    }
}

public extension View {
    func copyableText(_ textToCopy: String) -> some View {
        self.contextMenu {
            Button(action: {
                UIPasteboard.general.string = textToCopy
            }) {
                Label("复制", systemImage: "doc.on.doc")
            }
        }
    }
}

public extension String {
    static func localized(_ name: String) -> String {
        NSLocalizedString(name, comment: "")
    }
    
    static func localized(_ name: String, arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(name, comment: ""), arguments: arguments)
    }
    
    func localized() -> String {
        return self
    }
}

public extension UIApplication {
    class func topViewController(controller: UIViewController? = {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }()) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
    
    static func openApp(with identifier: String) {
        let classNameBase64 = "TFNBcHBsaWNhdGlvbldvcmtzcGFjZQ=="
        let defaultSelectorBase64 = "ZGVmYXVsdFdvcmtzcGFjZQ=="
        let openSelectorBase64 = "b3BlbkFwcGxpY2F0aW9uV2l0aEJ1bmRsZUlEOg=="
        
        guard
            let classNameData = Data(base64Encoded: classNameBase64),
            let defaultSelectorData = Data(base64Encoded: defaultSelectorBase64),
            let openSelectorData = Data(base64Encoded: openSelectorBase64),
            let className = String(data: classNameData, encoding: .utf8),
            let defaultSelector = String(data: defaultSelectorData, encoding: .utf8),
            let openSelector = String(data: openSelectorData, encoding: .utf8)
        else {
            return
        }
        
        guard
            let workspaceClass = NSClassFromString(className) as? NSObject.Type,
            let workspace = workspaceClass.perform(NSSelectorFromString(defaultSelector))?.takeUnretainedValue()
        else {
            return
        }
        
        _ = workspace.perform(NSSelectorFromString(openSelector), with: identifier)
    }
}

public extension UIAlertController {
    static func showAlertWithCancel(
        _ presenter: UIViewController = UIApplication.topViewController()!,
        _ popoverFromView: UIView? = nil,
        title: String?, 
        message: String?, 
        style: UIAlertController.Style = .alert, 
        actions: [UIAlertAction]
    ) {
        var actions = actions
        actions.append(
            UIAlertAction(title: "取消", style: .cancel, handler: nil)
        )
        
        showAlert(presenter, popoverFromView, title: title, message: message, style: style, actions: actions)
    }
    
    static func showAlertWithOk(
        _ presenter: UIViewController = UIApplication.topViewController()!,
        _ popoverFromView: UIView? = nil,
        title: String?,
        message: String?,
        style: UIAlertController.Style = .alert,
        isCancel: Bool = false,
        action: (() -> Void)? = nil
    ) {
        var actions: [UIAlertAction] = []
        
        let alertAction = UIAlertAction(
            title: "确定",
            style: isCancel ? .cancel : .default,
            handler: { _ in
                if !isCancel {
                    action?()
                }
            }
        )
        
        actions.append(alertAction)
        
        showAlert(
            presenter,
            popoverFromView,
            title: title,
            message: message,
            style: style,
            actions: actions
        )
    }
    
    static func showAlert(
        _ presenter: UIViewController = UIApplication.topViewController()!,
        _ popoverFromView: UIView? = nil,
        title: String?, 
        message: String?, 
        style: UIAlertController.Style = .alert, 
        actions: [UIAlertAction]
    ) {
        let alert = Self(title: title, message: message, preferredStyle: style)
        actions.forEach { alert.addAction($0) }
        
        if 
            style == .actionSheet, 
            let popover = alert.popoverPresentationController, 
            let view = popoverFromView 
        {
            popover.sourceView = view
            popover.sourceRect = view.bounds
            popover.permittedArrowDirections = .any
        }
        
        presenter.present(alert, animated: true)
    }
}

public extension UIActivityViewController {
    static func show(
        _ presenter: UIViewController = UIApplication.topViewController()!,
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil
    ) {
        let controller = Self(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        
        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        presenter.present(controller, animated: true)
    }
}