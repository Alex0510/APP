import Foundation

extension FileManager {
    public func createDirectoryIfNeeded(at url: URL) throws {
        if !self.fileExists(atPath: url.path) {
            try self.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    public func removeFileIfNeeded(at url: URL) throws {
        if self.fileExists(atPath: url.path) {
            try self.removeItem(at: url)
        }
    }
    
    public func moveFileIfNeeded(from sourceURL: URL, to destinationURL: URL) throws {
        if !self.fileExists(atPath: destinationURL.path) {
            try self.moveItem(at: sourceURL, to: destinationURL)
        }
    }
    
    static public func forceWrite(content: String, to filename: String) throws {
        let path = URL.documentsDirectory.appendingPathComponent(filename)
        try content.write(to: path, atomically: true, encoding: .utf8)
    }
    
    public func getPath(in directory: URL, for pathExtension: String) -> URL? {
        guard let contents = try? contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return nil
        }
        
        return contents.first(where: { $0.pathExtension == pathExtension })
    }
}

extension URL {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}