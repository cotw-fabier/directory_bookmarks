class BookmarkData {
  final String identifier;
  final String path;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  BookmarkData({
    required this.identifier,
    required this.path,
    DateTime? createdAt,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'path': path,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata ?? {},
    };
  }

  factory BookmarkData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError('Cannot create BookmarkData from null JSON');
    }

    return BookmarkData(
      identifier: json['identifier'] as String? ?? '',
      path: json['path'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      metadata: (json['metadata'] as Map<Object?, Object?>?)?.cast<String, dynamic>(),
    );
  }

  @override
  String toString() => 'BookmarkData(identifier: $identifier, path: $path, createdAt: $createdAt, metadata: $metadata)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkData &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier;

  @override
  int get hashCode => identifier.hashCode;
}
