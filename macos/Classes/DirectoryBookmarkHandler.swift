import Cocoa
import FlutterMacOS

class DirectoryBookmarkHandler: NSObject {
    static let shared = DirectoryBookmarkHandler()

    // Storage keys
    private let bookmarksKey = "DirectoryBookmarks"
    private let metadataKey = "DirectoryBookmarksMetadata"

    // Resource management
    private var accessedURLs: [String: URL] = [:]
    private var lastAccessTime: [String: Date] = [:]
    private let maxActiveBookmarks = 5
    private let accessTimeout: TimeInterval = 300 // 5 minutes

    deinit {
        stopAccessingAllURLs()
    }

    // MARK: - Resource Management

    private func stopAccessingAllURLs() {
        for (_, url) in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        accessedURLs.removeAll()
        lastAccessTime.removeAll()
    }

    private func stopAccessingURL(id: String) {
        if let url = accessedURLs[id] {
            url.stopAccessingSecurityScopedResource()
            accessedURLs.removeValue(forKey: id)
            lastAccessTime.removeValue(forKey: id)
        }
    }

    private func cleanupLeastRecentlyUsed() {
        guard let (lruId, _) = lastAccessTime.min(by: { $0.value < $1.value }) else {
            return
        }
        stopAccessingURL(id: lruId)
    }

    private func ensureBookmarkAccessed(id: String) -> URL? {
        // If already accessed and valid, return it
        if let url = accessedURLs[id], url.isDirectory {
            lastAccessTime[id] = Date()
            return url
        }

        // Need to activate - check limit
        if accessedURLs.count >= maxActiveBookmarks {
            cleanupLeastRecentlyUsed()
        }

        // Resolve and start accessing
        guard let url = resolveAndStartAccessing(id: id) else {
            return nil
        }

        accessedURLs[id] = url
        lastAccessTime[id] = Date()
        return url
    }

    private func resolveAndStartAccessing(id: String) -> URL? {
        guard let bookmarkData = loadBookmarkData(id: id) else {
            print("No bookmark data found for id: \(id)")
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // Start accessing the security-scoped resource
            if !url.startAccessingSecurityScopedResource() {
                print("Failed to start accessing security-scoped resource for id: \(id)")
                return nil
            }

            // Verify the URL still exists and is a directory
            guard url.isDirectory else {
                print("Bookmarked path no longer exists or is not a directory for id: \(id)")
                url.stopAccessingSecurityScopedResource()
                return nil
            }

            if isStale {
                print("Bookmark is stale for id: \(id), attempting to recreate")
                if createBookmark(identifier: id, path: url.path, metadata: loadMetadata(id: id)) {
                    return url
                }
                url.stopAccessingSecurityScopedResource()
                return nil
            }

            return url
        } catch {
            print("Failed to resolve bookmark for id \(id): \(error)")
            return nil
        }
    }

    // MARK: - Storage

    private func loadAllBookmarksData() -> [String: Data] {
        return UserDefaults.standard.dictionary(forKey: bookmarksKey) as? [String: Data] ?? [:]
    }

    private func saveAllBookmarksData(_ bookmarks: [String: Data]) {
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }

    private func loadBookmarkData(id: String) -> Data? {
        let allBookmarks = loadAllBookmarksData()
        return allBookmarks[id]
    }

    private func loadAllMetadata() -> [String: [String: Any]] {
        return UserDefaults.standard.dictionary(forKey: metadataKey) as? [String: [String: Any]] ?? [:]
    }

    private func saveAllMetadata(_ metadata: [String: [String: Any]]) {
        UserDefaults.standard.set(metadata, forKey: metadataKey)
    }

    private func loadMetadata(id: String) -> [String: Any]? {
        let allMetadata = loadAllMetadata()
        return allMetadata[id]
    }

    // MARK: - Bookmark Management

    func createBookmark(identifier: String, path: String, metadata: [String: Any]?) -> Bool {
        let url = URL(fileURLWithPath: path)

        // Verify directory exists and is accessible
        guard url.isDirectory else {
            print("Path is not a directory or is not accessible")
            return false
        }

        do {
            // Create security-scoped bookmark
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            // Save bookmark data
            var allBookmarks = loadAllBookmarksData()
            allBookmarks[identifier] = bookmarkData
            saveAllBookmarksData(allBookmarks)

            // Save metadata
            var allMetadata = loadAllMetadata()
            let timestamp = ISO8601DateFormatter().string(from: Date())
            var bookmarkMetadata: [String: Any] = [
                "createdAt": timestamp,
                "path": path
            ]
            if let customMetadata = metadata {
                bookmarkMetadata["metadata"] = customMetadata
            }
            allMetadata[identifier] = bookmarkMetadata
            saveAllMetadata(allMetadata)

            return true
        } catch {
            print("Failed to create bookmark: \(error)")
            return false
        }
    }

