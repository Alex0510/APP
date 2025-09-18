//
//  SearchManager.swift
//  APP
//
//  由 pxx917144686 于 2025/08/20 创建。
//
import Foundation
import SwiftUI

/// 搜索历史管理器
class SearchHistoryManager: ObservableObject {
    static let shared = SearchHistoryManager()
    @Published var searchHistory: [iTunesClient.SearchHistoryItem] = []
    private let maxHistoryCount = 20
    private let userDefaults = UserDefaults.standard
    private let historyKey = "SearchHistory"
    
    private init() {
        loadSearchHistory()
    }
    
    /// 添加搜索历史
    func addSearchHistory(_ query: String, resultCount: Int = 0) {
        let newItem = iTunesClient.SearchHistoryItem(query: query, resultCount: resultCount)
        
        // 移除重复项
        searchHistory.removeAll { $0.query == query }
        
        // 添加到开头
        searchHistory.insert(newItem, at: 0)
        
        // 限制历史记录数量
        if searchHistory.count > maxHistoryCount {
            searchHistory = Array(searchHistory.prefix(maxHistoryCount))
        }
        
        saveSearchHistory()
    }
    
    /// 清除搜索历史
    func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    /// 删除特定搜索历史
    func removeSearchHistory(_ item: iTunesClient.SearchHistoryItem) {
        searchHistory.removeAll { $0.id == item.id }
        saveSearchHistory()
    }
    
    /// 保存搜索历史
    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            userDefaults.set(data, forKey: historyKey)
        }
    }
    
    /// 加载搜索历史
    private func loadSearchHistory() {
        if let data = userDefaults.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([iTunesClient.SearchHistoryItem].self, from: data) {
            searchHistory = history
        }
    }
}

/// 用于处理应用搜索和查找操作的搜索管理器
class SearchManager: ObservableObject {
    static let shared = SearchManager()
    private var itunesClient: iTunesClient {
        return iTunesClient.shared
    }
    private let historyManager = SearchHistoryManager.shared
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

// MARK: - 增强搜索功能
extension SearchManager {
    /// 增强搜索 - 支持过滤器和排序
    func enhancedSearch(
        query: String,
        filter: iTunesClient.SearchFilter = iTunesClient.SearchFilter(),
        limit: Int = 50,
        countryCode: String = "US"
    ) async -> Result<[iTunesSearchResult], SearchError> {
        // 验证输入
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.emptyQuery)
        }
        guard limit > 0 && limit <= 200 else {
            return .failure(.invalidLimit)
        }
        
        do {
            let result = await itunesClient.enhancedSearch(
                query: query,
                filter: filter,
                limit: limit,
                country: countryCode
            )
            
            switch result {
            case .success(let results):
                // 保存搜索历史
                historyManager.addSearchHistory(query, resultCount: results.count)
                return .success(results)
            case .failure(let error):
                return .failure(.networkError(error))
            }
        }
    }
    
    /// 获取搜索建议
    func getSearchSuggestions(for query: String) async -> Result<[iTunesClient.SuggestTerm], SearchError> {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.emptyQuery)
        }
        
        let result = await itunesClient.getSearchSuggestions(for: query)
        switch result {
        case .success(let suggestions):
            return .success(suggestions)
        case .failure(let error):
            return .failure(.networkError(error))
        }
    }
    
    /// 添加搜索历史
    func addSearchHistory(_ query: String, resultCount: Int = 0) {
        historyManager.addSearchHistory(query, resultCount: resultCount)
    }
    
    /// 获取搜索历史
    func getSearchHistory() -> [iTunesClient.SearchHistoryItem] {
        return historyManager.searchHistory
    }
    
    /// 清除搜索历史
    func clearSearchHistory() {
        historyManager.clearSearchHistory()
    }
    
    /// 删除特定搜索历史
    func removeSearchHistory(_ item: iTunesClient.SearchHistoryItem) {
        historyManager.removeSearchHistory(item)
    }
}
// MARK: - 扩展：高级能力封装（隐私/版本/评论/联想）
extension SearchManager {
    /// 获取应用的版本历史（通过 AMP API）
    func fetchVersionHistory(appId: Int, countryCode: String = "US") async -> Result<[iTunesClient.AppVersionInfo], SearchError> {
        do {
            let list = try await itunesClient.versionHistory(id: appId, country: countryCode)
            return .success(list)
        } catch let err as SearchError {
            return .failure(err)
        } catch {
            return .failure(.networkError(error))
        }
    }
    /// 获取应用的隐私详情
    func fetchPrivacy(appId: Int, countryCode: String = "US") async -> Result<iTunesClient.AppPrivacy, SearchError> {
        do {
            let info = try await itunesClient.privacy(id: appId, country: countryCode)
            return .success(info)
        } catch let err as SearchError {
            return .failure(err)
        } catch {
            return .failure(.networkError(error))
        }
    }
    /// 获取应用的评论列表
    func fetchReviews(appId: Int, countryCode: String = "us", page: Int = 1, sort: iTunesClient.ReviewSort = .mostRecent) async -> Result<[iTunesClient.AppReview], SearchError> {
        do {
            let list = try await itunesClient.reviews(id: appId, country: countryCode, page: page, sort: sort)
            return .success(list)
        } catch let err as SearchError {
            return .failure(err)
        } catch {
            return .failure(.networkError(error))
        }
    }
    /// 联想词
    func suggest(term: String) async -> Result<[iTunesClient.SuggestTerm], SearchError> {
        do {
            let list = try await itunesClient.suggest(term: term)
            return .success(list)
        } catch let err as SearchError {
            return .failure(err)
        } catch {
            return .failure(.networkError(error))
        }
    }
}