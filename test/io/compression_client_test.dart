import 'dart:io';
import 'dart:typed_data';

import 'package:media_asset_optimizer/src/io/bindings/ffmpeg_transcoder.dart';
import 'package:media_asset_optimizer/src/io/compression_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../mocks/mock_io.dart';

void main() {
  group('CompressionClient', () {
    late MockFileSystemClient fs;
    late MockFfmpegTranscoder transcoder;
    late Uint8List imageBytes;
    late String smallerFile;
    final transcodedTo = <String>[];

    setUpAll(() {
      registerFallbackValue(Uint8List(0));
    });

    setUp(() {
      fs = MockFileSystemClient();
      transcoder = MockFfmpegTranscoder();
      transcodedTo.clear();
      smallerFile = '';
      imageBytes = File(p.join(
        Directory.current.path,
        'example/web/icons/Icon-192.png',
      )).readAsBytesSync();

      when(() => fs.isWindows).thenReturn(false);
      when(() => fs.isMacOS).thenReturn(false);
      when(() => fs.isLinux).thenReturn(true);
      when(() => fs.fileExists(any())).thenReturn(true);
      when(() => fs.readAsBytes(any())).thenReturn(imageBytes);
      when(() => fs.writeAsBytes(any(), any())).thenAnswer((_) {});
      when(() => fs.createFile(any())).thenAnswer((_) {});
      when(() => fs.deleteSync(any())).thenAnswer((_) {});
      when(() => fs.lengthSync(any())).thenAnswer((invocation) {
        final path = invocation.positionalArguments.first as String;
        return path == smallerFile ? 40 : 100;
      });
      when(() => transcoder.transcode(
            fs: fs,
            inputPath: any(named: 'inputPath'),
            outputPath: any(named: 'outputPath'),
            quality: any(named: 'quality'),
          )).thenAnswer((invocation) {
        transcodedTo.add(invocation.namedArguments[#outputPath] as String);
        return (status: 0, hresult: 0);
      });
    });

    CompressionClient client({String? outputPath}) {
      final client = CompressionClient(fs: fs, outputPath: outputPath);
      client.fft = transcoder;
      return client;
    }

    test('overwrites the original image when no output path is set', () {
      client().compressImage('assets/logo.png');

      verify(() => fs.writeAsBytes('assets/logo.png', any())).called(1);
    });

    test('transcodes into the output folder without touching the original', () {
      final outputDir = p.join('out', 'compressed');
      final target = p.join(outputDir, 'intro.mp4');
      smallerFile = target;

      final saved = client(outputPath: outputDir)
          .compressVideoOrAudio('videos/intro.mp4');

      expect(saved, 60);
      expect(transcodedTo, [target]);
      verifyNever(() => fs.writeAsBytes('videos/intro.mp4', any()));
      verifyNever(() => fs.deleteSync(any()));
    });

    test('leaves the original alone when transcoding saves no space', () {
      final saved = client(outputPath: p.join('out', 'compressed'))
          .compressVideoOrAudio('videos/intro.mp4');

      expect(saved, 0);
      verifyNever(() => fs.writeAsBytes(any(), any()));
    });
  });
}

class MockFfmpegTranscoder extends Mock implements FfmpegTranscoder {}
