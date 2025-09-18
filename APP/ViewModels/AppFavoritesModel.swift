//
//  AppFavoritesModel.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/20.
//  从iAppStore-SwiftUI-main项目转移并增强
//

import Foundation

class AppFavoritesModel: ObservableObject {
    
    @Published private(set) var favorites: [AppFavorite] {
        didSet {
            saveFavorites()
        }
    }
    
    private let modelName = "AppFavoritesModel"
    private let folderName = "AppFavorites"
    
    init() {
        // 加载收藏记录
        favorites = LocalFileManager.instance.getModel(modelName: modelName, folderName: folderName)
    }
    
    // MARK: Public Methods
    
    func addFavorite(_ appDetail: AppDetail, regionName: String) {
        let favorite = AppFavorite.createFromAppDetail(appDetail, regionName: regionName)
        
        // 检查是否已存在
        if !favoriteExist(appId: favorite.appId, regionName: regionName) {
            favorites.append(favorite)
        }
    }
    
    func removeFavorite(_ favorite: AppFavorite) {
        favorites.removeAll { $0.id == favorite.id }
    }
    
    func removeFavorite(appId: String, regionName: String) {
        favorites.removeAll { $0.appId == appId && $0.regionName == regionName }
    }
    
    func favoriteExist(appId: String, regionName: String) -> Bool {
        return favorites.contains { $0.appId == appId && $0.regionName == regionName }
    }
    
    func removeAt(indexSet: IndexSet) {
        favorites.remove(atOffsets: indexSet)
    }
    
    func clearAllFavorites() {
        favorites.removeAll()
    }
    
    // MARK: Private Methods
    
    private func saveFavorites() {
        LocalFileManager.instance.saveModel(model: favorites, modelName: modelName, folderName: folderName)
    }
}
