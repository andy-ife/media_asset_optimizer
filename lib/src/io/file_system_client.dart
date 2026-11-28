import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:media_asset_optimizer/src/exception/file_exception.dart';
import 'package:path/path.dart' as p;

/// Simple wrapper around dart:io
/// Contains information about the current project and directories
class FileSystemClient {
  FileSystemClient({List<String>? ignoredDirs})
      : ignoredDirs = ignoredDirs ?? ['test', 'build'] {
    _findProjectRoot();
  }

  late final String projectRoot;
  late final String pubspecPath;

  final List<String> ignoredDirs; // folders to ignore during code search

  void _findProjectRoot() {
    var dir = Directory.current;
    while (true) {
      final pubspecFile = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        projectRoot = dir.path;
        pubspecPath = pubspecFile.path;
        return;
      }
      final parentDir = dir.parent;
      if (parentDir.path == dir.path) {
        throw ProjectRootNotFoundException();
      }
      dir = parentDir;
    }
  }

  // ===========
  // Process
  // ===========
  FsProcessResult runProcess(String executable, List<String> args) {
    final result = Process.runSync(executable, args);
    return FsProcessResult(result.exitCode);
  }

  void exitApp(int code) {
    exit(code);
  }

  void cleanupOnAppExit({required Function onExit}) {
    ProcessSignal.sigint.watch().listen((signal) {
      onExit();
    });

    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((signal) {
        onExit();
      });
    }
  }

  void cleanup() {}

  // ===========
  // Platform
  // ===========

  bool get isWindows => Platform.isWindows;
  bool get isMacOS => Platform.isMacOS;
  bool get isLinux => Platform.isLinux;

  // ============
  // File
  // ============

  String readPubspec() {
    return readAsString(pubspecPath);
  }

  bool fileExists(String path) {
    return File(path).existsSync();
  }

  bool isFile(String path) {
    return fileExists(path) &&
        FileSystemEntity.typeSync(path) == FileSystemEntityType.file;
  }

  void createFile(String path) {
    return File(path).createSync(recursive: true);
  }

  String readAsString(String path) {
    return File(path).readAsStringSync();
  }

  Uint8List readAsBytes(String path) {
    return File(path).readAsBytesSync();
  }

  void writeAsBytes(String path, Uint8List bytes) {
    return File(path).writeAsBytesSync(bytes);
  }

  int lengthSync(String path) {
    return File(path).lengthSync();
  }

  Future<int> length(String path) {
    return File(path).length();
  }

  Future<void> delete(String path) {
    return File(path).delete();
  }

  void deleteSync(String path) {
    return File(path).deleteSync(recursive: true);
  }

  // ============
  // Directory
  // ============

  bool directoryExists(String path) {
    return Directory(path).existsSync();
  }

  bool isDirectory(String path) {
    return directoryExists(path) &&
        FileSystemEntity.typeSync(path) == FileSystemEntityType.directory;
  }

  void createDir(String path) {
    return Directory(path).createSync(recursive: true);
  }

  String get currentDir => Directory.current.path;

  Set<String> getFilesRecursivelyRelative(String dirPath) {
    final files = <String>{};
    if (!directoryExists(dirPath)) return files;
    try {
      for (var entity in _listFilesSync(dirPath)) {
        if (isFile(entity)) {
          files
              .add(p.relative(entity, from: projectRoot).replaceAll('\\', '/'));
        }
      }
    } catch (e) {
      throw GeneralFileException(message: e.toString());
    }
    return files;
  }

  Set<String> _listFilesSync(String path) {
    return Directory(path).listSync(recursive: true).map((e) => e.path).toSet();
  }
}

final class FsProcessResult {
  FsProcessResult(this.exitCode);
  int exitCode;
}
