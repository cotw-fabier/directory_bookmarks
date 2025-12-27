## 2.0.0

**⚠️ BREAKING CHANGES - Complete API redesign**

This is a major version with breaking changes and no backward compatibility with v1.x. The entire API has been redesigned to support multiple concurrent bookmarks instead of a single global bookmark.

### Breaking Changes

#### API Changes
- **Removed** `saveBookmark()` - replaced with `createBookmark()` which requires an identifier
- **Removed** `resolveBookmark()` - replaced with `listBookmarks()` and `getBookmark(identifier)`
- **Changed** All file operations now require a bookmark identifier as the first parameter:
  - `saveFile(identifier, fileName, data)` (was: `saveFile(fileName, data)`)
  - `saveStringToFile(identifier, fileName, content)` (was: `saveStringToFile(fileName, content)`)
  - `saveBytesToFile(identifier, fileName, bytes)` (was: `saveBytesToFile(fileName, bytes)`)
  - `readFile(identifier, fileName)` (was: `readFile(fileName)`)
  - `readStringFromFile(identifier, fileName)` (was: `readStringFromFile(fileName)`)
  - `readBytesFromFile(identifier, fileName)` (was: `readBytesFromFile(fileName)`)
  - `listFiles(identifier)` (was: `listFiles()`)
- **Changed** Permission methods now require bookmark identifier:
  - `hasWritePermission(identifier)` (was: `hasWritePermission()`)
  - `requestWritePermission(identifier)` (was: `requestWritePermission()`)

#### Platform Support Changes
- **Removed** Android support temporarily (planned for future release)
- **Updated** Platform check now only allows macOS and Linux

#### Data Model Changes
- **Added** `identifier` field to `BookmarkData` class (required)
- **Added** Equality operators to `BookmarkData` based on identifier

### New Features

#### Bookmark Management
- **New** `createBookmark(identifier, path, {metadata})` - Create bookmark with unique identifier
- **New** `listBookmarks()` - List all bookmarks
- **New** `getBookmark(identifier)` - Get specific bookmark by identifier
- **New** `deleteBookmark(identifier)` - Delete a bookmark
- **New** `bookmarkExists(identifier)` - Check if bookmark exists
- **New** `updateBookmarkMetadata(identifier, metadata)` - Update bookmark metadata

#### File Operations
- **New** `deleteFile(identifier, fileName)` - Delete files in bookmarked directories
- **New** `fileExists(identifier, fileName)` - Check if file exists

#### Exception Handling
- **New** `BookmarkNotFoundException` - Thrown when bookmark doesn't exist
- **New** `BookmarkAlreadyExistsException` - Thrown when creating duplicate bookmark

### Improvements

#### macOS Implementation
- **Improved** Resource management with LRU (Least Recently Used) strategy
- **Added** On-demand activation of security-scoped resources
- **Added** Maximum 5 concurrent active bookmarks with automatic cleanup
- **Changed** Storage now uses separate dictionaries for bookmark data and metadata
- **Changed** Bookmark data stored in `UserDefaults` with keys:
  - `DirectoryBookmarks` (was: `SavedDirectoryBookmark`)
  - `DirectoryBookmarksMetadata`

#### Linux Implementation
- **Improved** JSON parsing using nlohmann/json library (header-only)
- **Changed** Storage location: `~/.config/directory_bookmarks/bookmarks.json` (was: `bookmark.json`)
- **Added** Multi-bookmark support with version field in JSON structure
- **Improved** Atomic writes with temp file + rename pattern
- **Added** Robust error handling for JSON parse failures

#### Example App
- **Rewritten** Complete redesign demonstrating multi-bookmark usage
- **Added** Bookmark list view with create/delete functionality
- **Added** Per-bookmark file operations
- **Added** Responsive layout (column on narrow screens, row on wide screens)
- **Improved** Error handling and user feedback

### Migration Guide

See README.md for detailed migration instructions. Key migration steps:

1. Replace `saveBookmark(path)` with `createBookmark(identifier, path)`
2. Replace `resolveBookmark()` with `listBookmarks()` or `getBookmark(identifier)`
3. Add bookmark identifier as first parameter to all file operations
4. Add bookmark identifier to permission methods
5. Update error handling to catch new exception types
6. Remove Android-specific code (temporarily unsupported)
7. Update UI to handle multiple bookmarks

### Platform-Specific Notes

**macOS:**
- Implements LRU resource management for optimal performance
- Maximum 5 active security-scoped bookmarks at any time
- Least-recently-used bookmarks automatically released when limit reached

**Linux:**
- New JSON storage format with version field
- Uses nlohmann/json v3.11.3 for robust parsing
- Atomic writes prevent data corruption

**Android:**
- Temporarily removed in v2.0.0
- Planned for future release with full multi-bookmark support

## 0.1.1

* Updated documentation

## 0.1.0

Initial release with the following features:

* Cross-platform directory bookmarking support
* macOS security-scoped bookmarks implementation
  * Persistent directory access across app restarts
  * Proper resource management and cleanup
  * Comprehensive error handling
* Basic Android implementation with Storage Access Framework
* File operations in bookmarked directories:
  * Save files
  * Read files
  * List files
  * Check write permissions
* Example app demonstrating all features
* Comprehensive documentation and platform setup guides