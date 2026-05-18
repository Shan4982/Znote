import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class FileStorage {
  static const _uuid = Uuid();

  late final String _basePath;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _basePath = p.join(dir.path, 'note_data');
    await Directory(_basePath).create(recursive: true);
  }

  String get basePath => _basePath;

  String notebookPath(String notebookId) => p.join(_basePath, notebookId);
  String pagesPath(String notebookId) => p.join(notebookPath(notebookId), 'pages');
  String importsPath(String notebookId) => p.join(notebookPath(notebookId), 'imports');

  Future<void> ensureNotebookDirs(String notebookId) async {
    await Directory(pagesPath(notebookId)).create(recursive: true);
    await Directory(importsPath(notebookId)).create(recursive: true);
  }

  Future<void> deleteNotebookDirs(String notebookId) async {
    final dir = Directory(notebookPath(notebookId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  String strokeFilePath(String notebookId, String pageId) =>
      p.join(pagesPath(notebookId), '$pageId.strokes');

  String thumbFilePath(String notebookId, String pageId) =>
      p.join(pagesPath(notebookId), '$pageId.thumb.png');

  String importFilePath(String notebookId, String docId) =>
      p.join(importsPath(notebookId), '$docId.pdf');

  String annotationFilePath(String notebookId, String docId) =>
      p.join(importsPath(notebookId), '$docId.annotations');

  Future<List<int>> readStrokes(String notebookId, String pageId) async {
    final file = File(strokeFilePath(notebookId, pageId));
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return [];
  }

  Future<void> writeStrokes(String notebookId, String pageId, List<int> bytes) async {
    final file = File(strokeFilePath(notebookId, pageId));
    await file.writeAsBytes(bytes);
  }

  Future<void> saveImportFile(String notebookId, String docId, List<int> bytes) async {
    final file = File(importFilePath(notebookId, docId));
    await file.writeAsBytes(bytes);
  }

  Future<List<int>> readAnnotations(String notebookId, String docId) async {
    final file = File(annotationFilePath(notebookId, docId));
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return [];
  }

  Future<void> writeAnnotations(String notebookId, String docId, List<int> bytes) async {
    final file = File(annotationFilePath(notebookId, docId));
    await file.writeAsBytes(bytes);
  }

  static String generateId() => _uuid.v4();
}
