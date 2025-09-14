import OSLog

extension Logger {
	private static var subsystem = Bundle.main.bundleIdentifier!
	static let signing = Logger(subsystem: subsystem, category: "Signing")
	static let misc = Logger(subsystem: subsystem, category: "Misc")
}