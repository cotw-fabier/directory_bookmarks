import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../directory_bookmarks.dart';

abstract class PlatformHandler {
  static const _channel =
      MethodChannel('com.example.directory_bookmarks/bookmark');

  /// Throws an UnsupportedError if the current platform is not supported
  static void _checkPlatformSupport() {
    if (!_isPlatformSupported) {
      throw UnsupportedError(
          'Platform ${defaultTargetPlatform.name} is not supported yet. '
          'Currently supported platforms: macOS (full support), Linux (full support). '
          'Android, iOS, and Windows support is planned for future releases.');
    }
  }

  /// Check if the current platform is supported
  static bool get _isPlatformSupported {
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  // ============================================================================
  // BOOKMARK MANAGEMENT
  // ============================================================================

  /// Create a new bookmark
  static Future<String?> createBookmark(
    String identifier,
    String path, {
    Map<String, dynamic>? metadata,
  }) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('createBookmark', {
        'identifier': identifier,
        'path': path,
        'metadata': metadata,
      });
      return result as String?;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// List all bookmarks
  static Future<List<BookmarkData>> listBookmarks() async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('listBookmarks');
      if (result == null) return [];

      final List<dynamic> bookmarksList = result as List<dynamic>;
      return bookmarksList.map((item) {
        final Map<String, dynamic> bookmarkMap;
        if (item is Map<Object?, Object?>) {
          bookmarkMap = Map<String, dynamic>.from(
              item.map((key, value) => MapEntry(key.toString(), value)));
        } else {
          bookmarkMap = Map<String, dynamic>.from(item);
        }
        return BookmarkData.fromJson(bookmarkMap);
      }).toList();
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Get a specific bookmark
  static Future<BookmarkData?> getBookmark(String identifier) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('getBookmark', {
        'identifier': identifier,
      });

      if (result == null) return null;

      final Map<String, dynamic> bookmarkData;
      if (result is Map<Object?, Object?>) {
        bookmarkData = Map<String, dynamic>.from(
            result.map((key, value) => MapEntry(key.toString(), value)));
      } else {
        bookmarkData = Map<String, dynamic>.from(result);
      }
      return BookmarkData.fromJson(bookmarkData);
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Check if bookmark exists
  static Future<bool> bookmarkExists(String identifier) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('bookmarkExists', {
        'identifier': identifier,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Delete a bookmark
  static Future<bool> deleteBookmark(String identifier) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('deleteBookmark', {
        'identifier': identifier,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Update bookmark metadata
  static Future<bool> updateBookmarkMetadata(
    String identifier,
    Map<String, dynamic> metadata,
  ) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('updateBookmarkMetadata', {
        'identifier': identifier,
        'metadata': metadata,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  // ============================================================================
  // FILE OPERATIONS
  // ============================================================================

  /// Save file to bookmarked directory
  static Future<bool> saveFile(
    String identifier,
    String fileName,
    List<int> data,
  ) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('saveFile', {
        'identifier': identifier,
        'fileName': fileName,
        'data': data,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Read file from bookmarked directory
  static Future<List<int>?> readFile(
    String identifier,
    String fileName,
  ) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('readFile', {
        'identifier': identifier,
        'fileName': fileName,
      });
      return result != null ? List<int>.from(result) : null;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// List files in bookmarked directory
  static Future<List<String>?> listFiles(String identifier) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('listFiles', {
        'identifier': identifier,
      });
      return result != null ? List<String>.from(result) : null;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Delete file in bookmarked directory
  static Future<bool> deleteFile(
    String identifier,
    String fileName,
  ) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('deleteFile', {
        'identifier': identifier,
        'fileName': fileName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Check if file exists in bookmarked directory
  static Future<bool> fileExists(
    String identifier,
    String fileName,
  ) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('fileExists', {
        'identifier': identifier,
        'fileName': fileName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  // ============================================================================
  // PERMISSION MANAGEMENT
  // ============================================================================

  /// Check write permission
  static Future<bool> hasWritePermission(String identifier) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('hasWritePermission', {
        'identifier': identifier,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Request write permission
  static Future<bool> requestWritePermission(String identifier) async {
    _checkPlatformSupport();
    try {
      final result = await _channel.invokeMethod('requestWritePermission', {
        'identifier': identifier,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw _handlePlatformException(e);
    }
  }

  /// Handle platform-specific exceptions
  static Exception _handlePlatformException(PlatformException e) {
    switch (e.code) {
      case 'DIRECTORY_NOT_FOUND':
        return DirectoryNotFoundException('Directory not found: ${e.message}');
      case 'PERMISSION_DENIED':
        return PermissionDeniedException('Permission denied: ${e.message}');
      case 'BOOKMARK_NOT_FOUND':
        return BookmarkNotFoundException('Bookmark not found: ${e.message}');
      case 'BOOKMARK_ALREADY_EXISTS':
        return BookmarkAlreadyExistsException(
            'Bookmark already exists: ${e.message}');
      default:
        return e;
    }
  }
}
