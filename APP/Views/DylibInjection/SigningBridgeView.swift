import SwiftUI
import CoreData

struct SigningBridgeView: View {
    let app: AppInfoPresentable
    let dylib: DylibFile?

    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss

    @State private var status: String = "准备签名"
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var resultIPAPath: String?

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(status).font(.headline)
                ProgressView(value: progress).progressViewStyle(.linear)
                if let err = errorMessage { Text(err).foregroundColor(.red).font(.footnote) }
                if let ipa = resultIPAPath {
                    Text("IPA 输出: \(ipa)").font(.footnote).foregroundColor(.secondary)
                }
                Spacer()
                HStack {
                    Button("关闭") { dismiss() }.buttonStyle(.bordered)
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("签名")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { startFlow() }
    }

    private func startFlow() {
        guard let appDir = Storage.shared.getAppDirectory(for: app) else {
            errorMessage = "目标应用目录不存在"
            return
        }

        let appPath = appDir.path
        let dylibPath = dylib?.path

        status = "准备注入"
        progress = 0.05

        DispatchQueue.global(qos: .userInitiated).async {
            var injectionOK = true
            if let dylibPath {
                injectionOK = LiveContainerIntegration.shared.injectDylibUsingLiveContainer(dylibPath: dylibPath, targetAppPath: appPath)
            }

            DispatchQueue.main.async {
                if !injectionOK {
                    self.errorMessage = "动态库注入失败"
                    self.status = "失败"
                    return
                }
                self.status = "创建可安装 IPA"
                self.progress = 0.25
            }

            LiveContainerIntegration.shared.injectDylibAndCreateIPA(dylibPath: dylibPath ?? "", targetAppPath: appPath, appleId: nil) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let ipaPath):
                        self.resultIPAPath = ipaPath
                        self.status = "IPA 创建完成"
                        self.progress = 1.0
                    case .failure(let err):
                        self.errorMessage = err.localizedDescription
                        self.status = "失败"
                        self.progress = 1.0
                    }
                }
            }
        }
    }
}


