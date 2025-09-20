//
//  Apple.swift
//  APP
//
//  Created by pxx917144686 on 2024/12/30.
//
import Foundation
import Security
import CryptoKit
import AltSourceKit
import OSLog
import Network
import Combine
import SwiftUI
import CommonCrypto
import AltSourceKit
import Vapor
#if os(macOS)
import Darwin
#endif
// MARK: - 全局配置和映射
// MARK: - HTTP 类型定义
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}
public protocol HTTPRequest {
    var method: HTTPMethod { get }
    var endpoint: HTTPEndpoint { get }
    var headers: [String: String] { get }
    var payload: HTTPPayload? { get }
}
public protocol HTTPEndpoint {
    var url: URL { get }
}
public enum HTTPPayload {
    case xml([String: Any])
    case urlEncoding([String: String])
}
public struct HTTPResponse {
    public let data: Data
    public let response: HTTPURLResponse
    public var allHeaderFields: [AnyHashable: Any] {
        return response.allHeaderFields
    }
    public init(data: Data, response: HTTPURLResponse) {
        self.data = data
        self.response = response
    }
}
public enum HTTPResponseFormat {
    case xml
    case json
}
public extension HTTPResponse {
    func decode<T: Decodable>(_ type: T.Type, as format: HTTPResponseFormat) throws -> T {
        guard !data.isEmpty else {
            throw HTTPClientError.invalidResponse
        }
        switch format {
        case .json:
            let decoder = JSONDecoder()
            decoder.userInfo = [.init(rawValue: "data")!: data]
            return try decoder.decode(type, from: data)
        case .xml:
            let decoder = PropertyListDecoder()
            decoder.userInfo = [.init(rawValue: "data")!: data]
            return try decoder.decode(type, from: data)
        }
    }
}
// MARK: - 实体类型
public enum EntityType: String, CaseIterable {
    case desktopApp = "desktopApp"
    case iosApp = "software"
    case macApp = "macSoftware"
}
// MARK: - iTunes Archive (legacy support)
extension iTunesResponse {
    struct iTunesArchive: Identifiable, Equatable, Hashable, Codable {
        public var id: String { bundleIdentifier }
        public let bundleIdentifier: String
        public let version: String
        public let identifier: Int
        public let name: String
        public let artworkUrl512: String?
        public let fileSizeBytes: String?
        public let isGameCenterEnabled: Bool?
        public let screenshotUrls: [String]?
        public let currency: String?
        public let artistName: String?
        public let price: Double?
        public let formattedPrice: String?
        public let description: String?
        public let releaseNotes: String?
        public let supportedDevices: [String]?
        public var entityType: EntityType?
        public var byteCountDescription: String {
            guard let fileSizeBytes, let bytes = Int64(fileSizeBytes) else {
                return "Unknown"
            }
            let fmt = ByteCountFormatter()
            fmt.countStyle = .file
            return fmt.string(fromByteCount: bytes)
        }
        enum CodingKeys: String, CodingKey {
            case identifier = "trackId"
            case name = "trackName"
            case bundleIdentifier = "bundleId"
            case version, artworkUrl512, fileSizeBytes
            case isGameCenterEnabled, screenshotUrls, currency
            case artistName, price, formattedPrice, description
            case releaseNotes, supportedDevices
        }
    }
}
// iTunesResponse Codable implementation is now in iTunesAPI.swift
// MARK: - 统一的Account模型
/// 统一的账户模型，避免重复定义
public struct Account: Codable, Identifiable, Equatable {
    public static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id
    }
    
    public var id: String { email }
    // 基本信息
    public let name: String
    public let email: String
    public let firstName: String
    public let lastName: String
    // 认证信息
    public let passwordToken: String
    public let directoryServicesIdentifier: String
    public let dsPersonId: String
    // 会话信息
    public let cookies: [String]
    public let countryCode: String
    // Store响应信息
    public let storeResponse: StoreResponse
    // 新增字段：storeFront用于地区识别
    public let storeFront: String
    
    public init(
        name: String,
        email: String,
        firstName: String,
        lastName: String,
        passwordToken: String,
        directoryServicesIdentifier: String,
        dsPersonId: String,
        cookies: [String] = [],
        countryCode: String = "US",
        storeResponse: StoreResponse,
        storeFront: String = ""
    ) {
        self.name = name
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.passwordToken = passwordToken
        self.directoryServicesIdentifier = directoryServicesIdentifier
        self.dsPersonId = dsPersonId
        self.cookies = cookies
        self.countryCode = countryCode
        self.storeResponse = storeResponse
        self.storeFront = storeFront
    }
    
    // 便利初始化器，兼容旧版本
    public init(
        firstName: String,
        lastName: String,
        directoryServicesIdentifier: String,
        passwordToken: String,
        storeFront: String = ""
    ) {
        self.init(
            name: "\(firstName) \(lastName)",
            email: "", // 需要从外部提供
            firstName: firstName,
            lastName: lastName,
            passwordToken: passwordToken,
            directoryServicesIdentifier: directoryServicesIdentifier,
            dsPersonId: directoryServicesIdentifier,
            storeResponse: StoreResponse(
                directoryServicesIdentifier: directoryServicesIdentifier,
                passwordToken: passwordToken,
                storeFront: storeFront.isEmpty ? "143441-1,29" : storeFront
            ),
            storeFront: storeFront
        )
    }
    
    public struct StoreResponse: Codable {
        public let directoryServicesIdentifier: String
        public let passwordToken: String
        public let storeFront: String
        public init(directoryServicesIdentifier: String, passwordToken: String, storeFront: String) {
            self.directoryServicesIdentifier = directoryServicesIdentifier
            self.passwordToken = passwordToken
            self.storeFront = storeFront
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "n"
        case email = "e"
        case firstName = "fn"
        case lastName = "ln"
        case passwordToken = "p"
        case directoryServicesIdentifier = "dsi"
        case dsPersonId = "d"
        case cookies = "c"
        case countryCode = "cc"
        case storeResponse = "sr"
        case storeFront = "sf"
    }
}
// MARK: - Store 响应模型
public enum StoreResponse {
    case failure(error: Swift.Error)
    case account(Account)
    case item(Item)
    public struct Item {
        public let url: URL
        public let md5: String
        public let signatures: [Signature]
        public let metadata: [String: Any]
        public init(url: URL, md5: String, signatures: [Signature], metadata: [String: Any]) {
            self.url = url
            self.md5 = md5
            self.signatures = signatures
            self.metadata = metadata
        }
    }
    enum Error: Int, Swift.Error {
        case unknownError = 0
        case genericError = 5002
        case codeRequired = 1
        case invalidLicense = 9610
        case invalidCredentials = -5000
        case invalidAccount = 5001
        case invalidItem = -10000
        case lockedAccount = -10001
    }
}
extension StoreResponse: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let error = try container.decodeIfPresent(String.self, forKey: .error)
        let message = try container.decodeIfPresent(String.self, forKey: .message)
        if container.contains(.account) {
            let directoryServicesIdentifier = try container.decode(String.self, forKey: .directoryServicesIdentifier)
            let accountContainer = try container.nestedContainer(keyedBy: AccountInfoCodingKeys.self, forKey: .account)
            let addressContainer = try accountContainer.nestedContainer(keyedBy: AddressCodingKeys.self, forKey: .address)
            let firstName = try addressContainer.decode(String.self, forKey: .firstName)
            let lastName = try addressContainer.decode(String.self, forKey: .lastName)
            let passwordToken = try container.decode(String.self, forKey: .passwordToken)
            self = .account(.init(firstName: firstName, lastName: lastName, directoryServicesIdentifier: directoryServicesIdentifier, passwordToken: passwordToken))
        } else if let items = try container.decodeIfPresent([Item].self, forKey: .items), let item = items.first {
            self = .item(item)
        } else if let error = error, !error.isEmpty {
            self = .failure(error: Error(rawValue: Int(error) ?? 0) ?? .unknownError)
        } else {
            switch message {
            case "Your account information was entered incorrectly.":
                self = .failure(error: Error.invalidCredentials)
            case "An Apple ID verification code is required to sign in. Type your password followed by the verification code shown on your other devices.":
                self = .failure(error: Error.codeRequired)
            case "This Apple ID has been locked for security reasons. Visit iForgot to reset your account (https://iforgot.apple.com).":
                self = .failure(error: Error.lockedAccount)
            case let msg where msg?.contains("未能读取数据") == true || msg?.contains("格式不正确") == true:
                self = .failure(error: Error.invalidCredentials)
            default:
                self = .failure(error: Error.unknownError)
            }
        }
    }
    private enum CodingKeys: String, CodingKey {
        case directoryServicesIdentifier = "dsPersonId"
        case message = "customerMessage"
        case items = "songList"
        case error = "failureType"
        case account = "accountInfo"
        case passwordToken
    }
    private enum AccountInfoCodingKeys: String, CodingKey {
        case address
    }
    private enum AddressCodingKeys: String, CodingKey {
        case firstName
        case lastName
    }
}
extension StoreResponse.Item: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let md5 = try container.decode(String.self, forKey: .md5)
        guard let key = CodingUserInfoKey(rawValue: "data"),
              let data = decoder.userInfo[key] as? Data,
              let json = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let items = json["songList"] as? [[String: Any]],
              let item = items.first(where: { $0["md5"] as? String == md5 }),
              let metadata = item["metadata"] as? [String: Any]
        else { throw StoreResponse.Error.invalidItem }
        let absoluteUrl = try container.decode(String.self, forKey: .url)
        self.md5 = md5
        self.metadata = metadata
        signatures = try container.decode([Signature].self, forKey: .signatures)
        if let url = URL(string: absoluteUrl) {
            self.url = url
        } else {
            let context = DecodingError.Context(codingPath: [CodingKeys.url], debugDescription: "URL contains illegal characters: \(absoluteUrl).")
            throw DecodingError.keyNotFound(CodingKeys.url, context)
        }
    }
    public struct Signature: Codable, Hashable {
        public let id: Int
        public let sinf: Data
        public init(id: Int, sinf: Data) {
            self.id = id
            self.sinf = sinf
        }
    }
    enum CodingKeys: String, CodingKey {
        case url = "URL"
        case metadata
        case md5
        case signatures = "sinfs"
    }
}
// MARK: - Apple 主入口
public enum Apple {
    // MARK: - 全局配置
    public static var overrideGUID: String?
    static let storeFrontCodeMap: [String: String] = [
        "US": "143441", "CN": "143465", "JP": "143462", "GB": "143444",
        "DE": "143443", "FR": "143442", "AU": "143460", "CA": "143455",
        "IT": "143450", "ES": "143454", "KR": "143466", "BR": "143503",
        "MX": "143468", "IN": "143467", "RU": "143469", "NL": "143452",
        "SE": "143456", "NO": "143457", "DK": "143458", "FI": "143447"
    ]
    
