import 'package:media_asset_optimizer/src/io/file_system_client.dart';
import 'package:media_asset_optimizer/src/exception/file_exception.dart';
import 'package:media_asset_optimizer/src/io/console.dart';
import 'package:media_asset_optimizer/src/utils/asset_utils.dart';
import 'package:path/path.dart' as p;

// ignore_for_file: constant_identifier_names

const ASSETS_DIR = 'assets';
const ANDROID_ASSETS_DIR = 'android/app/src/main/res';
const IOS_ASSETS_DIR = 'ios/Runner/Assets/Assets.xcassets';

// const MACOS_ASSETS_DIR = 'macos/Runner/Assets.xcassets';
// const WINDOWS_ASSETS_DIR = 'windows/runner/resources';
// const LINUX_ASSETS_DIR = 'linux/runner/resources';

final pubspecNameRegex = RegExp(r'^\s*name:\s*([a-z0-9_]+)', multiLine: true);
final pubspecEnvironmentRegex =
    RegExp(r'^\s*environment:\s*\n(?:[ \t]+.+\n?)*', multiLine: true);

class AssetUsageScanner {
  AssetUsageScanner({
    required this.fs,
    Console? console,
  }) : console = console ?? Console();

  final FileSystemClient fs;
  final Console console;

  Future<Set<String>> getAllAssets() {
    return console.printLoading<Set<String>>(
        message: 'Finding project assets...',
        work: () {
          return {
            ...getFlutterAssets(),
            ...getAndroidAssets(),
            ...getIosAssets(),
            ...getPubspecAssets()
          };
        });
  }

  Set<String> getFlutterAssets() {
    return findAllFilesInDirectory(p.join(fs.projectRoot, ASSETS_DIR));
  }

  Set<String> getAndroidAssets() {
    return findAllFilesInDirectory(p.join(fs.projectRoot, ANDROID_ASSETS_DIR));
  }

  Set<String> getIosAssets() {
    return findAllFilesInDirectory(p.join(fs.projectRoot, IOS_ASSETS_DIR));
  }

  Set<String> getPubspecAssets() {
    return extractPubspecAssets();
  }

  // ===============
  // Helpers
  // ==============

  /// Takes full raw text from pubspec.yaml and returns the list of assets from the
  /// assets section if present
  Set<String> extractPubspecAssets() {
    final pubspecContent = fs.readPubspec();
    if (!(pubspecNameRegex.hasMatch(pubspecContent) &&
        pubspecEnvironmentRegex.hasMatch(pubspecContent))) {
      throw InvalidPubspecFileException();
    }

    final assetRegex = RegExp(r'assets:\s*((?:\s+-\s+.+\n)+)', multiLine: true);
    final match = assetRegex.firstMatch(pubspecContent);
    if (match == null) return {};
    final assetLines = match
        .group(1)!
        .split('\n')
        .where((line) => line.trim().startsWith('-'))
        .map(
          (line) => line
              .trim()
              .substring(1)
              .trim()
              .replaceAll("'", '')
              .replaceAll('"', ''),
        )
        .toList();
    final assets = <String>{};
    for (var declaration in assetLines) {
      String path = declaration;
      if (declaration.contains(fs.projectRoot)) {
        path = p.relative(declaration, from: fs.projectRoot);
      }
      if (fs.isDirectory(path)) {
        assets.addAll(fs.getFilesRecursivelyRelative(path));
      } else {
        assets.add(path);
      }
    }
    return assets;
  }

  /// Find all files in a directory
  Set<String> findAllFilesInDirectory(String dir) {
    final files = <String>{};
    if (!fs.directoryExists(dir)) {
      return files;
    }
    for (var entity in fs.getFilesRecursivelyRelative(dir)) {
      if (_shouldIgnore(dir)) continue;
      try {
        if (fs.isFile(entity)) {
          if (!p.basename(entity).startsWith('.')) {
            files.add(p.relative(entity, from: fs.projectRoot));
          }
        }
      } catch (e) {
        console.printError('Error listing files in /$dir: $e');
      }
    }
    if (files.isEmpty) {
      console.printWarning(
          '\nNo files found in the assets directory /$dir (Excluding hidden files and ignored dirs)');
    } else {
      console.printInfo(
        '\nFound ${files.length} files in /$dir',
      );
      final nonMedia = files.where((e) => !AssetUtils.isMedia(e));
      if (nonMedia.isNotEmpty) {
        console.printInfo('${nonMedia.length} are non-media files');
      }
    }
    return files;
  }

  bool _shouldIgnore(String path) {
    final filePath = path;
    final rootPath = fs.projectRoot;
    return fs.ignoredDirs.any((dir) {
      final ignoredPath = p.join(rootPath, dir);
      return filePath.contains(ignoredPath);
    });
  }
}
