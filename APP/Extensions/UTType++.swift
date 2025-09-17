import UniformTypeIdentifiers

extension UTType {
	static var entitlements: UTType = .init(filenameExtension: "entitlements", conformingTo: .data)!
	static var mobileProvision: UTType = .init(filenameExtension: "mobileprovision", conformingTo: .data)!
	static var dylib: UTType = .init(filenameExtension: "dylib", conformingTo: .data)!
	static var deb: UTType = .init(filenameExtension: "deb", conformingTo: .data)!
	static var p12: UTType = .init(filenameExtension: "p12", conformingTo: .data)!
	static var ipa: UTType = .init(filenameExtension: "ipa")!
	static var tipa: UTType = .init(filenameExtension: "tipa")!
}