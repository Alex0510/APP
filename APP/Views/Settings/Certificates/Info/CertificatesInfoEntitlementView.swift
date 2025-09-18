
import SwiftUI

struct CertificatesInfoEntitlementView: View {
	let entitlements: [String: AnyCodable]
	
	var body: some View {
		List {
			ForEach(entitlements.keys.sorted(), id: \.self) { key in
				if let value = entitlements[key]?.value {
					CertificatesInfoEntitlementCellView(key: key, value: value)
				}
			}
		}
		.navigationTitle("权限")
		.listStyle(.grouped)
	}
}
