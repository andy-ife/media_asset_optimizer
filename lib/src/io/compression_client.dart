import 'package:media_asset_optimizer/src/io/bindings/av_transcoder.dart';
import 'package:media_asset_optimizer/src/io/bindings/ffmpeg_transcoder.dart';
import 'package:media_asset_optimizer/src/io/bindings/mf_transcoder.dart';
import 'package:media_asset_optimizer/src/io/file_system_client.dart';
import 'package:media_asset_optimizer/src/exception/transcoder_exception.dart';
import 'package:media_asset_optimizer/src/utils/asset_utils.dart';
import 'package:path/path.dart' as p;

import 'package:image_compression/image_compression.dart';

class CompressionClient {
  CompressionClient({FileSystemClient? fs, this.quality, this.outputPath}) {
    this.fs = fs ?? FileSystemClient();
    if (this.fs.isWindows) {
      mft = MfTranscoder(
          dllPath: p.join(
              this.fs.projectRoot, 'native_libs/windows/mf_transcoder.dll'));
    } else if (this.fs.isMacOS) {
      avt = AvTranscoder(
          dllPath: p.join(
              this.fs.projectRoot, 'native_libs/macOS/av_transcoder.dylib'));
    } else if (this.fs.isLinux) {
      fft = FfmpegTranscoder();
    } else {
      throw UnsupportedPlatformException(null);
    }
  }

  late final FileSystemClient fs;

  /// File quality from 1 (smallest file) to 100 (best quality).
  ///
  /// Each media type keeps its own default when this is null.
  final int? quality;
  final String? outputPath;

  AvTranscoder? avt;
  MfTranscoder? mft;
  FfmpegTranscoder? fft;

  int get _imageQuality => (quality ?? 50).clamp(1, 100).toInt();

  int get _videoQuality => (quality ?? 85).clamp(1, 100).toInt();

  double compressImage(String path) {
    final input = ImageFile(filePath: path, rawBytes: fs.readAsBytes(path));

    final output = compress(ImageFileConfiguration(
        input: input, config: Configuration(jpgQuality: _imageQuality)));

    if (output.sizeInBytes < input.sizeInBytes) {
      if (outputPath == null) {
        fs.writeAsBytes(path, output.rawBytes);
      } else {
        fs.writeAsBytes(p.join(outputPath!, p.basename(path)), output.rawBytes);
      }
      return (input.sizeInBytes - output.sizeInBytes).toDouble();
    } else {
      return 0;
    }
  }

  double compressVideoOrAudio(String path) {
    final tempPath = outputPath == null
        ? p.join(fs.projectRoot, '.dart_tool', '.temp', p.basename(path))
        : p.join(outputPath!, p.basename(path));

    try {
      if (!fs.fileExists(tempPath)) fs.createFile(tempPath);
      final inputLength = fs.lengthSync(path);

      final result = fs.isWindows
          ? mft!.transcode(
              inputPath: path,
              outputPath: tempPath,
              quality: _videoQuality,
            )
          : fs.isMacOS
              ? avt!.transcode(
                  inputPath: path,
                  outputPath: tempPath,
                  quality: _videoQuality,
                )
              : fs.isLinux
                  ? fft!.transcode(
                      fs: fs,
                      inputPath: path,
                      outputPath: tempPath,
                      quality: _videoQuality,
                    )
                  : throw UnsupportedPlatformException(null);

      if (result.status != 0) {
        throw getTranscoderException(result.status, result.hresult, fs);
      }
      if (!fs.fileExists(tempPath) || fs.lengthSync(tempPath) == 0) {
        throw UnexpectedException(result.hresult);
      }

      final outputLength = fs.lengthSync(tempPath);
      if (outputLength < inputLength) {
        final outputBytes = fs.readAsBytes(tempPath);

        // overwrite original if there is no outputPath
        if (outputPath == null) fs.writeAsBytes(path, outputBytes);

        return (inputLength - outputLength).toDouble();
      } else {
        // untouched
        return 0;
      }
    } on Exception catch (e) {
      throw getTranscoderException(e, null, fs);
    } finally {
      // delete tempFile if there is no outputPath
      if (fs.fileExists(tempPath) && outputPath == null) {
        fs.deleteSync(tempPath);
      }
    }
  }

  double? compressMedia(String path) {
    switch (AssetUtils.getAssetType(path)) {
      case AssetType.image:
        return compressImage(path);
      case AssetType.video:
        return compressVideoOrAudio(path);
      case AssetType.audio:
        return compressVideoOrAudio(path);
      case AssetType.unkown:
        return null;
    }
  }

  double? compressAllMedia(Iterable<String> paths) {
    double result = 0;
    for (var p in paths) {
      final size = compressMedia(p) ?? 0;
      result += size;
    }
    return result;
  }
}
