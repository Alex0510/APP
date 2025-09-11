//
//  SearchManager.swift
//  APP
//
//  由 pxx917144686 于 2025/08/20 创建。
//
import Foundation
/// 用于处理应用搜索和查找操作的搜索管理器
class SearchManager {
    static let shared = SearchManager()
    private var itunesClient: iTunesClient {
        return iTunesClient.shared
    }
    private init() {}
    /// 按查询词搜索应用
    /// - 参数:
    ///   - query: 搜索词
    ///   - limit: 最大结果数 (默认值: 50)
    ///   - countryCode: iTunes 商店区域 (默认值: "US")
    ///   - deviceFamily: 设备类型 (默认值: .phone)
    /// - 返回值: 包含搜索结果或错误的结果对象
    func searchApps(
        query: String,
        limit: Int = 50,
        countryCode: String = "US",
        deviceFamily: DeviceFamily = .phone
    ) async -> Result<[iTunesSearchResult], SearchError> {
        // 验证输入
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.emptyQuery)
        }
        guard limit > 0 && limit <= 200 else {
            return .failure(.invalidLimit)
        }
        do {
            let results = try await itunesClient.search(
                term: query,
                limit: limit,
                countryCode: countryCode,
                deviceFamily: deviceFamily
            )
            if let searchResults = results, !searchResults.isEmpty {
                return .success(searchResults)
            } else {
                return .failure(.noResults)
            }
        } catch {
            return .failure(.networkError(error))
        }
    }
    /// 按应用包标识符查找应用
    /// - 参数:
    ///   - bundleIdentifier: 应用包 ID
    ///   - countryCode: iTunes 商店区域 (默认值: "US")
    ///   - deviceFamily: 设备类型 (默认值: .phone)
    /// - 返回值: 包含应用信息或错误的结果对象
    func lookupApp(
        bundleIdentifier: String,
        countryCode: String = "US",
        deviceFamily: DeviceFamily = .phone
    ) async -> Result<iTunesSearchResult, SearchError> {
        // 验证应用包标识符
        guard !bundleIdentifier.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.invalidBundleId)
        }
        do {
            let result = try await itunesClient.lookup(
                bundleIdentifier: bundleIdentifier,
                countryCode: countryCode,
                deviceFamily: deviceFamily
            )
            if let appInfo = result {
                return .success(appInfo)
            } else {
                return .failure(.appNotFound)
            }
        } catch {
            return .failure(.networkError(error))
        }
    }
    /// 从应用包标识符获取曲目 ID 或返回提供的曲目 ID
    /// - 参数:
    ///   - bundleIdentifier: 应用包 ID (可选)
    ///   - trackId: 曲目 ID (可选)
    ///   - countryCode: iTunes 商店区域 (默认值: "US")
    ///   - deviceFamily: 设备类型 (默认值: .phone)
    /// - 返回值: 如果找到则返回曲目 ID
    func getTrackId(
        bundleIdentifier: String? = nil,
        trackId: String? = nil,
        countryCode: String = "US",
        deviceFamily: DeviceFamily = .phone
    ) async -> Result<Int, SearchError> {
        // 如果提供了曲目 ID，验证并返回它
        if let trackIdString = trackId {
            if let trackIdInt = Int(trackIdString) {
                return .success(trackIdInt)
            } else {
                return .failure(.invalidTrackId)
            }
        }
        // 如果提供了应用包标识符，查找它
        if let bundleId = bundleIdentifier {
            let lookupResult = await lookupApp(
                bundleIdentifier: bundleId,
                countryCode: countryCode,
                deviceFamily: deviceFamily
            )
            switch lookupResult {
            case .success(let appInfo):
                return .success(appInfo.trackId)
            case .failure(let error):
                return .failure(error)
            }
        }
        return .failure(.missingIdentifier)
    }
}
// MARK: - 搜索模型
// 使用来自 iTunesAPI.swift 的 SearchError 以避免冲突
// MARK: - 扩展
extension iTunesSearchResult {
    /// 检查应用是否免费
    var isFree: Bool {
        return (price ?? 0.0) == 0.0
    }
    /// 获取格式化后的价格字符串
    var displayPrice: String {
        if isFree {
            return "免费"
        } else {
            return formattedPrice ?? "\(price ?? 0.0)"
        }
    }
    /// 从描述或曲目查看 URL 获取应用类别
    var category: String? {
        // 可以增强此功能，以便在可用时从应用元数据中提取类别信息
        return nil
    }
}