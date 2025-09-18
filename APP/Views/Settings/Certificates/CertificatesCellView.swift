
import SwiftUI

struct NBPillItem {
    let title: String
    let icon: String
    let color: Color
}

struct NBTitleWithSubtitleView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NBPillView: View {
    let title: String
    let icon: String
    let color: Color
    let index: Int
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

struct CertificatesCellView: View {
	@State var data: Certificate?
	
	@ObservedObject var cert: CertificatePair
	
	var body: some View {
		VStack(spacing: 6) {
			let title = {
				var title = cert.nickname ?? data?.Name ?? "未知"
				
				if let getTaskAllow = data?.Entitlements?["get-task-allow"]?.value as? Bool, getTaskAllow == true {
					title = "🐞 \(title)"
				}
				
				return title
			}()
			
			NBTitleWithSubtitleView(
				title: title,
				subtitle: data?.AppIDName ?? "未知"
			)
			
			_certInfoPill(data: cert)
		}
		.frame(height: 80)
		.frame(maxWidth: .infinity, alignment: .leading)
		.onAppear {
			withAnimation {
				data = Storage.shared.getProvisionFileDecoded(for: cert)
			}
		}
	}
}

extension CertificatesCellView {
	@ViewBuilder
	private func _certInfoPill(data: CertificatePair) -> some View {
		let pillItems = _buildPills(from: data)
		HStack(spacing: 6) {
			ForEach(pillItems.indices, id: \.hashValue) { index in
				let pill = pillItems[index]
				NBPillView(
					title: pill.title,
					icon: pill.icon,
					color: pill.color,
					index: index,
					count: pillItems.count
				)
			}
		}
	}
	
	private func _buildPills(from cert: CertificatePair) -> [NBPillItem] {
		var pills: [NBPillItem] = []
		
		if cert.ppQCheck == true {
			pills.append(NBPillItem(title: "PPQ检查", icon: "checkmark.shield", color: .red))
		}
		
		if cert.revoked == true {
			pills.append(NBPillItem(title: "已撤销", icon: "xmark.octagon", color: .red))
		}
		
		if let info = cert.expiration?.expirationInfo() {
			pills.append(NBPillItem(
				title: info.formatted,
				icon: info.icon,
				color: info.color
			))
		}
		
		return pills
	}
}