    func listBookmarks() -> [[String: Any]] {
        let allBookmarks = loadAllBookmarksData()
        let allMetadata = loadAllMetadata()

        var result: [[String: Any]] = []

        for (id, _) in allBookmarks {
            if let metadata = allMetadata[id] {
                var bookmarkInfo: [String: Any] = [
                    "identifier": id,
                    "path": metadata["path"] ?? "",
                    "createdAt": metadata["createdAt"] ?? ""
                ]
                if let customMetadata = metadata["metadata"] as? [String: Any] {
                    bookmarkInfo["metadata"] = customMetadata
                } else {
                    bookmarkInfo["metadata"] = [:]
                }
                result.append(bookmarkInfo)
            }
        }

        return result
    }

    func getBookmark(identifier: String) -> [String: Any]? {
        let allBookmarks = loadAllBookmarksData()
        let allMetadata = loadAllMetadata()

        guard allBookmarks[identifier] != nil else {
            return nil
        }

        if let metadata = allMetadata[identifier] {
            var bookmarkInfo: [String: Any] = [
                "identifier": identifier,
                "path": metadata["path"] ?? "",
                "createdAt": metadata["createdAt"] ?? ""
            ]
            if let customMetadata = metadata["metadata"] as? [String: Any] {
                bookmarkInfo["metadata"] = customMetadata
            } else {
                bookmarkInfo["metadata"] = [:]
            }
            return bookmarkInfo
        }

        return nil
    }

    func bookmarkExists(identifier: String) -> Bool {
        let allBookmarks = loadAllBookmarksData()
        return allBookmarks[identifier] != nil
    }

    func deleteBookmark(identifier: String) -> Bool {
        // Stop accessing if currently active
        stopAccessingURL(id: identifier)

        // Remove from storage
        var allBookmarks = loadAllBookmarksData()
        var allMetadata = loadAllMetadata()

        guard allBookmarks.removeValue(forKey: identifier) != nil else {
            return false
        }

        allMetadata.removeValue(forKey: identifier)

        saveAllBookmarksData(allBookmarks)
        saveAllMetadata(allMetadata)

        return true
    }

    func updateBookmarkMetadata(identifier: String, metadata: [String: Any]) -> Bool {
        var allMetadata = loadAllMetadata()

        guard var existingMetadata = allMetadata[identifier] else {
            return false
        }

        existingMetadata["metadata"] = metadata
        allMetadata[identifier] = existingMetadata

        saveAllMetadata(allMetadata)

        return true
    }

    // MARK: - File Operations

    func saveFile(bookmarkId: String, fileName: String, data: FlutterStandardTypedData) -> Bool {
        guard let url = ensureBookmarkAccessed(id: bookmarkId) else {
            print("No valid bookmark found for id: \(bookmarkId)")
            return false
        }

        do {
            let fileURL = url.appendingPathComponent(fileName)
            try data.data.write(to: fileURL)
            return true
        } catch {
            print("Failed to save file: \(error)")
            return false
        }
    }

    func readFile(bookmarkId: String, fileName: String) -> FlutterStandardTypedData? {
        guard let url = ensureBookmarkAccessed(id: bookmarkId) else {
            print("No valid bookmark found for id: \(bookmarkId)")
            return nil
        }

        do {
            let fileURL = url.appendingPathComponent(fileName)
            let data = try Data(contentsOf: fileURL)
            return FlutterStandardTypedData(bytes: data)
        } catch {
            print("Failed to read file: \(error)")
            return nil
        }
    }

    func listFiles(bookmarkId: String) -> [String]? {
        guard let url = ensureBookmarkAccessed(id: bookmarkId) else {
            print("No valid bookmark found for id: \(bookmarkId)")
            return nil
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            return contents
                .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false }
                .map { $0.lastPathComponent }
        } catch {
            print("Failed to list files: \(error)")
            return nil
        }
    }

    func deleteFile(bookmarkId: String, fileName: String) -> Bool {
        guard let url = ensureBookmarkAccessed(id: bookmarkId) else {
            print("No valid bookmark found for id: \(bookmarkId)")
            return false
        }

        do {
            let fileURL = url.appendingPathComponent(fileName)
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            print("Failed to delete file: \(error)")
            return false
        }
    }

    func fileExists(bookmarkId: String, fileName: String) -> Bool {
        guard let url = ensureBookmarkAccessed(id: bookmarkId) else {
            return false
        }

        let fileURL = url.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    func hasWritePermission(bookmarkId: String) -> Bool {
        guard let url = ensureBookmarkAccessed(id: bookmarkId) else {
            return false
        }

        return FileManager.default.isWritableFile(atPath: url.path)
    }
}

extension URL {
    var isDirectory: Bool {
        guard let resourceValues = try? resourceValues(forKeys: [.isDirectoryKey]),
              let isDirectory = resourceValues.isDirectory else {
            return false
        }
        return isDirectory
    }
}
