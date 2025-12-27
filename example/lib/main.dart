import 'package:directory_bookmarks/directory_bookmarks.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Directory Bookmarks Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DirectoryBookmarksDemo(),
    );
  }
}

class DirectoryBookmarksDemo extends StatefulWidget {
  const DirectoryBookmarksDemo({super.key});

  @override
  State<DirectoryBookmarksDemo> createState() => _DirectoryBookmarksDemoState();
}

class _DirectoryBookmarksDemoState extends State<DirectoryBookmarksDemo> {
  List<BookmarkData> _bookmarks = [];
  BookmarkData? _selectedBookmark;
  List<String> _files = [];
  bool _hasWritePermission = false;
  String? _errorMessage;
  bool _isLoading = false;

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();
  final TextEditingController _fileContentController = TextEditingController();

  bool get _isSupported =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  void initState() {
    super.initState();
    _checkPlatformAndLoadBookmarks();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _fileNameController.dispose();
    _fileContentController.dispose();
    super.dispose();
  }

  Future<void> _checkPlatformAndLoadBookmarks() async {
    if (!_isSupported) {
      setState(() {
        _errorMessage =
            'Platform ${defaultTargetPlatform.name} is not supported yet. '
            'Currently supported platforms: macOS (full support), Linux (full support). '
            'Android, iOS, and Windows support is planned for future releases.';
      });
      return;
    }

    await _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bookmarks = await DirectoryBookmarkHandler.listBookmarks();
      setState(() {
        _bookmarks = bookmarks;
        // If selected bookmark was deleted, clear selection
        if (_selectedBookmark != null &&
            !bookmarks.any((b) => b.identifier == _selectedBookmark!.identifier)) {
          _selectedBookmark = null;
          _files = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading bookmarks: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectBookmark(BookmarkData bookmark) async {
    setState(() {
      _selectedBookmark = bookmark;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check write permission
      final hasPermission = await DirectoryBookmarkHandler.hasWritePermission(
        bookmark.identifier,
      );

      // Load files
      final files = await DirectoryBookmarkHandler.listFiles(bookmark.identifier);

      setState(() {
        _hasWritePermission = hasPermission;
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading bookmark data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateBookmarkDialog() async {
    if (!_isSupported) {
      _showError('Platform not supported');
      return;
    }

    _identifierController.clear();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Bookmark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _identifierController,
              decoration: const InputDecoration(
                labelText: 'Identifier',
                hintText: 'my-project',
                helperText: 'Unique identifier for this bookmark',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You will be asked to select a directory after clicking Create.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _createBookmark(_identifierController.text);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBookmark(String identifier) async {
    if (identifier.isEmpty) {
      _showError('Identifier cannot be empty');
      return;
    }

    // Check if identifier already exists
    if (_bookmarks.any((b) => b.identifier == identifier)) {
      _showError('Bookmark with identifier "$identifier" already exists');
      return;
    }

    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select directory for bookmark "$identifier"',
      );

      if (path == null) {
        // User canceled the picker
        return;
      }

      final result = await DirectoryBookmarkHandler.createBookmark(
        identifier,
        path,
        metadata: {
          'created': DateTime.now().toIso8601String(),
          'app': 'directory_bookmarks_example',
        },
      );

      if (!mounted) return;

      if (result != null) {
        _showSuccess('Bookmark "$identifier" created successfully');
        await _loadBookmarks();

        // Auto-select the newly created bookmark
        final newBookmark = _bookmarks.firstWhere((b) => b.identifier == identifier);
        await _selectBookmark(newBookmark);
      } else {
        _showError('Failed to create bookmark');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error creating bookmark: $e');
    }
  }

  Future<void> _deleteBookmark(BookmarkData bookmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bookmark'),
        content: Text(
          'Are you sure you want to delete bookmark "${bookmark.identifier}"?\n\n'
          'Path: ${bookmark.path}\n\n'
          'This will not delete the directory or its files, only the bookmark reference.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await DirectoryBookmarkHandler.deleteBookmark(
        bookmark.identifier,
      );

      if (!mounted) return;

      if (success) {
        _showSuccess('Bookmark "${bookmark.identifier}" deleted');
        if (_selectedBookmark?.identifier == bookmark.identifier) {
          setState(() {
            _selectedBookmark = null;
            _files = [];
          });
        }
        await _loadBookmarks();
      } else {
        _showError('Failed to delete bookmark');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error deleting bookmark: $e');
    }
  }

  Future<void> _showCreateFileDialog() async {
    if (_selectedBookmark == null) {
      _showError('Please select a bookmark first');
      return;
    }

    _fileNameController.clear();
    _fileContentController.clear();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _fileNameController,
              decoration: const InputDecoration(
                labelText: 'File Name',
                hintText: 'example.txt',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fileContentController,
              decoration: const InputDecoration(
                labelText: 'File Content',
                hintText: 'Enter text content...',
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _createFile(
                _fileNameController.text,
                _fileContentController.text,
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFile(String fileName, String content) async {
    if (_selectedBookmark == null) {
      _showError('No bookmark selected');
      return;
    }

    if (fileName.isEmpty) {
      _showError('File name cannot be empty');
      return;
    }

    if (!_hasWritePermission) {
      final granted = await DirectoryBookmarkHandler.requestWritePermission(
        _selectedBookmark!.identifier,
      );
      if (!granted) {
        _showError('Write permission denied');
        return;
      }
      setState(() {
        _hasWritePermission = true;
      });
    }

    try {
      final success = await DirectoryBookmarkHandler.saveStringToFile(
        _selectedBookmark!.identifier,
        fileName,
        content,
      );

      if (!mounted) return;

      if (success) {
        _showSuccess('File "$fileName" created successfully');
        await _refreshFiles();
      } else {
        _showError('Failed to create file');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error creating file: $e');
    }
  }

  Future<void> _viewFile(String fileName) async {
    if (_selectedBookmark == null) return;

    try {
      final content = await DirectoryBookmarkHandler.readStringFromFile(
        _selectedBookmark!.identifier,
        fileName,
      );

      if (!mounted) return;

      if (content != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(fileName),
            content: SingleChildScrollView(
              child: SelectableText(content),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        _showError('File not found');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error reading file: $e');
    }
  }

  Future<void> _deleteFile(String fileName) async {
    if (_selectedBookmark == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await DirectoryBookmarkHandler.deleteFile(
        _selectedBookmark!.identifier,
        fileName,
      );

      if (!mounted) return;

      if (success) {
        _showSuccess('File "$fileName" deleted');
        await _refreshFiles();
      } else {
        _showError('Failed to delete file');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error deleting file: $e');
    }
  }

  Future<void> _refreshFiles() async {
    if (_selectedBookmark == null) return;

    try {
      final files = await DirectoryBookmarkHandler.listFiles(
        _selectedBookmark!.identifier,
      );
      setState(() {
        _files = files;
      });
    } catch (e) {
      _showError('Error refreshing files: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildBookmarksList() {
    if (_bookmarks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No bookmarks yet.\nClick + to create your first bookmark.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        final isSelected = _selectedBookmark?.identifier == bookmark.identifier;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isSelected ? Colors.blue.shade50 : null,
          child: ListTile(
            leading: Icon(
              Icons.folder,
              color: isSelected ? Colors.blue : null,
            ),
            title: Text(
              bookmark.identifier,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              bookmark.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteBookmark(bookmark),
            ),
            onTap: () => _selectBookmark(bookmark),
          ),
        );
      },
    );
  }

  Widget _buildFilesView() {
    if (_selectedBookmark == null) {
      return const Center(
        child: Text('Select a bookmark to view files'),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bookmark: ${_selectedBookmark!.identifier}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Path: ${_selectedBookmark!.path}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Created: ${_selectedBookmark!.createdAt}',
                style: const TextStyle(fontSize: 12),
              ),
              if (!_hasWritePermission) ...[
                const SizedBox(height: 8),
                const Text(
                  'Write permission required to create files',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _files.isEmpty
              ? const Center(
                  child: Text('No files in this directory'),
                )
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final fileName = _files[index];
                    return ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(fileName),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteFile(fileName),
                      ),
                      onTap: () => _viewFile(fileName),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Directory Bookmarks Demo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Directory Bookmarks Demo'),
        actions: [
          if (_selectedBookmark != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshFiles,
              tooltip: 'Refresh files',
            ),
        ],
      ),
      body: _isLoading && _bookmarks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // Use column layout on narrow screens, row on wide screens
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  const Text(
                                    'Bookmarks',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: _showCreateBookmarkDialog,
                                    tooltip: 'Create bookmark',
                                  ),
                                ],
                              ),
                            ),
                            Expanded(child: _buildBookmarksList()),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        flex: 3,
                        child: _buildFilesView(),
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      SizedBox(
                        width: 300,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  const Text(
                                    'Bookmarks',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: _showCreateBookmarkDialog,
                                    tooltip: 'Create bookmark',
                                  ),
                                ],
                              ),
                            ),
                            Expanded(child: _buildBookmarksList()),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildFilesView()),
                    ],
                  );
                }
              },
            ),
      floatingActionButton: _selectedBookmark != null && _hasWritePermission
          ? FloatingActionButton(
              onPressed: _showCreateFileDialog,
              tooltip: 'Create file',
              child: const Icon(Icons.note_add),
            )
          : null,
    );
  }
}
