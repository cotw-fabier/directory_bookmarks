# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter plugin that provides cross-platform directory bookmarking and secure file operations. The plugin enables persistent access to user-selected directories using platform-specific security features like macOS security-scoped bookmarks.

**Current Platform Support:**
- macOS: Full support (security-scoped bookmarks)
- Android: Partial implementation (Storage Access Framework - in development)
- Linux: Full support (XDG config directory, desktop apps)
- iOS, Windows: Planned

## Development Commands

### Setup and Dependencies
```bash
flutter pub get
```

### Testing
```bash
flutter test
```

### Code Quality
```bash
# Run static analysis
flutter analyze

# Format code
dartfmt -w .
```

### Running the Example App
```bash
cd example
flutter run
```

## Architecture

### Core Architecture

The plugin uses a layered architecture:

1. **Public API Layer** (`lib/directory_bookmarks.dart`): Exports main handler and models
2. **Handler Layer** (`lib/src/directory_bookmark_handler.dart`): `DirectoryBookmarkHandler` provides static methods for all operations
3. **Platform Bridge** (`lib/src/platform/platform_handler.dart`): `PlatformHandler` manages MethodChannel communication with native code
4. **Models** (`lib/src/models/bookmark_data.dart`): Data transfer objects

### Platform Implementation (macOS)

Native implementation in Swift (`macos/Classes/`):
- `DirectoryBookmarksPlugin`: FlutterPlugin that handles MethodChannel calls
- `DirectoryBookmarkHandler`: Singleton that manages security-scoped bookmarks using `UserDefaults` for persistence

**Critical Implementation Details:**

1. **Security-Scoped Resources**: macOS implementation uses `startAccessingSecurityScopedResource()` and must call `stopAccessingSecurityScopedResource()` to clean up. The handler maintains `currentAccessedURL` to track the active resource.

2. **Bookmark Lifecycle**:
   - Creating: `url.bookmarkData(options: [.withSecurityScope])` creates the bookmark
   - Storing: Saved to `UserDefaults` with key "SavedDirectoryBookmark"
   - Resolving: `URL(resolvingBookmarkData:options: [.withSecurityScope])` recreates URL
   - Access: Must call `startAccessingSecurityScopedResource()` before file operations

3. **Stale Bookmark Handling**: When resolving, check `bookmarkDataIsStale` flag and recreate if needed

### Platform Implementation (Linux)

Native implementation in C++ (`linux/`):
- `DirectoryBookmarksPlugin`: GObject-based FlutterPlugin that handles MethodChannel calls
- Direct filesystem operations using C++17 `std::filesystem`
- XDG config directory for bookmark persistence

**Critical Implementation Details:**

1. **Bookmark Persistence**:
   - Location: `~/.config/directory_bookmarks/bookmark.json` (follows XDG Base Directory specification)
   - Format: JSON with `path`, `createdAt`, and `metadata` fields
   - Uses XDG_CONFIG_HOME environment variable, falls back to `~/.config`
   - Atomic writes (write to temp file, then rename)

2. **File Operations**:
   - Direct filesystem access via `std::filesystem` library
   - No special resource lifecycle management needed
   - Permission checks using POSIX `access()` syscall with W_OK flag
   - Files filtered by hidden status (filenames starting with `.` excluded from listings)

3. **Permission Model**:
   - No runtime permission dialogs required for standard desktop apps
   - `hasWritePermission()` checks directory writability using `access()`
   - `requestWritePermission()` returns current permission status (no actual request)
   - Throws `PermissionDeniedException` when write access denied

4. **Future Enhancement**: XDG Desktop Portal support planned for Flatpak/Snap sandboxed environments

### MethodChannel API

Channel name: `com.example.directory_bookmarks/bookmark`

**Methods:**
- `saveDirectoryBookmark`: Args: `{path: String, metadata: Map?}` → Returns: `bool`
- `resolveDirectoryBookmark`: No args → Returns: `{path: String, createdAt: String, metadata: Map}`
- `saveFile`: Args: `{fileName: String, data: Uint8List}` → Returns: `bool`
- `readFile`: Args: `{fileName: String}` → Returns: `Uint8List?`
- `listFiles`: No args → Returns: `List<String>?`
- `hasWritePermission`: No args → Returns: `bool`
- `requestWritePermission`: No args → Returns: `bool`

### Platform-Specific Requirements

#### macOS Setup
Apps using this plugin must have entitlements in `macos/Runner/*.entitlements`:
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

Plugin registration in `AppDelegate.swift` is required (see README example).

#### Android Setup
Requires permissions in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

#### Linux Setup
No special setup required for standard desktop applications.

**Build Requirements:**
- C++17 compiler (for `std::filesystem`)
- Flutter Linux development dependencies
- GTK 3.0+ development libraries

**Runtime Behavior:**
- Bookmark stored in `~/.config/directory_bookmarks/bookmark.json`
- Respects XDG_CONFIG_HOME environment variable
- Config directory created automatically if it doesn't exist
- Standard POSIX filesystem permissions apply

### Error Handling

The plugin uses custom exceptions:
- `DirectoryNotFoundException`: Thrown when directory doesn't exist
- `PermissionDeniedException`: Thrown when write permission is denied
- `UnsupportedError`: Thrown when platform is not supported

Platform exceptions are mapped in `PlatformHandler._handlePlatformException()`.

## Common Patterns

### Platform Support Checking
Always check platform support before operations:
```dart
if (!(defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux)) {
  // Handle unsupported platform
}
```

### Permission Flow
1. Check with `hasWritePermission()`
2. Request if needed with `requestWritePermission()`
3. Handle denial appropriately

### File Operations
All file operations automatically use the currently resolved bookmark. The handler will resolve if needed on each operation.

## Dependencies

Key dependencies:
- `path_provider`: Platform-specific paths
- `permission_handler`: Permission management
- `file_picker`: Directory/file selection UI
- `path`: Path manipulation utilities

## Contributing Guidelines

From CONTRIBUTING.md:
- Fork from `main` branch
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Update README.md for significant changes
- Update example app if API changes
- Keep functions focused and concise
- Document all public APIs
- Update CHANGELOG.md for notable changes
- Commit messages: present tense, imperative mood, max 72 chars first line
