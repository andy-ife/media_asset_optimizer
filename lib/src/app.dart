import 'package:media_asset_optimizer/src/app/analysis_printer.dart';
import 'package:media_asset_optimizer/src/app/asset_compressor.dart';
import 'package:media_asset_optimizer/src/app/asset_usage_scanner.dart';
import 'package:media_asset_optimizer/src/exception/file_exception.dart';
import 'package:media_asset_optimizer/src/io/compression_client.dart';
import 'package:media_asset_optimizer/src/runner.dart';
import 'package:media_asset_optimizer/src/io/file_system_client.dart';
import 'package:media_asset_optimizer/src/app/cli.dart';
import 'package:media_asset_optimizer/src/io/console.dart';
import 'package:path/path.dart' as p;

const test_asset_reference2 = 'test_pic2.jpg';
const test_asset_reference3 = 'test_vid1.mp4';
const test_asset_reference4 = 'test_aud1.mp3';
const test_asset_reference5 = 'test_vid3.mkv';
const test_asset_ref6 = 'test_aud2.mp3';
const test_asset_ref7 = 'test_pic1.bmp';
const test_asset_ref8 = 'test_pic3.png';
const test_asset_ref9 = 'test_pic4.tif';
const test_asset_ref10 = 'test_pic5.gif';
const test_asset_ref11 = 'test_pic6.webp';
const test_asset_ref12 = 'test_pic7.avif';
const test_asset_ref13 = 'test_vid2.webm';

class App {
  App({FileSystemClient? fs, Console? console}) {
    this.fs = fs ??
        FileSystemClient(
          ignoredDirs: ['test', 'build'],
        );
    this.console = console ?? Console();
  }

  late final FileSystemClient fs;
  late final Console console;

  void start(List<String> args) async {
    fs.cleanupOnAppExit(onExit: () {
      cleanup();
    });

    // App
    try {
      if (fs.projectRoot != fs.currentDir) {
        console.printInfo('Changed project root to: ${fs.projectRoot}');
      }

      final scanner = AssetUsageScanner(fs: fs);

      final cli = Cli();
      final cliMode = cli.start(args);

      if (cliMode == CliMode.none) {
        fs.exitApp(0);
      }

      String? outputPath = cli.outputPath;
      if (outputPath != null) {
        if (!fs.isDirectory(outputPath)) {
          throw IsAFileException(outputPath);
        }
        final root = p.rootPrefix(outputPath);
        if (root.isEmpty) {
          // relative
          final relative = p.relative(outputPath);
          outputPath = p.join(fs.projectRoot, relative);
          fs.createDir(outputPath);
          cli.outputPath = outputPath;
        } else {
          throw NotRelativeToProjectRootException(outputPath);
        }
      }

      final Set<String> allAssets;
      if (cliMode == CliMode.compressFile) {
        // A single file does not need the whole project scanned.
        allAssets = {};
      } else {
        allAssets = await scanner.getAllAssets();
      }

      if (allAssets.isEmpty && cliMode != CliMode.compressFile) {
        console.printInfo('\nNo assets found in the project. Exiting.');
        fs.exitApp(0);
      }

      // Start
      final runner = Runner(
          cliMode: cliMode,
          singleFile: cli.singleFile,
          compressor: AssetCompressor(
              allAssets: allAssets,
              fs: fs,
              client: CompressionClient(
                quality: cli.quality,
                outputPath: cli.outputPath,
              )),
          printer: AnalysisPrinter(
            fs: fs,
          ));

      await runner.run();
    } catch (e) {
      console.printError(e.toString());
    } finally {
      cleanup();
      fs.exitApp(0);
    }
  }

  void cleanup() {
    console.resetConsole();
  }
}
