import SwiftUI
import SafariServices

public struct SafariRepresentableView: UIViewControllerRepresentable {
	public let url: URL

	public init(url: URL) {
		self.url = url
	}

	public func makeUIViewController(context: Context) -> SFSafariViewController { return SFSafariViewController(url: url) }
	public func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}