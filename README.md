# Directory Bookmarks

A Flutter plugin for cross-platform multi-bookmark directory management and secure file operations. This plugin provides a consistent API for managing multiple directory bookmarks with platform-specific security features.

## ⚠️ Breaking Changes in v2.0.0

**Version 2.0.0 is a complete API redesign** that replaces the single-bookmark model with multi-bookmark support. This is a breaking change with no backward compatibility.

**If you're upgrading from v1.x**, please see the [Migration Guide](#migration-guide-from-v1x-to-v20) below.

## Platform Support

| Platform | Status | Implementation Details |
|----------|--------|----------------------|
| macOS    | ✅ Fully Supported | Security-scoped bookmarks with LRU resource management |
| Linux    | ✅ Fully Supported | XDG config directory with JSON storage |
| Android  | 🚧 Planned | Storage Access Framework (planned for future release) |
| iOS      | 🚧 Planned | Security-scoped bookmarks (planned for future release) |
| Windows  | 🚧 Planned | Future implementation |

> **Note**: This package currently supports macOS and Linux platforms with full functionality. Android, iOS, and Windows support is planned for future releases.

## Features

- **Multi-Bookmark Management**: Create and manage multiple directory bookmarks with unique identifiers
- **Direct Reference Model**: All operations use explicit bookmark identifiers (no global state)
- **Secure Directory Access**: Platform-specific secure directory access mechanisms
  - macOS: Security-scoped bookmarks with on-demand LRU activation
  - Linux: XDG-compliant config directory with JSON storage
- **File Operations**: Read, write, list, and delete files in any bookmarked directory
- **Persistent Access**: Maintain access to directories across app restarts
- **Permission Handling**: Built-in permission management per bookmark
- **Resource Management**: Automatic cleanup of system resources (macOS: max 5 active bookmarks with LRU eviction)
- **Metadata Support**: Attach custom metadata to each bookmark

## Getting Started

Add the package to your pubspec.yaml:

```yaml
dependencies:
  directory_bookmarks: ^2.0.0
```

### Platform-Specific Setup

#### macOS (Fully Supported)

1. Enable App Sandbox and required entitlements in your macOS app. Add the following to your entitlements files (`macos/Runner/Release.entitlements` and `macos/Runner/DebugProfile.entitlements`):

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

2. Register the plugin in your `AppDelegate.swift`:

```swift
import directory_bookmarks

class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let mainWindow = mainFlutterWindow else { return }
    guard let controller = mainWindow.contentViewController as? FlutterViewController else { return }
    DirectoryBookmarksPlugin.register(with: controller.registrar(forPlugin: "DirectoryBookmarksPlugin"))
    super.applicationDidFinishLaunching(notification)
  }
}
```

**macOS Implementation Details:**
- Stores bookmarks in `UserDefaults` with separate dictionaries for bookmark data and metadata
- Implements LRU (Least Recently Used) resource management: maximum 5 active security-scoped resources
- On-demand activation: security-scoped resources are only activated when accessed
- Automatic cleanup: least-recently-used resources are released when limit is reached

#### Linux (Fully Supported)

No special setup required for standard desktop applications.

**Linux Implementation Details:**
- Bookmark storage: `~/.config/directory_bookmarks/bookmarks.json`
- Uses nlohmann/json library for robust JSON parsing
- Atomic writes (temp file + rename) to prevent corruption
- Standard POSIX permission checking
- Automatic directory creation for config files

**Future Enhancement:** XDG Desktop Portal integration planned for Flatpak/Snap sandboxed environments.

#### Other Platforms

Android, iOS, and Windows support is planned for future releases. Using this package on these platforms will result in an `UnsupportedError`.

## API Reference

### Bookmark Management

#### Create a Bookmark

```dart
Future<String?> createBookmark(
  String identifier,
  String directoryPath, {
  Map<String, dynamic>? metadata,
})
```

Creates a new bookmark with a unique identifier. Returns the identifier on success, null on failure.

**Throws:**
- `DirectoryNotFoundException` if the directory doesn't exist
- `BookmarkAlreadyExistsException` if the identifier is already in use

#### List All Bookmarks

```dart
Future<List<BookmarkData>> listBookmarks()
```

