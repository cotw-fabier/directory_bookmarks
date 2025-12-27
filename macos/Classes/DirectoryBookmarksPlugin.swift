import Cocoa
import FlutterMacOS

private extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: self)
    }
}

public class DirectoryBookmarksPlugin: NSObject, FlutterPlugin {
    private let bookmarkHandler = DirectoryBookmarkHandler.shared
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.example.directory_bookmarks/bookmark",
            binaryMessenger: registrar.messenger)
        let instance = DirectoryBookmarksPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // MARK: - Bookmark Management
        case "createBookmark":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String,
                  let path = args["path"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for createBookmark",
                    details: "Required arguments: identifier (String), path (String)"
                ))
                return
            }

            // Check if bookmark already exists
            if bookmarkHandler.bookmarkExists(identifier: identifier) {
                result(FlutterError(
                    code: "BOOKMARK_ALREADY_EXISTS",
                    message: "Bookmark with identifier '\(identifier)' already exists",
                    details: nil
                ))
                return
            }

            let metadata = args["metadata"] as? [String: Any]
            let success = bookmarkHandler.createBookmark(identifier: identifier, path: path, metadata: metadata)
            if success {
                result(identifier)
            } else {
                result(nil)
            }

        case "listBookmarks":
            let bookmarks = bookmarkHandler.listBookmarks()
            result(bookmarks)

        case "getBookmark":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for getBookmark",
                    details: "Required arguments: identifier (String)"
                ))
                return
            }

            if let bookmark = bookmarkHandler.getBookmark(identifier: identifier) {
                result(bookmark)
            } else {
                result(nil)
            }

        case "bookmarkExists":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for bookmarkExists",
                    details: "Required arguments: identifier (String)"
                ))
                return
            }

            result(bookmarkHandler.bookmarkExists(identifier: identifier))

        case "deleteBookmark":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for deleteBookmark",
                    details: "Required arguments: identifier (String)"
                ))
                return
            }

            result(bookmarkHandler.deleteBookmark(identifier: identifier))

        case "updateBookmarkMetadata":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String,
                  let metadata = args["metadata"] as? [String: Any] else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for updateBookmarkMetadata",
                    details: "Required arguments: identifier (String), metadata (Map)"
                ))
                return
            }

            result(bookmarkHandler.updateBookmarkMetadata(identifier: identifier, metadata: metadata))

        // MARK: - File Operations
        case "saveFile":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String,
                  let fileName = args["fileName"] as? String,
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for saveFile",
                    details: "Required arguments: identifier (String), fileName (String), data (Uint8List)"
                ))
                return
            }

            if !bookmarkHandler.bookmarkExists(identifier: identifier) {
                result(FlutterError(
                    code: "BOOKMARK_NOT_FOUND",
                    message: "Bookmark with identifier '\(identifier)' not found",
                    details: nil
                ))
                return
            }

            let success = bookmarkHandler.saveFile(bookmarkId: identifier, fileName: fileName, data: data)
            result(success)

        case "readFile":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String,
                  let fileName = args["fileName"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for readFile",
                    details: "Required arguments: identifier (String), fileName (String)"
                ))
                return
            }

            if !bookmarkHandler.bookmarkExists(identifier: identifier) {
                result(FlutterError(
                    code: "BOOKMARK_NOT_FOUND",
                    message: "Bookmark with identifier '\(identifier)' not found",
                    details: nil
                ))
                return
            }

            result(bookmarkHandler.readFile(bookmarkId: identifier, fileName: fileName))

        case "listFiles":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for listFiles",
                    details: "Required arguments: identifier (String)"
                ))
                return
            }

            if !bookmarkHandler.bookmarkExists(identifier: identifier) {
                result(FlutterError(
                    code: "BOOKMARK_NOT_FOUND",
                    message: "Bookmark with identifier '\(identifier)' not found",
                    details: nil
                ))
                return
            }

            result(bookmarkHandler.listFiles(bookmarkId: identifier))

        case "deleteFile":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String,
                  let fileName = args["fileName"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for deleteFile",
                    details: "Required arguments: identifier (String), fileName (String)"
                ))
                return
            }

            if !bookmarkHandler.bookmarkExists(identifier: identifier) {
                result(FlutterError(
                    code: "BOOKMARK_NOT_FOUND",
                    message: "Bookmark with identifier '\(identifier)' not found",
                    details: nil
                ))
                return
            }

            result(bookmarkHandler.deleteFile(bookmarkId: identifier, fileName: fileName))

        case "fileExists":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String,
                  let fileName = args["fileName"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for fileExists",
                    details: "Required arguments: identifier (String), fileName (String)"
                ))
                return
            }

            if !bookmarkHandler.bookmarkExists(identifier: identifier) {
                result(false)
                return
            }

            result(bookmarkHandler.fileExists(bookmarkId: identifier, fileName: fileName))

        // MARK: - Permission Management
        case "hasWritePermission":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for hasWritePermission",
                    details: "Required arguments: identifier (String)"
                ))
                return
            }

            if !bookmarkHandler.bookmarkExists(identifier: identifier) {
                result(false)
                return
            }

            result(bookmarkHandler.hasWritePermission(bookmarkId: identifier))

        case "requestWritePermission":
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments for requestWritePermission",
                    details: "Required arguments: identifier (String)"
                ))
                return
            }

            if !bookmarkHandler.bookmarkExists(identifier: identifier) {
                result(false)
                return
            }

            result(bookmarkHandler.hasWritePermission(bookmarkId: identifier))

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
