sealed class FileException implements Exception {
  final String? message;

  const FileException({this.message});

  @override
  String toString() =>
      message ??
      'A file error has occured. Please ensure all input paths are valid';
}

class GeneralFileException extends FileException {
  const GeneralFileException({required String message});

  @override
  String toString() => message ?? super.toString();
}

class InvalidDartProjectException extends FileException {
  InvalidDartProjectException({super.message});

  @override
  String toString() => message ?? 'Invalide Dart/Flutter project';
}

class InvalidPubspecFileException extends FileException {
  InvalidPubspecFileException({super.message});

  @override
  String toString() =>
      message ??
      'Invalid Dart/Flutter pubspec.yaml file. Missing name: and environment: sections';
}

class ProjectRootNotFoundException extends FileException {
  ProjectRootNotFoundException({super.message});

  @override
  String toString() =>
      message ?? 'Could not find project root with pubspec.yaml';
}

class FFmpegProcessException extends FileException {
  FFmpegProcessException({super.message, required this.reason});
  final String reason;

  @override
  String toString() => '${message ?? 'Ffmpeg process error'}: $reason';
}

class IsAFileException extends FileException {
  IsAFileException(this.path);
  final String path;

  @override
  String toString() => '$path is a file. Directory is expected';
}

class NotRelativeToProjectRootException extends FileException {
  NotRelativeToProjectRootException(this.path);
  final String path;
  @override
  String toString() =>
      'Error processing $path. Please provide an output path that is relative to the project root';
}
