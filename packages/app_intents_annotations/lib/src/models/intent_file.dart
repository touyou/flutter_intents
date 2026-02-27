/// Represents a file received from an App Intent parameter.
///
/// Maps to iOS `IntentFile` which wraps file data, MIME type, and filename.
/// Used with `@IntentParam(fileType: 'public.image')` to accept file inputs.
class IntentFile {
  /// The file path (typically a temporary file path).
  final String path;

  /// The MIME type of the file (e.g., 'image/jpeg').
  final String? mimeType;

  /// The original filename.
  final String? filename;

  const IntentFile({required this.path, this.mimeType, this.filename});

  factory IntentFile.fromMap(Map<String, dynamic> map) => IntentFile(
        path: map['path'] as String,
        mimeType: map['mimeType'] as String?,
        filename: map['filename'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'path': path,
        if (mimeType != null) 'mimeType': mimeType,
        if (filename != null) 'filename': filename,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! IntentFile) return false;
    return path == other.path &&
        mimeType == other.mimeType &&
        filename == other.filename;
  }

  @override
  int get hashCode => Object.hash(path, mimeType, filename);

  @override
  String toString() =>
      'IntentFile(path: $path, mimeType: $mimeType, filename: $filename)';
}
