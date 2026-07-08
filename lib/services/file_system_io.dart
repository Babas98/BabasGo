import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<bool> fileExists(String path) async {
  return File(path).existsSync();
}

Future<void> writeFile(String path, List<int> bytes) async {
  final file = File(path);
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<void> deleteFile(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<String> getApplicationDocumentsDirectoryPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}