Returns a list of all bookmarks. Each `BookmarkData` contains:
- `identifier`: Unique bookmark identifier
- `path`: Directory path
- `createdAt`: Creation timestamp
- `metadata`: Custom metadata map

#### Get a Specific Bookmark

```dart
Future<BookmarkData?> getBookmark(String identifier)
```

Returns bookmark data for the specified identifier, or null if not found.

#### Check if Bookmark Exists

```dart
Future<bool> bookmarkExists(String identifier)
```

Returns true if a bookmark with the given identifier exists.

#### Delete a Bookmark

```dart
Future<bool> deleteBookmark(String identifier)
```

Deletes the bookmark with the given identifier. Returns true on success. Note: This only deletes the bookmark reference, not the directory or its files.

#### Update Bookmark Metadata

```dart
Future<bool> updateBookmarkMetadata(
  String identifier,
  Map<String, dynamic> metadata,
)
```

Updates the custom metadata for a bookmark. Returns true on success.

**Throws:**
- `BookmarkNotFoundException` if the bookmark doesn't exist

### File Operations

All file operations require a bookmark identifier as the first parameter.

#### Save File (Raw Bytes)

```dart
Future<bool> saveFile(
  String identifier,
  String fileName,
  List<int> data,
)
```

Saves raw bytes to a file in the bookmarked directory.

#### Save String to File

```dart
Future<bool> saveStringToFile(
  String identifier,
  String fileName,
  String content,
)
```

Saves text content to a file in the bookmarked directory.

#### Save Bytes to File

```dart
Future<bool> saveBytesToFile(
  String identifier,
  String fileName,
  Uint8List bytes,
)
```

Saves binary data to a file in the bookmarked directory.

#### Read File (Raw Bytes)

```dart
Future<List<int>?> readFile(
  String identifier,
  String fileName,
)
```

Reads raw bytes from a file. Returns null if file not found.

#### Read String from File

```dart
Future<String?> readStringFromFile(
  String identifier,
  String fileName,
)
```

Reads text content from a file. Returns null if file not found.

#### Read Bytes from File

```dart
Future<Uint8List?> readBytesFromFile(
  String identifier,
  String fileName,
)
```

Reads binary data from a file. Returns null if file not found.

#### List Files

```dart
Future<List<String>> listFiles(String identifier)
```

Lists all non-hidden files in the bookmarked directory.

**Throws:**
- `BookmarkNotFoundException` if the bookmark doesn't exist

#### Delete File

```dart
Future<bool> deleteFile(
  String identifier,
  String fileName,
)
```

Deletes a file in the bookmarked directory. Returns true on success.

**Throws:**
- `BookmarkNotFoundException` if the bookmark doesn't exist
- `PermissionDeniedException` if write permission is denied

#### Check if File Exists

```dart
Future<bool> fileExists(
  String identifier,
  String fileName,
)
```

Returns true if the file exists in the bookmarked directory.

### Permission Management

#### Check Write Permission

```dart
Future<bool> hasWritePermission(String identifier)
```

Checks if write permission is granted for the bookmarked directory.

#### Request Write Permission

```dart
Future<bool> requestWritePermission(String identifier)
```

Requests write permission for the bookmarked directory. On Linux/macOS desktop, this simply returns the current permission status (no runtime dialogs).

## Usage Examples

### Creating and Managing Multiple Bookmarks

```dart
import 'package:directory_bookmarks/directory_bookmarks.dart';
import 'package:file_picker/file_picker.dart';

Future<void> createMultipleBookmarks() async {
  // Create bookmark for project directory
  final projectPath = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Select project directory',
  );

  if (projectPath != null) {
    await DirectoryBookmarkHandler.createBookmark(
      'my-project',
      projectPath,
      metadata: {
        'type': 'project',
        'created': DateTime.now().toIso8601String(),
      },
    );
  }

  // Create bookmark for documents directory
  final docsPath = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Select documents directory',
  );

  if (docsPath != null) {
    await DirectoryBookmarkHandler.createBookmark(
      'documents',
      docsPath,
      metadata: {
        'type': 'documents',
        'created': DateTime.now().toIso8601String(),
      },
    );
  }

  // List all bookmarks
  final bookmarks = await DirectoryBookmarkHandler.listBookmarks();
  for (var bookmark in bookmarks) {
    print('${bookmark.identifier}: ${bookmark.path}');
  }
}
```

