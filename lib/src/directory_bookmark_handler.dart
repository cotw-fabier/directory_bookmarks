import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'models/bookmark_data.dart';
import 'platform/platform_handler.dart';

class DirectoryBookmarkHandler {
  // ============================================================================
  // BOOKMARK MANAGEMENT
  // ============================================================================

  /// Create a new bookmark with the specified identifier
  ///
  /// Returns the identifier on success, null on failure
  /// Throws [DirectoryNotFoundException] if directory doesn't exist
  /// Throws [BookmarkAlreadyExistsException] if identifier is already used
  static Future<String?> createBookmark(
    String identifier,
    String directoryPath, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!await Directory(directoryPath).exists()) {
      throw DirectoryNotFoundException(
          'Directory does not exist: $directoryPath');
    }

    // Check if bookmark already exists
    if (await bookmarkExists(identifier)) {
      throw BookmarkAlreadyExistsException(
          'Bookmark with identifier "$identifier" already exists');
    }

    return PlatformHandler.createBookmark(
      identifier,
      directoryPath,
      metadata: metadata,
    );
  }

  /// List all bookmarks
  ///
  /// Returns list of BookmarkData objects, empty list if none exist
  static Future<List<BookmarkData>> listBookmarks() async {
    return PlatformHandler.listBookmarks();
  }

  /// Get a specific bookmark by identifier
  ///
  /// Returns BookmarkData if found, null otherwise
  static Future<BookmarkData?> getBookmark(String identifier) async {
    return PlatformHandler.getBookmark(identifier);
  }

  /// Check if a bookmark exists
  static Future<bool> bookmarkExists(String identifier) async {
    return PlatformHandler.bookmarkExists(identifier);
  }

  /// Delete a bookmark
  ///
  /// Returns true if deleted, false if not found or deletion failed
  static Future<bool> deleteBookmark(String identifier) async {
    return PlatformHandler.deleteBookmark(identifier);
  }

  /// Update bookmark metadata
  ///
  /// Returns true on success, false if bookmark not found or update failed
  /// Note: Does NOT change the bookmarked path, only metadata
  static Future<bool> updateBookmarkMetadata(
    String identifier,
    Map<String, dynamic> metadata,
  ) async {
    return PlatformHandler.updateBookmarkMetadata(identifier, metadata);
  }

  // ============================================================================
  // FILE OPERATIONS
  // ============================================================================

  /// Save file to the specified bookmarked directory
  ///
  /// Automatically requests write permission if needed
  /// Throws [BookmarkNotFoundException] if bookmark doesn't exist
  /// Throws [PermissionDeniedException] if write permission denied
  static Future<bool> saveFile(
    String identifier,
    String fileName,
    List<int> data,
  ) async {
    if (!await hasWritePermission(identifier)) {
      final hasPermission = await requestWritePermission(identifier);
      if (!hasPermission) {
        throw PermissionDeniedException(
            'Write permission denied for bookmark "$identifier"');
      }
    }
    return PlatformHandler.saveFile(identifier, fileName, data);
  }

  /// Save string content to a file
  static Future<bool> saveStringToFile(
    String identifier,
    String fileName,
    String content,
  ) async {
    final data = utf8.encode(content);
    return saveFile(identifier, fileName, data);
  }

  /// Save bytes to a file
  static Future<bool> saveBytesToFile(
    String identifier,
    String fileName,
    Uint8List bytes,
  ) async {
    return saveFile(identifier, fileName, bytes);
  }

  /// Read file from the specified bookmarked directory
  ///
  /// Returns file data or null if file not found
  /// Throws [BookmarkNotFoundException] if bookmark doesn't exist
  static Future<List<int>?> readFile(
    String identifier,
    String fileName,
  ) async {
    return PlatformHandler.readFile(identifier, fileName);
  }

  /// Read string content from a file
  static Future<String?> readStringFromFile(
    String identifier,
    String fileName,
  ) async {
    final bytes = await readFile(identifier, fileName);
    if (bytes == null) return null;
    return String.fromCharCodes(bytes);
  }

  /// Read bytes from a file
  static Future<Uint8List?> readBytesFromFile(
    String identifier,
    String fileName,
  ) async {
    final bytes = await readFile(identifier, fileName);
    if (bytes == null) return null;
    return Uint8List.fromList(bytes);
  }

  /// List all files in the specified bookmarked directory
  ///
  /// Returns list of file names, empty list if directory is empty
  /// Throws [BookmarkNotFoundException] if bookmark doesn't exist
  static Future<List<String>> listFiles(String identifier) async {
    final files = await PlatformHandler.listFiles(identifier);
    return files ?? [];
  }

  /// Delete a file in the bookmarked directory
  ///
  /// Returns true if deleted, false if file not found or deletion failed
  /// Throws [BookmarkNotFoundException] if bookmark doesn't exist
  /// Throws [PermissionDeniedException] if write permission denied
  static Future<bool> deleteFile(
    String identifier,
    String fileName,
  ) async {
    if (!await hasWritePermission(identifier)) {
      throw PermissionDeniedException(
          'Write permission denied for bookmark "$identifier"');
    }
    return PlatformHandler.deleteFile(identifier, fileName);
  }

  /// Check if a file exists in the bookmarked directory
  static Future<bool> fileExists(
    String identifier,
    String fileName,
  ) async {
    return PlatformHandler.fileExists(identifier, fileName);
  }

  // ============================================================================
  // PERMISSION MANAGEMENT
  // ============================================================================

  /// Check if we have write permission for the specified bookmark
  static Future<bool> hasWritePermission(String identifier) async {
    return PlatformHandler.hasWritePermission(identifier);
  }

  /// Request write permission for the specified bookmark
  static Future<bool> requestWritePermission(String identifier) async {
    return PlatformHandler.requestWritePermission(identifier);
  }
}

class DirectoryNotFoundException implements Exception {
  final String message;
  DirectoryNotFoundException(this.message);
  @override
  String toString() => 'DirectoryNotFoundException: $message';
}

class PermissionDeniedException implements Exception {
  final String message;
  PermissionDeniedException(this.message);
  @override
  String toString() => 'PermissionDeniedException: $message';
}

class BookmarkNotFoundException implements Exception {
  final String message;
  BookmarkNotFoundException(this.message);
  @override
  String toString() => 'BookmarkNotFoundException: $message';
}

class BookmarkAlreadyExistsException implements Exception {
  final String message;
  BookmarkAlreadyExistsException(this.message);
  @override
  String toString() => 'BookmarkAlreadyExistsException: $message';
}
