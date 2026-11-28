import 'package:media_asset_optimizer/src/io/compression_client.dart';
import 'package:media_asset_optimizer/src/io/file_system_client.dart';
import 'package:media_asset_optimizer/src/io/console.dart';
import 'package:media_asset_optimizer/src/utils/extension.dart';
import 'package:media_asset_optimizer/src/utils/asset_utils.dart';
import 'package:path/path.dart' as p;

class CompressResult {
  CompressResult(
      {required this.allMediaAssets,
      required this.assetsForCompression,
      required this.assetsForCompressionTree,
      required this.spaceOfMediaAssetsBeforeCompress,
      required this.potentiallySavedSpace,
      required this.spaceOfMediaAssetsAfterCompress,
      required this.hasAnalyzed,
      required this.hasCompressed});

  Set<String> allMediaAssets;
  List<String> assetsForCompression; // by default, these are used assets
  Map<String, dynamic> assetsForCompressionTree;
  double spaceOfMediaAssetsBeforeCompress;
  double potentiallySavedSpace;
  double? spaceOfMediaAssetsAfterCompress;
  bool hasAnalyzed;
  bool hasCompressed;
}

class AssetCompressor {
  AssetCompressor({
    required this.allAssets,
    required this.fs,
    required this.client,
    Console? console,
  }) : console = console ?? Console();

  final Set<String> allAssets;
  final FileSystemClient fs;
  final CompressionClient client;
  final Console console;

  CompressResult? _result;
  CompressResult? get result => _result;

  CompressResult analyze() {
    final List<String> assetsForCompression = [];
    double spaceofMediaAssetsBeforeCompress = 0;

    final allMediaAssets = allAssets.where((e) => AssetUtils.isMedia(e));
    // final usedMediaAssets = usedAssets.where((e) => AssetUtils.isMedia(e));

    for (final assetPath in allMediaAssets) {
      final path = p.join(fs.projectRoot, assetPath);
      bool isNonEmpty = false;
      try {
        if (fs.fileExists(path)) {
          final size = fs.lengthSync(path);
          isNonEmpty = size > 0;
          spaceofMediaAssetsBeforeCompress += size;
        }
      } catch (e) {
        console.printWarning('Could not check size of "$assetPath": $e');
      }

      if (isNonEmpty) {
        assetsForCompression.add(assetPath);
      }
    }

    final compressTree = console.buildTree(assetsForCompression.toList());

    _result = CompressResult(
        allMediaAssets: allMediaAssets.toSet(),
        assetsForCompression: assetsForCompression,
        assetsForCompressionTree: compressTree,
        spaceOfMediaAssetsBeforeCompress: spaceofMediaAssetsBeforeCompress,
        spaceOfMediaAssetsAfterCompress: null,
        potentiallySavedSpace: spaceofMediaAssetsBeforeCompress * 0.6,
        hasAnalyzed: true,
        hasCompressed: false);
    return _result!;
  }

  /// Compress one asset instead of the whole project.
  ///
  /// [assetPath] may be absolute or relative to the project root.
  Future<CompressResult?> compressFile(String assetPath) async {
    final relativePath = _normalizeAssetPath(assetPath);
    final absolutePath = p.join(fs.projectRoot, relativePath);

    if (!fs.fileExists(absolutePath)) {
      console.printError('File not found: "$assetPath"');
      return null;
    }

    if (!AssetUtils.isMedia(relativePath)) {
      console.printError('Unsupported media file: "$assetPath"');
      return null;
    }

    final size = fs.lengthSync(absolutePath);
    if (size <= 0) {
      console.printWarning('File is empty, skipping compression: "$assetPath"');
      return null;
    }

    final result = CompressResult(
      allMediaAssets: {relativePath},
      assetsForCompression: [relativePath],
      assetsForCompressionTree: console.buildTree([relativePath]),
      spaceOfMediaAssetsBeforeCompress: size.toDouble(),
      potentiallySavedSpace: size * 0.6,
      spaceOfMediaAssetsAfterCompress: null,
      hasAnalyzed: true,
      hasCompressed: false,
    );
    _result = result;

    console.printInfo('\nCompressing single asset: $relativePath');
    final freedSpace = _compress([relativePath]);

    _result = result
      ..spaceOfMediaAssetsAfterCompress =
          (size - freedSpace).clamp(0, double.infinity).toDouble()
      ..hasCompressed = freedSpace > 0;

    if (freedSpace > 0) {
      console.printSuccess(
          '\n✨ You have freed up ${freedSpace.toStorageString()} of space.');
    } else {
      console.printError('Unable to compress this asset');
    }

    return _result;
  }