### Working with Files in Different Bookmarks

```dart
Future<void> workWithMultipleBookmarks() async {
  // Save a file to project bookmark
  await DirectoryBookmarkHandler.saveStringToFile(
    'my-project',
    'config.json',
    '{"version": "1.0.0"}',
  );

  // Save a file to documents bookmark
  await DirectoryBookmarkHandler.saveStringToFile(
    'documents',
    'notes.txt',
    'Meeting notes from today',
  );

  // Read files from different bookmarks
  final config = await DirectoryBookmarkHandler.readStringFromFile(
    'my-project',
    'config.json',
  );

  final notes = await DirectoryBookmarkHandler.readStringFromFile(
    'documents',
    'notes.txt',
  );

  // List files in each bookmark
  final projectFiles = await DirectoryBookmarkHandler.listFiles('my-project');
  final documentFiles = await DirectoryBookmarkHandler.listFiles('documents');

  print('Project files: $projectFiles');
  print('Document files: $documentFiles');
}
```

### Complete Example with Error Handling

```dart
import 'package:directory_bookmarks/directory_bookmarks.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

Future<void> completeExample() async {
  // Check platform support
  if (!(defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux)) {
    print('Platform not supported');
    return;
  }

  try {
    // Select and create a bookmark
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select a directory to bookmark',
    );

    if (path == null) {
      print('No directory selected');
      return;
    }

    // Create bookmark with identifier
    final identifier = await DirectoryBookmarkHandler.createBookmark(
      'my-workspace',
      path,
      metadata: {
        'description': 'My workspace directory',
        'created': DateTime.now().toIso8601String(),
      },
    );

    if (identifier == null) {
      print('Failed to create bookmark');
      return;
    }

    print('Bookmark created: $identifier');

    // Check write permission
    final hasPermission = await DirectoryBookmarkHandler.hasWritePermission(
      identifier,
    );

    if (!hasPermission) {
      print('No write permission');
      return;
    }

    // Write a file
    final writeSuccess = await DirectoryBookmarkHandler.saveStringToFile(
      identifier,
      'hello.txt',
      'Hello from Directory Bookmarks!',
    );

    if (writeSuccess) {
      print('File written successfully');
    }

    // List files
    final files = await DirectoryBookmarkHandler.listFiles(identifier);
    print('Files in bookmark: $files');

    // Read the file
    final content = await DirectoryBookmarkHandler.readStringFromFile(
      identifier,
      'hello.txt',
    );

    if (content != null) {
      print('File content: $content');
    }

    // Update metadata
    await DirectoryBookmarkHandler.updateBookmarkMetadata(
      identifier,
      {
        'description': 'My workspace directory',
        'lastAccessed': DateTime.now().toIso8601String(),
      },
    );

    // Get bookmark info
    final bookmark = await DirectoryBookmarkHandler.getBookmark(identifier);
    if (bookmark != null) {
      print('Bookmark path: ${bookmark.path}');
      print('Created at: ${bookmark.createdAt}');
      print('Metadata: ${bookmark.metadata}');
    }

  } on DirectoryNotFoundException catch (e) {
    print('Directory not found: $e');
  } on BookmarkAlreadyExistsException catch (e) {
    print('Bookmark already exists: $e');
  } on BookmarkNotFoundException catch (e) {
    print('Bookmark not found: $e');
  } on PermissionDeniedException catch (e) {
    print('Permission denied: $e');
  } on UnsupportedError catch (e) {
    print('Unsupported platform: $e');
  } catch (e) {
    print('Unexpected error: $e');
  }
}
```

## Migration Guide from v1.x to v2.0

Version 2.0 introduces a complete API redesign. Here's how to migrate your code:

### 1. Creating Bookmarks

**Old API (v1.x):**
```dart
final success = await DirectoryBookmarkHandler.saveBookmark(
  path,
  metadata: metadata,
);
```

**New API (v2.0):**
```dart
final identifier = await DirectoryBookmarkHandler.createBookmark(
  'unique-identifier',  // NEW: provide an identifier
  path,
  metadata: metadata,
);
```

