//
//  AppDetailModel.swift
//  APP
//
//  Created by pxx917144686 on 2025/09/18.
//

import Foundation
import Combine

class AppDetailModel: ObservableObject {
    
    @Published var appDetail: AppDetail?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var isError: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchAppDetail(appId: String, regionName: String) {
        isLoading = true
        isError = false
        errorMessage = ""
        
        let regionId = TSMGConstants.regionTypeListIds[regionName] ?? "cn"
        let endpoint: APIService.Endpoint = APIService.Endpoint.lookupApp(appid: appId, country: regionId)
        
        APIService.shared.POST(endpoint: endpoint, params: nil) { [weak self] (result: Result<AppDetailM, APIService.APIError>) in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    if response.resultCount > 0 {
                        self?.appDetail = response.results.first
                    } else {
                        self?.isError = true
                        self?.errorMessage = "应用未找到"
                    }
                case .failure(let error):
                    self?.isError = true
                    self?.errorMessage = "加载失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func fetchAppDetailByBundleId(bundleId: String, regionName: String) {
        isLoading = true
        isError = false
        errorMessage = ""
        
        let regionId = TSMGConstants.regionTypeListIds[regionName] ?? "cn"
        let endpoint: APIService.Endpoint = APIService.Endpoint.lookupBundleId(appid: bundleId, country: regionId)
        
        APIService.shared.POST(endpoint: endpoint, params: nil) { [weak self] (result: Result<AppDetailM, APIService.APIError>) in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    if response.resultCount > 0 {
                        self?.appDetail = response.results.first
                    } else {
                        self?.isError = true
                        self?.errorMessage = "应用未找到"
                    }
                case .failure(let error):
                    self?.isError = true
                    self?.errorMessage = "加载失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func clearDetail() {
        appDetail = nil
        errorMessage = ""
        isError = false
    }
}
