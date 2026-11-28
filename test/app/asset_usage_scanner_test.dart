import 'package:media_asset_optimizer/src/app/asset_usage_scanner.dart';
import 'package:media_asset_optimizer/src/exception/file_exception.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../mocks/mock_io.dart';
import '../mocks/sample_data.dart';

void main() {
  group('Asset Usage Scanner', () {
    final mockConsole = MockConsole();

    test('reads valid pubspec assets', () {
      final fs = MockFileSystemClient();
      when(() => fs.readPubspec()).thenAnswer((_) => validPubspec);
      when(() => fs.isDirectory(any())).thenAnswer((_) => false);

      final scanner = AssetUsageScanner(fs: fs, console: mockConsole);
      final assets = scanner.getPubspecAssets();

      expect(
          assets,
          samplePubspecAssets
              .map((e) => p.relative(e, from: fs.projectRoot))
              .toSet());
    });

    test('throws on invalid pubspec file', () {
      final fs = MockFileSystemClient();
      when(() => fs.readPubspec()).thenAnswer((_) => invalidPubspec);
      when(() => fs.isDirectory(any())).thenAnswer((_) => false);

      final scanner = AssetUsageScanner(fs: fs, console: mockConsole);
      expect(() => scanner.getPubspecAssets(),
          throwsA(isA<InvalidPubspecFileException>()));
    });

    test('finds Flutter, Android, iOS, and pubspec assets', () async {
      final fs = MockFileSystemClient();
      when(() => fs.isDirectory(any())).thenAnswer((_) => false);
      when(() => fs.directoryExists(any())).thenAnswer((_) => true);
      when(() => fs.isFile(any())).thenAnswer((_) => true);

      stubPrintLoading<Set<String>>(mockConsole);

      final flutterAssets = sampleFlutterAssets;
      when(() => fs.getFilesRecursivelyRelative(
              p.join(SAMPLE_PROJECT_ROOT, ASSETS_DIR)))
          .thenAnswer((_) => flutterAssets);

      final androidAssets = sampleAndroidAssets;
      when(() => fs.getFilesRecursivelyRelative(
              p.join(SAMPLE_PROJECT_ROOT, ANDROID_ASSETS_DIR)))
          .thenAnswer((_) => androidAssets);

      final iosAssets = sampleIosAssets;
      when(() => fs.getFilesRecursivelyRelative(
              p.join(SAMPLE_PROJECT_ROOT, IOS_ASSETS_DIR)))
          .thenAnswer((_) => iosAssets);

      when(() => fs.readPubspec()).thenAnswer((_) => validPubspec);

      final scanner = AssetUsageScanner(fs: fs, console: mockConsole);

      final allAssets = await scanner.getAllAssets();

      expect(
          allAssets,
          <String>{
            ...flutterAssets,
            ...androidAssets,
            ...iosAssets,
            ...samplePubspecAssets
          }.map((e) => p.relative(e, from: SAMPLE_PROJECT_ROOT)));
    });

    test('returns empty set when a common assets dir does not exist', () async {
      final fs = MockFileSystemClient();
      when(() => fs.isDirectory(any())).thenAnswer((_) => false);
      when(() => fs.directoryExists(p.join(SAMPLE_PROJECT_ROOT, ASSETS_DIR)))
          .thenAnswer((_) => false);

      final scanner = AssetUsageScanner(fs: fs, console: mockConsole);

      final assets = scanner.getFlutterAssets();

      expect(assets, isEmpty);
    });

    test('skips ignored dirs', () async {
      final fs = MockFileSystemClient();
      when(() => fs.isDirectory(any())).thenAnswer((_) => false);
      when(() => fs.directoryExists(any())).thenAnswer((_) => true);
      when(() => fs.isFile(any())).thenAnswer((_) => true);

      stubPrintLoading<Set<String>>(mockConsole);

      // add ignoredDirs to all
      final flutterAssets = {...sampleFlutterAssets, ...SAMPLE_IGNORED_DIRS};
      when(() => fs.getFilesRecursivelyRelative(
              p.join(SAMPLE_PROJECT_ROOT, ASSETS_DIR)))
          .thenAnswer((_) => flutterAssets);

      final androidAssets = {...sampleAndroidAssets, ...SAMPLE_IGNORED_DIRS};
      when(() => fs.getFilesRecursivelyRelative(
              p.join(SAMPLE_PROJECT_ROOT, ANDROID_ASSETS_DIR)))
          .thenAnswer((_) => androidAssets);

      final iosAssets = {...sampleIosAssets, ...SAMPLE_IGNORED_DIRS};
      when(() => fs.getFilesRecursivelyRelative(
              p.join(SAMPLE_PROJECT_ROOT, IOS_ASSETS_DIR)))
          .thenAnswer((_) => iosAssets);

      when(() => fs.readPubspec()).thenAnswer((_) => validPubspec);

      final scanner = AssetUsageScanner(fs: fs, console: mockConsole);

      final allAssets = await scanner.getAllAssets();

      expect(allAssets, isNot(contains(allOf(SAMPLE_IGNORED_DIRS))));
    });

    test('skips empty asset directories and subdirectories', () async {});

    test('returned assets are files, not directories', () async {});
  });
}
