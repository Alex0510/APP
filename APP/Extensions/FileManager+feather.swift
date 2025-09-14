import Foundation

extension FileManager {
    public func moveAndStore(_ url: URL, with prepend: String, completion: @escaping (URL) -> Void) {
        let destination = _getDestination(url, with: prepend)
        
        try? createDirectoryIfNeeded(at: destination.temp)
        
        try? self.copyItem(at: url, to: destination.dest)
        completion(destination.dest)
    }
    
    public func deleteStored(_ url: URL, completion: @escaping (URL) -> Void) {
        try? FileManager.default.removeItem(at: url)
        completion(url)
    }
    
    private func _getDestination(_ url: URL, with prepend: String) -> (temp: URL, dest: URL) {
        let tempDir = self.temporaryDirectory.appendingPathComponent("\(prepend)_\(UUID().uuidString)", isDirectory: true)
        let destinationUrl = tempDir.appendingPathComponent(url.lastPathComponent)
        return (tempDir, destinationUrl)
    }
}