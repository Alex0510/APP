import CoreData
import UIKit.UIImpactFeedbackGenerator
extension Storage {
	func addImported(
		uuid: String,
		source: URL? = nil,
		
		appName: String? = nil,
		appIdentifier: String? = nil,
		appVersion: String? = nil,
		appIcon: String? = nil,
		
		completion: @escaping (Error?) -> Void
	) {
		let generator = UIImpactFeedbackGenerator(style: .light)
		
		let new = Imported(context: context)
		
		new.uuid = uuid
		new.source = source
		new.date = Date()
		new.identifier = appIdentifier
		new.name = appName
		new.icon = appIcon
		new.version = appVersion
		
		saveContext()
		generator.impactOccurred()
		completion(nil)
	}
}
