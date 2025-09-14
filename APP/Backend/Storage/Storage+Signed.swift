import CoreData
import UIKit.UIImpactFeedbackGenerator
extension Storage {
	func addSigned(
		uuid: String,
		source: URL? = nil,
		certificate: CertificatePair? = nil,
		
		appName: String? = nil,
		appIdentifier: String? = nil,
		appVersion: String? = nil,
		appIcon: String? = nil,
		
		completion: @escaping (Error?) -> Void
	) {
		let generator = UIImpactFeedbackGenerator(style: .light)
		
		let new = Signed(context: context)
		
		new.uuid = uuid
		new.source = source
		new.date = Date()
		new.certificate = certificate
		new.identifier = appIdentifier
		new.name = appName
		new.icon = appIcon
		new.version = appVersion
		
		saveContext()
		generator.impactOccurred()
		completion(nil)
	}
}
