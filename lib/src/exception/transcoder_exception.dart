import 'package:media_asset_optimizer/src/io/file_system_client.dart';
import 'package:media_asset_optimizer/src/exception/file_exception.dart';

sealed class TranscoderException implements Exception {
  final int? osCode;
  const TranscoderException(this.osCode);

  @override
  String toString() => 'An error occured while transcoding: $osCode';
}

class InvalidArgumentException extends TranscoderException {
  const InvalidArgumentException(super.osCode);
  @override
  String toString() => 'Invalid arguments passed to the transcoder: $osCode';
}

class Utf8ConversionException extends TranscoderException {
  const Utf8ConversionException(super.osCode);
  @override
  String toString() => 'An error occurred during utf-8 conversion: $osCode';
}

class CommunicationInitException extends TranscoderException {
  const CommunicationInitException(super.osCode);
  @override
  String toString() => 'Error initializing communication: $osCode';
}

class MfStartupException extends TranscoderException {
  const MfStartupException(super.osCode);
  @override
  String toString() =>
      'An error occurred while trying to initialize the Windows MediaFoundation APIs: $osCode';
}

class SourceReaderException extends TranscoderException {
  const SourceReaderException(super.osCode);
  @override
  String toString() => 'An error occurred while parsing the input: $osCode';
}

class SinkWriterException extends TranscoderException {
  const SinkWriterException(super.osCode);
  @override
  String toString() => 'An error occurred while processing the output: $osCode';
}

class MediaTypeException extends TranscoderException {
  const MediaTypeException(super.osCode);
  @override
  String toString() => 'Invalid media type: $osCode';
}

class StreamSetupException extends TranscoderException {
  const StreamSetupException(super.osCode);
  @override
  String toString() => 'An error occured while setting up the stream: $osCode';
}

class PipelineException extends TranscoderException {
  const PipelineException(super.osCode);
  @override
  String toString() =>
      'An error occured while transcoding a video/audio stream: $osCode';
}

class UnsupportedContainerException extends TranscoderException {
  const UnsupportedContainerException(super.osCode);
  @override
  String toString() =>
      'Unsupported output container. Use .mp4, .m4v, .mov, .3gp or .3g2 for video, or .mp3/.m4a for audio: $osCode';
}

class UnsupportedAudioOnlyException extends TranscoderException {
  const UnsupportedAudioOnlyException(super.osCode);
  @override
  String toString() =>
      'Standalone audio compression is not supported on macOS: $osCode';
}

class AssetLoadingException extends TranscoderException {
  const AssetLoadingException(super.osCode);
  @override
  String toString() => 'An error occurred while loading an asset: $osCode';
}

class ReaderInitializationException extends TranscoderException {
  const ReaderInitializationException(super.osCode);
  @override
  String toString() => 'An error occurred while parsing the input: $osCode';
}

class WriterInitializationException extends TranscoderException {
  const WriterInitializationException(super.osCode);
  @override
  String toString() => 'An error occurred while processing the output: $osCode';
}

class UnexpectedException extends TranscoderException {
  const UnexpectedException(super.osCode);
  @override
  String toString() => 'An unexpected error occurred while transcoding';
}

class UnsupportedPlatformException extends TranscoderException {
  const UnsupportedPlatformException(super.osCode);
  @override
  String toString() => 'Unsupported platform';
}

class FfmpegNotFoundException extends TranscoderException {
  const FfmpegNotFoundException(super.osCode);
  @override
  String toString() =>
      'Ffmpeg not found. Please download ffmpeg and add it to your PATH or specify `ffmpegPath` as an argument\nhttps://ffmpeg.org/download.html';
}

class FfmpegTranscodingFailedException extends TranscoderException {
  const FfmpegTranscodingFailedException(super.osCode);
  @override
  String toString() =>
      'Ffmpeg transcoding failed. The file format or codec may be unsupported: $osCode';
}

class InsufficientFfmpegPermissionsException extends TranscoderException {
  const InsufficientFfmpegPermissionsException(super.osCode);
  @override
  String toString() =>
      'Insufficient permissions to execute `ffmpeg`. Please ensure `ffmpeg is executable and you have sufficient permissions to run it: $osCode`';
}

class OutOfMemoryException extends TranscoderException {
  const OutOfMemoryException(super.osCode);
  @override
  String toString() => 'Out of memory while running ffmpeg: $osCode';
}

class IsADirectoryException extends TranscoderException {
  const IsADirectoryException(super.osCode);
  @override
  String toString() =>
      'Sorry. We tried reading/writing from a directory instead of a file. Please ensure all file paths are valid';
}

TranscoderException getTranscoderException(
    dynamic code, int? osCode, FileSystemClient fs) {
  if (code is Exception) {
    throw GeneralFileException(message: code.toString());
  } else if (code is int) {
    if (fs.isWindows) {
      late final TranscoderException error;
      switch (code) {
        case 1:
          error = InvalidArgumentException(osCode);
          break;
        case 2:
          error = Utf8ConversionException(osCode);
          break;
        case 3:
          error = CommunicationInitException(osCode);
          break;
        case 4:
          error = MfStartupException(osCode);
          break;
        case 5:
          error = ReaderInitializationException(osCode);
          break;
        case 6:
          error = WriterInitializationException(osCode);
          break;
        case 7:
          error = MediaTypeException(osCode);
          break;
        case 8:
          error = StreamSetupException(osCode);
          break;
        case 9:
          error = PipelineException(osCode);
          break;
        case 10:
          error = UnsupportedContainerException(osCode);
          break;
        default:
          error = UnexpectedException(osCode);
          break;
      }
      return error;
    } else if (fs.isMacOS) {
      late final TranscoderException error;
      switch (code) {
        case 1:
          error = InvalidArgumentException(osCode);
          break;
        case 2:
          error = Utf8ConversionException(osCode);
          break;
        case 3:
          error = AssetLoadingException(osCode);
          break;
        case 4:
          error = ReaderInitializationException(osCode);
          break;
        case 5:
          error = WriterInitializationException(osCode);
          break;
        case 6:
          error = StreamSetupException(osCode);
          break;
        case 7:
          error = PipelineException(osCode);
          break;
        case 8:
          error = UnsupportedAudioOnlyException(osCode);
          break;
        case 9:
          error = UnsupportedContainerException(osCode);
          break;
        default:
          error = UnexpectedException(osCode);
          break;
      }
      return error;
    } else if (fs.isLinux) {
      late final TranscoderException error;
      switch (code) {
        case 126:
          error = InsufficientFfmpegPermissionsException(osCode);
          break;
        case 127:
          error = FfmpegNotFoundException(null);
          break;
        case 137:
          error = OutOfMemoryException(osCode);
          break;
        case 234:
          error = FfmpegTranscodingFailedException(osCode);
          break;
        case 235:
          error = IsADirectoryException(osCode);
          break;
        default:
          error = UnexpectedException(osCode);
      }
      return error;
    } else {
      throw UnsupportedPlatformException(null);
    }
  } else {
    throw UnexpectedException(null);
  }
}
