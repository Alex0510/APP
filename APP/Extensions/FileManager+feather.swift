import Foundation

extension FileManager {
    public func moveAndStore(_ url: URL, with prepend: String, completion: @escaping (URL) -> Void) {
        let destination = _getDestination(url, with: prepend)
        
        DispatchQueue.global(qos: .userInitiated).async {
            var didStartAccessing = false
            if url.startAccessingSecurityScopedResource() {
                didStartAccessing = true
            }
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                try self.createDirectoryIfNeeded(at: destination.temp)
                // Remove existing file if any to avoid copyItem throwing errors
                try? self.removeFileIfNeeded(at: destination.dest)
                try self.copyItem(at: url, to: destination.dest)
                if self.fileExists(atPath: destination.dest.path) {
                    DispatchQueue.main.async {
                        completion(destination.dest)
                    }
                }
            } catch {
                // Swallow errors to avoid crashing; caller will not be notified on failure
            }
        }
    }
    
    public func deleteStored(_ url: URL, completion: @escaping (URL) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                // Ignore deletion error
            }
            DispatchQueue.main.async {
                completion(url)
            }
        }
    }
    
    private func _getDestination(_ url: URL, with prepend: String) -> (temp: URL, dest: URL) {
        let tempDir = self.temporaryDirectory.appendingPathComponent("\(prepend)_\(UUID().uuidString)", isDirectory: true)
        let destinationUrl = tempDir.appendingPathComponent(url.lastPathComponent)
        return (tempDir, destinationUrl)
    }
}