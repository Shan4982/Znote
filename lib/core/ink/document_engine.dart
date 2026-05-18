import 'dart:io';
import 'package:flutter/material.dart';
import '../storage/file_storage.dart';

/// Handles PDF rendering and DOCX-to-PDF conversion.
/// For DOCX: converts to PDF first, then renders with a unified pipeline.
class DocumentEngine {
  static const supportedInputFormats = ['pdf', 'docx', 'doc'];

  /// Import a document file into the notebook.
  /// Copies the file to app storage. For DOCX, triggers conversion.
  Future<String> importDocument({
    required String sourcePath,
    required String notebookId,
    required FileStorage fileStorage,
  }) async {
    final ext = sourcePath.split('.').last.toLowerCase();
    final docId = FileStorage.generateId();

    if (ext == 'pdf') {
      final bytes = await File(sourcePath).readAsBytes();
      await fileStorage.saveImportFile(notebookId, docId, bytes);
    } else if (ext == 'docx' || ext == 'doc') {
      // DOCX → PDF conversion stub.
      // In production, use a conversion library (e.g. libreoffice headless,
      // or a Dart-side docx parser that renders to PDF).
      // For MVP, store the original and flag for conversion.
      final bytes = await File(sourcePath).readAsBytes();
      await fileStorage.saveImportFile(notebookId, docId, bytes);
      // TODO: actual DOCX→PDF conversion
    } else {
      throw UnsupportedError('Unsupported format: $ext');
    }

    return docId;
  }

  /// Get the PDF file path for rendering with pdfrx.
  String getPdfPath(String notebookId, String docId, FileStorage storage) {
    return storage.importFilePath(notebookId, docId);
  }

  /// Check whether a given file extension is importable.
  static bool canImport(String extension) =>
      supportedInputFormats.contains(extension.toLowerCase());
}