  String _normalizeAssetPath(String assetPath) {
    final absolutePath =
        p.isAbsolute(assetPath) ? assetPath : p.join(fs.projectRoot, assetPath);
    return p.relative(absolutePath, from: fs.projectRoot).replaceAll('\\', '/');
  }

  Future<CompressResult?> compressMultiple(
      {bool selectAssetsToIgnore = false}) async {
    if (_result == null || _result?.hasAnalyzed == false) {
      console.printError('Run analysis before compression');
      return null;
    }

    var curResult = _result!;

    if (selectAssetsToIgnore) {
      List<String> totalAssets = [];
      console
          .printInfo('\nSelect assets to skip (Remove from compression list)');
      final indexes = console.printMultiSelect(
          message: 'space: Select  |  enter: Confirm selection',
          options: curResult.allMediaAssets.toList());
      final toRemove = curResult.allMediaAssets.indexed
          .where((e) => indexes.contains(e.$1))
          .map((e) => e.$2);
      totalAssets =
          curResult.allMediaAssets.where((e) => !toRemove.contains(e)).toList();
      curResult.assetsForCompression = totalAssets;

      if (curResult.assetsForCompression.isNotEmpty) {
        console.printWarning(
            '\nMarking ${curResult.assetsForCompression.length}/${curResult.allMediaAssets.length} assets for compression...');
      } else {
        console.printSuccess('\n✨ Nothing to compress. Keeping all assets');
        return curResult;
      }
    }

    if (curResult.assetsForCompression.isEmpty) {
      console.printSuccess('No assets to compress. Keeping all assets...');
      return curResult;
    }

    String? finalConfirm;
    double freedSpace = 0;
    console.printInfo(
        '\nFINAL CONFIRMATION: You are about to compress ${curResult.assetsForCompression.length} asset(s).');
    do {
      console.printInputPrompt(
          'Proceed with compression? It may take a while (Y/N): ');
      finalConfirm = console.read();
      if (finalConfirm.isYes) {
        freedSpace += await console.printLoading<double>(
            message:
                'Compressing ${curResult.assetsForCompression.length} asset(s)',
            work: () {
              final freed = _compress(curResult.assetsForCompression);
              if (freed > 0) {
                console.printSuccess(
                    '\n✨ You have freed up ${freed.toStorageString()} of space.');
              } else {
                console.printError('Unable to compress some assets');
              }
              return freed.clamp(0, double.infinity); // no negative nums
            });
      } else if (finalConfirm.isNo) {
        console.printError('Compression cancelled by user.');
        _result = curResult
          ..hasCompressed = false
          ..spaceOfMediaAssetsAfterCompress = null;
        return _result;
      } else {
        console.printError('Invalid option. Please enter "y" or "n"');
      }
    } while (!finalConfirm.isYesOrNo);

    _result = curResult
      ..spaceOfMediaAssetsAfterCompress =
          curResult.spaceOfMediaAssetsBeforeCompress - freedSpace
      ..hasCompressed = true;

    return _result;
  }

  double _compress(List<String> assets) {
    double result = 0;
    for (var assetRelativePath in assets) {
      final path = p.join(fs.projectRoot, assetRelativePath);
      if (!fs.fileExists(path)) {
        console.printWarning(
            'File not found, skipping compression: "$assetRelativePath"');
        continue;
      }
      try {
        final res = client.compressMedia(path);
        if (res != null && res > 0) {
          result += res;
          console.printSuccess(
              '\nCompressed: $assetRelativePath: -${res.toStorageString()}');
        } else {
          console.printWarning(
              '\nCould not compress further: $assetRelativePath. Consider lowering the quality setting');
        }
      } catch (e) {
        console.printError('Error compressing $path: $e');
      }
    }
    return result;
  }
}