**Key changes:**
- Now requires a unique identifier as the first parameter
- Returns the identifier on success (String?) instead of bool
- Throws `BookmarkAlreadyExistsException` if identifier is already used

### 2. Resolving Bookmarks

**Old API (v1.x):**
```dart
final bookmark = await DirectoryBookmarkHandler.resolveBookmark();
```

**New API (v2.0):**
```dart
// List all bookmarks
final bookmarks = await DirectoryBookmarkHandler.listBookmarks();

// Or get a specific bookmark by identifier
final bookmark = await DirectoryBookmarkHandler.getBookmark('my-identifier');
```

**Key changes:**
- No single "current" bookmark - must specify which bookmark to work with
- Use `listBookmarks()` to get all bookmarks
- Use `getBookmark(identifier)` to get a specific bookmark

### 3. File Operations

**Old API (v1.x):**
```dart
// No identifier needed - operated on the single bookmarked directory
await DirectoryBookmarkHandler.saveStringToFile(
  'file.txt',
  content,
);

await DirectoryBookmarkHandler.readStringFromFile('file.txt');
await DirectoryBookmarkHandler.listFiles();
```

**New API (v2.0):**
```dart
// All operations require bookmark identifier
await DirectoryBookmarkHandler.saveStringToFile(
  'my-identifier',  // NEW: specify which bookmark
  'file.txt',
  content,
);

await DirectoryBookmarkHandler.readStringFromFile('my-identifier', 'file.txt');
await DirectoryBookmarkHandler.listFiles('my-identifier');
await DirectoryBookmarkHandler.deleteFile('my-identifier', 'file.txt');  // NEW
await DirectoryBookmarkHandler.fileExists('my-identifier', 'file.txt');  // NEW
```

**Key changes:**
- All file operations now require a bookmark identifier as the first parameter
- Added `deleteFile()` and `fileExists()` methods

### 4. Permission Management

**Old API (v1.x):**
```dart
final hasPermission = await DirectoryBookmarkHandler.hasWritePermission();
await DirectoryBookmarkHandler.requestWritePermission();
```

**New API (v2.0):**
```dart
final hasPermission = await DirectoryBookmarkHandler.hasWritePermission(
  'my-identifier',  // NEW: specify which bookmark
);
await DirectoryBookmarkHandler.requestWritePermission('my-identifier');
```

**Key changes:**
- Permission methods now require a bookmark identifier parameter

### 5. New Features in v2.0

Features not available in v1.x:

```dart
// Delete bookmarks
await DirectoryBookmarkHandler.deleteBookmark('my-identifier');

// Check if bookmark exists
final exists = await DirectoryBookmarkHandler.bookmarkExists('my-identifier');

// Update bookmark metadata
await DirectoryBookmarkHandler.updateBookmarkMetadata(
  'my-identifier',
  {'key': 'value'},
);

// Delete files
await DirectoryBookmarkHandler.deleteFile('my-identifier', 'file.txt');

// Check if file exists
final fileExists = await DirectoryBookmarkHandler.fileExists(
  'my-identifier',
  'file.txt',
);
```

### 6. Platform Support Changes

**Old (v1.x):**
- macOS: Supported
- Android: Partial support
- Linux: Supported

**New (v2.0):**
- macOS: Fully supported (with LRU resource management)
- Linux: Fully supported (with improved JSON storage)
- Android: Not supported (planned for future release)
- iOS, Windows: Not supported (planned for future release)

### Migration Checklist

- [ ] Replace all `saveBookmark()` calls with `createBookmark()` and provide identifiers
- [ ] Replace `resolveBookmark()` with `listBookmarks()` or `getBookmark(identifier)`
- [ ] Add bookmark identifier as first parameter to all file operations
- [ ] Add bookmark identifier to permission check methods
- [ ] Update error handling to catch new exception types:
  - `BookmarkNotFoundException`
  - `BookmarkAlreadyExistsException`
- [ ] Remove Android-specific code (if any) - now unsupported
- [ ] Test on macOS/Linux to verify multi-bookmark functionality
- [ ] Update UI to show multiple bookmarks (if applicable)

## Features and Bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/queiul/directory_bookmarks/issues).

## Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) to get started.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
