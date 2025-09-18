//
//  LocalFileManager.swift
//  APP
//
//  Created by pxx917144686 on 2025/09/18.
//

import Foundation
import UIKit

class LocalFileManager {
    static let instance = LocalFileManager()
    
    private init() {}
    
    func saveModel<T: Codable>(model: T, modelName: String, folderName: String) {
        // 创建文件夹
        createFolderIfNeeded(folderName: folderName)
        
        // 获取文件路径
        guard let url = getURLForModel(modelName: modelName, folderName: folderName) else {
            return
        }
        
        // 保存数据
        do {
            let data = try JSONEncoder().encode(model)
            try data.write(to: url)
        } catch {
            print("Error saving model: \(error)")
        }
    }
    
    func getModel<T: Codable>(modelName: String, folderName: String, type: T.Type) -> T? {
        guard let url = getURLForModel(modelName: modelName, folderName: folderName) else {
            return nil
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let model = try JSONDecoder().decode(type, from: data)
            return model
        } catch {
            print("Error loading model: \(error)")
            return nil
        }
    }
    
    func getModel<T: Codable>(modelName: String, folderName: String) -> T where T: ExpressibleByArrayLiteral, T.ArrayLiteralElement: Codable {
        guard let url = getURLForModel(modelName: modelName, folderName: folderName) else {
            return [] as! T
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [] as! T
        }
        
        do {
            let data = try Data(contentsOf: url)
            let model = try JSONDecoder().decode(T.self, from: data)
            return model
        } catch {
            print("Error loading model: \(error)")
            return [] as! T
        }
    }
    
    private func createFolderIfNeeded(folderName: String) {
        guard let url = getURLForFolder(folderName: folderName) else {
            return
        }
        
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating folder: \(error)")
            }
        }
    }
    
    private func getURLForFolder(folderName: String) -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent(folderName)
    }
    
    private func getURLForModel(modelName: String, folderName: String) -> URL? {
        guard let folderURL = getURLForFolder(folderName: folderName) else {
            return nil
        }
        return folderURL.appendingPathComponent("\(modelName).json")
    }
    
    // MARK: - Image Management
    
    func saveImage(image: UIImage, imageName: String, folderName: String) {
        createFolderIfNeeded(folderName: folderName)
        
        guard let data = image.jpegData(compressionQuality: 1.0),
              let url = getURLForImage(imageName: imageName, folderName: folderName) else {
            return
        }
        
        do {
            try data.write(to: url)
        } catch {
            print("Error saving image: \(error)")
        }
    }
    
    func getImage(imageName: String, folderName: String) -> UIImage? {
        guard let url = getURLForImage(imageName: imageName, folderName: folderName),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        return UIImage(contentsOfFile: url.path)
    }
    
    private func getURLForImage(imageName: String, folderName: String) -> URL? {
        guard let folderURL = getURLForFolder(folderName: folderName) else {
            return nil
        }
        return folderURL.appendingPathComponent("\(imageName).jpg")
    }
}