    // 新增：从storeFront代码到国家代码的反向映射
    static let storeFrontToCountryCodeMap: [String: String] = [
        "143441": "US", "143465": "CN", "143462": "JP", "143444": "GB",
        "143443": "DE", "143442": "FR", "143460": "AU", "143455": "CA",
        "143450": "IT", "143454": "ES", "143466": "KR", "143503": "BR",
        "143468": "MX", "143467": "IN", "143469": "RU", "143452": "NL",
        "143456": "SE", "143457": "NO", "143458": "DK", "143447": "FI"
    ]
    
    public static var countryCodeMap: [String: String] {
        storeFrontCodeMap
    }
    
    // MARK: - HTTP 客户端
    public class HTTPClient {
        private let session: URLSession
        public init(session: URLSession = .shared) {
            self.session = session
        }
        public func send(_ request: HTTPRequest) throws -> HTTPResponse {
            let semaphore = DispatchSemaphore(value: 0)
            var result: Result<HTTPResponse, Error>!
            send(request) { response in
                result = response
                semaphore.signal()
            }
            semaphore.wait()
            return try result.get()
        }
        public func send(_ request: HTTPRequest, completion: @escaping (Result<HTTPResponse, Error>) -> Void) {
            do {
                let urlRequest = try makeURLRequest(from: request)
                session.dataTask(with: urlRequest) { data, response, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    guard let data = data, let response = response as? HTTPURLResponse else {
                        completion(.failure(HTTPClientError.invalidResponse))
                        return
                    }
                    completion(.success(HTTPResponse(data: data, response: response)))
                }.resume()
            } catch {
                completion(.failure(error))
            }
        }
        private func makeURLRequest(from request: HTTPRequest) throws -> URLRequest {
            var urlRequest = URLRequest(url: request.endpoint.url)
            urlRequest.httpMethod = request.method.rawValue
            for (key, value) in request.headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
            if let payload = request.payload {
                switch payload {
                case .xml(let dictionary):
                    urlRequest.httpBody = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
                case .urlEncoding(let parameters):
                    let body = parameters.map { "\($0.key)=\($0.value.addingPercentEncoding(charSet: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
                    urlRequest.httpBody = body.data(using: .utf8)
                }
            }
            return urlRequest
        }
    }
    // MARK: - Legacy iTunes Client (Deprecated)
    // Note: This class is deprecated. Use iTunesClient from iTunesAPI.swift instead
    // Note: StoreClient has been moved to StoreClient.swift
    // MARK: - 认证器
    public class Authenticator {
        public let email: String
        public var authenticated: Bool { authenticatedAccount != nil }
        public var account: Account? { authenticatedAccount }
        private let storeClient: StoreClient
        private var authenticatedAccount: Account?
        public init(email: String) {
            self.email = email
            _ = HTTPClient()
            storeClient = StoreClient.shared
        }
        public func authenticate(password: String, code: String? = nil) async throws -> Account {
            let result = await storeClient.authenticate(email: email, password: password, mfaCode: code)
            switch result {
            case .success(let account):
                self.authenticatedAccount = account
                // Save credentials to keychain
                try saveCredentials(account: account)
                return account
            case .failure(let error):
                throw error
            }
        }
        public func loadSavedCredentials() throws -> Account? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "APP.Apple.Store",
                kSecAttrAccount as String: email,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess,
                  let data = result as? Data,
                  let account = try? JSONDecoder().decode(Account.self, from: data) else {
                return nil
            }
            self.authenticatedAccount = account
            return account
        }
        private func saveCredentials(account: Account) throws {
            let data = try JSONEncoder().encode(account)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "APP.Apple.Store",
                kSecAttrAccount as String: email,
                kSecValueData as String: data
            ]
            // Delete existing item first
            SecItemDelete(query as CFDictionary)
            // Add new item
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw AuthenticatorError.keychainError
            }
        }
        public func logout() {
            // Remove from keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "APP.Apple.Store",
                kSecAttrAccount as String: email
            ]
            SecItemDelete(query as CFDictionary)
            self.authenticatedAccount = nil
        }
    }
    // MARK: - 下载器
    public class Downloader {
        public let email: String
        public let region: String
        public let directoryServicesIdentifier: String
        private let httpClient: HTTPClient
        private let itunesClient: iTunesClient
        private let storeClient: StoreClient
        public typealias ProgressBlock = (Float) -> Void
        public var onProgress: ProgressBlock?
        public init(email: String, directoryServicesIdentifier: String, region: String) {
            self.email = email
            self.directoryServicesIdentifier = directoryServicesIdentifier
            self.region = region
            httpClient = HTTPClient()
            itunesClient = iTunesClient.shared
            storeClient = StoreClient.shared
        }
        public func download(type: EntityType, bundleIdentifier: String, saveToDirectory: URL, withFileName fileName: String?, externalVersionId: String? = nil, shouldSign: Bool = true) async throws -> URL {
            // Look up the app in iTunes
            guard let app = try await itunesClient.lookup(bundleIdentifier: bundleIdentifier, countryCode: region) else {
                throw iTunesClientError.appNotFound
            }
            // Get download information from the store
            let result = await storeClient.getAppDownloadInfo(trackId: String(app.trackId), account: Account(name: "", email: email, firstName: "", lastName: "", passwordToken: "", directoryServicesIdentifier: directoryServicesIdentifier, dsPersonId: directoryServicesIdentifier, cookies: [], countryCode: region, storeResponse: Account.StoreResponse(directoryServicesIdentifier: directoryServicesIdentifier, passwordToken: "", storeFront: Apple.storeFrontCodeMap[region] ?? "")), appVerId: externalVersionId)
            let storeItem = try result.get()
            // Convert StoreItem to StoreResponse.Item
            let signatures = storeItem.sinfs.map { sinfData in
                StoreResponse.Item.Signature(id: sinfData.id, sinf: Data(base64Encoded: sinfData.sinf) ?? Data())
            }
            let metadata: [String: Any] = [
                "bundleDisplayName": storeItem.metadata.bundleDisplayName,
                "bundleShortVersionString": storeItem.metadata.bundleShortVersionString,
                "softwareVersionBundleId": storeItem.metadata.bundleId,
                "softwareVersionExternalIdentifier": storeItem.metadata.softwareVersionExternalIdentifier
            ]
            let item = StoreResponse.Item(
                url: URL(string: storeItem.url)!,
                md5: storeItem.md5,
                signatures: signatures,
                metadata: metadata
            )
            if !FileManager.default.fileExists(atPath: saveToDirectory.path) {
                try FileManager.default.createDirectory(at: saveToDirectory, withIntermediateDirectories: true)
            }
            let versionSuffix = externalVersionId != nil ? "_historical" : ""
            let name = fileName ?? "\(bundleIdentifier)_\(app.trackId)_v\(app.version)\(versionSuffix).ipa"
            let path = saveToDirectory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: path.path) {
                try FileManager.default.removeItem(at: path)
            }
            // Download with progress tracking
            try await downloadWithProgress(from: item.url, to: path)
            // Sign the IPA if requested
            if shouldSign {
                try await signIPA(item: item, at: path)
            }
            return path
        }
        private func downloadWithProgress(from url: URL, to saveURL: URL) async throws {
            let request = URLRequest(url: url)
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw DownloaderError.downloadFailed
            }
            let expectedLength = httpResponse.expectedContentLength
            var downloadedData = Data()
            for try await byte in asyncBytes {
                downloadedData.append(byte)
                if expectedLength > 0 {
                    let progress = Float(downloadedData.count) / Float(expectedLength)
                    await MainActor.run {
                        onProgress?(progress)
                    }
                }
            }
            try downloadedData.write(to: saveURL)
        }
        private func signIPA(item: StoreResponse.Item, at url: URL) async throws {
            // Convert StoreResponse.Item to StoreItem for SignatureClient
            // Note: This is a simplified conversion - may need adjustment based on actual StoreItem structure
            // For now, we'll skip the signing process as it requires proper type conversion
            // TODO: Implement proper StoreResponse.Item to StoreItem conversion
            print("Signing IPA at \(url.path) - conversion needed")
        }
        public func purchase(trackID: Int, token: String, countryCode: String) async throws {
            let account = Account(
                name: "",
                email: email,
                firstName: "",
                lastName: "",
                passwordToken: token,
                directoryServicesIdentifier: directoryServicesIdentifier,
                dsPersonId: directoryServicesIdentifier,
                cookies: [],
                countryCode: countryCode,
                storeResponse: Account.StoreResponse(
                    directoryServicesIdentifier: directoryServicesIdentifier,
                    passwordToken: token,
                    storeFront: Apple.storeFrontCodeMap[countryCode] ?? "143441"
                )
            )
            // 修复: 移除多余的country参数
            let result = await storeClient.purchaseApp(trackId: String(trackID), account: account)
            _ = try result.get()
        }
        public func getItem(identifier: String, externalVersionId: String? = nil) async throws -> StoreResponse.Item {
            let account = Account(
                name: "",
                email: email,
                firstName: "",
                lastName: "",
                passwordToken: "",
                directoryServicesIdentifier: directoryServicesIdentifier,
                dsPersonId: directoryServicesIdentifier,
                cookies: [],
                countryCode: region,
                storeResponse: Account.StoreResponse(
                    directoryServicesIdentifier: directoryServicesIdentifier,
                    passwordToken: "",
                    storeFront: Apple.storeFrontCodeMap[region] ?? "143441"
                )
            )
            let result = await storeClient.getAppDownloadInfo(trackId: identifier, account: account, appVerId: externalVersionId)
            let storeItem = try result.get()
            // Convert StoreItem to StoreResponse.Item
            let signatures = storeItem.sinfs.map { sinfData in
                StoreResponse.Item.Signature(id: sinfData.id, sinf: Data(base64Encoded: sinfData.sinf) ?? Data())
            }
            let metadata: [String: Any] = [
                "bundleDisplayName": storeItem.metadata.bundleDisplayName,
                "bundleShortVersionString": storeItem.metadata.bundleShortVersionString,
                "softwareVersionBundleId": storeItem.metadata.bundleId,
                "softwareVersionExternalIdentifier": storeItem.metadata.softwareVersionExternalIdentifier
            ]
            return StoreResponse.Item(
                url: URL(string: storeItem.url)!,
                md5: storeItem.md5,
                signatures: signatures,
                metadata: metadata
            )
        }
    }
    // MARK: - 便捷方法
    // MARK: - Legacy Search Method (Deprecated)
    // Note: This method is deprecated. Use iTunesClient.shared.search instead
    public static func purchase(token: String, directoryServicesIdentifier: String, trackID: Int, countryCode: String) async throws {
        let storeClient = StoreClient.shared // 使用新的单例模式
        let account = Account(
            name: "",
            email: "",
            firstName: "",
            lastName: "",
            passwordToken: token,
            directoryServicesIdentifier: directoryServicesIdentifier,
            dsPersonId: directoryServicesIdentifier,
            cookies: [],
            countryCode: countryCode,
            storeResponse: Account.StoreResponse(
                directoryServicesIdentifier: directoryServicesIdentifier,
                passwordToken: token,
                storeFront: Apple.storeFrontCodeMap[countryCode] ?? "143441"
            )
        )
        // 修复: 移除多余的country参数
        let result = await storeClient.purchaseApp(trackId: String(trackID), account: account)
        _ = try result.get()
    }
    // MARK: - 工具方法
    public static func md5(of fileURL: URL) -> String? {
        do {
            var hasher = Insecure.MD5()
            let bufferSize = 1024 * 1024 * 32 // 32MB
            let fileHandler = try FileHandle(forReadingFrom: fileURL)
            fileHandler.seekToEndOfFile()
            let size = fileHandler.offsetInFile
            try fileHandler.seek(toOffset: 0)
            while fileHandler.offsetInFile < size {
                autoreleasepool {
                    let data = fileHandler.readData(ofLength: bufferSize)
                    hasher.update(data: data)
                }
            }
            let digest = hasher.finalize()
            return digest.map { String(format: "%02hhx", $0) }.joined()
        } catch {
            print("[-] error reading file: \(error)")
            return nil
        }
    }
    public static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    public static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    public static func generateUUID() -> String {
        return UUID().uuidString
    }
    // MAC地址基础的GUID生成，完全匹配旧版本逻辑
    public static func generateMACBasedGUID() -> String {
        #if os(macOS)
            let MAC_ADDRESS_LENGTH = 6
            let bsds: [String] = ["en0", "en1"]
            var bsd: String = bsds[0]
            var length: size_t = 0
            var buffer: [CChar]
            var bsdIndex = Int32(if_nametoindex(bsd))
            if bsdIndex == 0 {
                bsd = bsds[1]
                bsdIndex = Int32(if_nametoindex(bsd))
                guard bsdIndex != 0 else {
                    // 如果无法获取MAC地址，使用固定值
                    return "060218BB0A0A"
                }
            }
            let bsdData = Data(bsd.utf8)
            var managementInfoBase = [CTL_NET, AF_ROUTE, 0, AF_LINK, NET_RT_IFLIST, bsdIndex]
            guard sysctl(&managementInfoBase, 6, nil, &length, nil, 0) >= 0 else {
                return "060218BB0A0A"
            }
            buffer = [CChar](unsafeUninitializedCapacity: length, initializingWith: { buffer, initializedCount in
                for x in 0 ..< length {
                    buffer[x] = 0
                }
                initializedCount = length
            })
            guard sysctl(&managementInfoBase, 6, &buffer, &length, nil, 0) >= 0 else {
                return "060218BB0A0A"
            }
            let infoData = Data(bytes: buffer, count: length)
            let indexAfterMsghdr = MemoryLayout<if_msghdr>.stride + 1
            guard let rangeOfToken = infoData[indexAfterMsghdr...].range(of: bsdData) else {
                return "060218BB0A0A"
            }
            let lower = rangeOfToken.upperBound
            let upper = lower + MAC_ADDRESS_LENGTH
            let macAddressData = infoData[lower ..< upper]
            let addressBytes = macAddressData.map { String(format: "%02x", $0) }
            return addressBytes.joined().uppercased()
        #else
            return "060218BB0A0A"
        #endif
    }
    public static func base64Enclude(_ data: Data) -> String {
        return data.base64EncodedString()
    }
    public static func base64Decode(_ string: String) -> Data? {
        return Data(base64Encoded: string)
    }
    
    // 新增：从storeFront代码获取国家代码
    public static func countryCodeFromStoreFront(_ storeFront: String) -> String {
        // 提取storeFront代码的前6位数字
        let storeFrontCode = String(storeFront.prefix(6))
        
        // 查找对应的国家代码
        for (code, regionCode) in storeFrontToCountryCodeMap {
            if code == storeFrontCode {
                return regionCode
            }
        }
        
        // 如果没有找到匹配的，尝试解析storeFront字符串
        if let range = storeFront.range(of: "-") {
            let code = String(storeFront[..<range.lowerBound])
            if let regionCode = storeFrontToCountryCodeMap[code] {
                return regionCode
            }
        }
        
        // 默认返回US
        return ""
    }
}
// MARK: - 文件系统扩展
extension Apple {
    public static func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    public static func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    public static var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    public static var temporaryDirectory: URL {
        return FileManager.default.temporaryDirectory
    }
    public static var configDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("APP").appendingPathComponent("Config")
        try? createDirectory(at: url)
        return url
    }
}
// MARK: - 请求实现
struct iTunesSearchRequest: HTTPRequest {
    let type: EntityType
    let term: String
    let limit: Int
    let region: String
    var method: HTTPMethod { .get }
    var endpoint: HTTPEndpoint { iTunesSearchEndpoint(type: type, term: term, limit: limit, region: region) }
    var headers: [String: String] { [:] }
    var payload: HTTPPayload? { nil }
}
struct iTunesLookupRequest: HTTPRequest {
    let type: EntityType
    let bundleIdentifier: String
    let region: String
    var method: HTTPMethod { .get }
    var endpoint: HTTPEndpoint { iTunesLookupEndpoint(type: type, bundleIdentifier: bundleIdentifier, region: region) }
    var headers: [String: String] { [:] }
    var payload: HTTPPayload? { nil }
}
struct StoreAuthenticateRequest: HTTPRequest {
    let email: String
    let password: String
    let code: String?
    var method: HTTPMethod { .post }
    var endpoint: HTTPEndpoint {
        let guid = Apple.overrideGUID ?? Apple.generateMACBasedGUID()
        return StoreAuthenticateEndpoint(hasMFA: code != nil, guid: guid)
    }
    var headers: [String: String] {
        [
            "User-Agent": "Configurator/2.15 (Macintosh; OS X 11.0.0; 16G29) AppleWebKit/2603.3.8",
            "Content-Type": "application/x-www-form-urlencoded"
        ]
    }
    var payload: HTTPPayload? {
        let guid = Apple.overrideGUID ?? Apple.generateMACBasedGUID()
        return .xml([
            "appleId": email,
            "attempt": "\(code == nil ? "4" : "2")",
            "createSession": "true",
            "guid": guid,
            "password": "\(password)\(code ?? "")",
            "rmp": "0",
            "why": "signIn"
        ])
    }
}
struct StoreDownloadRequest: HTTPRequest {
    let identifier: String
    let directoryServicesIdentifier: String
    let externalVersionId: String?
    var method: HTTPMethod { .post }
    var endpoint: HTTPEndpoint {
        let guid = Apple.overrideGUID ?? Apple.generateMACBasedGUID()
        return StoreDownloadEndpoint(guid: guid)
    }
    var headers: [String: String] {
        [
            "User-Agent": "Configurator/2.15 (Macintosh; OS X 11.0.0; 16G29) AppleWebKit/2603.3.8",
            "Content-Type": "application/x-apple-plist",
            "X-Dsid": directoryServicesIdentifier,
            "iCloud-DSID": directoryServicesIdentifier
        ]
    }
    var payload: HTTPPayload? {
        var params = [
            "creditDisplay": "",
            "guid": Apple.overrideGUID ?? Apple.generateMACBasedGUID(),
            "salableAdamId": identifier
        ]
        if let externalVersionId = externalVersionId {
            params["externalVersionId"] = externalVersionId
        }
        return .xml(params)
    }
}
struct StoreBuyRequest: HTTPRequest {
    let token: String
    let directoryServicesIdentifier: String
    let trackID: Int
    let countryCode: String
    var method: HTTPMethod { .post }
    var endpoint: HTTPEndpoint { StoreBuyEndpoint() }
    var headers: [String: String] {
        [
            "Content-Type": "application/x-apple-plist",
            "iCloud-DSID": directoryServicesIdentifier,
            "X-Dsid": directoryServicesIdentifier,
            "X-Apple-Store-Front": Apple.storeFrontCodeMap[countryCode] ?? "",
            "X-Token": token
        ]
    }
    var payload: HTTPPayload? {
        .xml([
            "salableAdamId": trackID,
            "productType": "C",
            "pricingParameters": "STDQ"
        ])
    }
}
// MARK: - 端点实现
struct iTunesSearchEndpoint: HTTPEndpoint {
    let type: EntityType
    let term: String
    let limit: Int
    let region: String
    var url: URL {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "country", value: region),
            URLQueryItem(name: "entity", value: type.rawValue),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return components.url!
    }
}
struct iTunesLookupEndpoint: HTTPEndpoint {
    let type: EntityType
    let bundleIdentifier: String
    let region: String
    var url: URL {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleIdentifier),
            URLQueryItem(name: "country", value: region),
            URLQueryItem(name: "entity", value: type.rawValue)
        ]
        return components.url!
    }
}
struct StoreAuthenticateEndpoint: HTTPEndpoint {
    let hasMFA: Bool
    let guid: String
    var url: URL {
        // 完全匹配旧版本的认证端点实现
        var components = URLComponents(string: "/auth/v1/native/fast")!
        components.scheme = "https"
        components.host = "auth.itunes.apple.com"
        components.queryItems = [URLQueryItem(name: "guid", value: guid)]
        return components.url!
    }
}
struct StoreDownloadEndpoint: HTTPEndpoint {
    let guid: String
    var url: URL {
        var components = URLComponents(string: "https://p25-buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/volumeStoreDownloadProduct")!
        components.queryItems = [URLQueryItem(name: "guid", value: guid)]
        return components.url!
    }
}
struct StoreBuyEndpoint: HTTPEndpoint {
    var url: URL {
        URL(string: "https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/buyProduct")!
    }
}
// MARK: - 错误类型
public enum HTTPClientError: Error {
    case invalidResponse
    case downloadFailed
    case encodingFailed
}
public enum iTunesClientError: Error {
    case appNotFound
    case invalidResponse
}
public enum StoreClientError: Error {
    case authenticationFailed(String)
    case purchaseFailed(String)
    case downloadFailed(String)
    case invalidCredentials
    case twoFactorRequired
    case accountLocked
}
public enum DownloaderError: Error {
    case downloadFailed
    case signatureFailed
    case fileSystemError
}
// MARK: - IPA Signature Processing
// Note: Signature processing is now handled by SignatureClient.swift
public enum AuthenticatorError: Error {
    case keychainError
    case credentialsNotFound
    case invalidCredentials
}
// MARK: - String 扩展
extension String {
    func addingPercentEncoding(charSet: CharacterSet) -> String? {
        return addingPercentEncoding(withAllowedCharacters: charSet)
    }
}
extension CharacterSet {
    static let urlQueryAllowed = CharacterSet.urlQueryAllowed
}
