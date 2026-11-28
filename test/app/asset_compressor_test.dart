import 'dart:collection';

import 'package:media_asset_optimizer/src/app/asset_compressor.dart';
import 'package:media_asset_optimizer/src/io/console.dart';
import 'package:path/path.dart' as p;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks/mock_io.dart';
import '../mocks/sample_data.dart';

void main() {
  group('Asset compressor', () {
    final mockFs = MockFileSystemClient();
    final mockConsole = MockConsole();
    final mockClient = MockCompressionClient();
    test('analysis result is empty when assets are empty', () {
      final compressor = AssetCompressor(
        allAssets: {},
        fs: mockFs,
        console: mockConsole,
        client: mockClient,
      );
      final result = compressor.analyze();

      expect(result.assetsForCompression.length, 0);
    });

    test('analysis builds the asset tree', () {
      final assets = samplePubspecAssets; // has 3 asset folders under root

      final console = MockConsole();
      when(() => console.buildTree(assets.toList()))
          .thenAnswer((_) => Console().buildTree(assets.toList()));

      final compressor = AssetCompressor(
        allAssets: assets,
        fs: mockFs,
        console: console,
        client: mockClient,
      );
      final result = compressor.analyze();

      expect(result.assetsForCompressionTree.values.first, isA<SplayTreeMap>());
      expect(result.assetsForCompressionTree.values.first.length, 3); // 3 dirs
      expect(
        result.assetsForCompressionTree.values.first.keys.first,
        'android',
      );
    });

    test('analysis gets initial size of files', () {
      final assets = samplePubspecAssets;

      final fs = MockFileSystemClient();
      when(() => fs.lengthSync(any())).thenAnswer((_) => 10);

      final compressor = AssetCompressor(
        allAssets: assets,
        fs: fs,
        console: mockConsole,
        client: mockClient,
      );

      final result = compressor.analyze();

      expect(
        result.spaceOfMediaAssetsBeforeCompress,
        10 * assets.length,
      );
    });

    group('compressFile', () {
      const assetPath = 'assets/logo.png';

      test('compresses a media file and reports the freed space', () async {
        final fs = MockFileSystemClient();
        final console = MockConsole();
        final client = MockCompressionClient();
        when(() => fs.lengthSync(any())).thenReturn(100);
        when(() => client.compressMedia(any())).thenReturn(30);

        final compressor = AssetCompressor(
          allAssets: {},
          fs: fs,
          console: console,
          client: client,
        );

        final result = await compressor.compressFile(assetPath);

        expect(result, isNotNull);
        expect(result!.hasAnalyzed, isTrue);
        expect(result.hasCompressed, isTrue);
        expect(result.allMediaAssets, {assetPath});
        expect(result.assetsForCompression, [assetPath]);
        expect(result.spaceOfMediaAssetsBeforeCompress, 100);
        expect(result.potentiallySavedSpace, 60);
        expect(result.spaceOfMediaAssetsAfterCompress, 70);
        expect(compressor.result, same(result));
        verify(() => client.compressMedia(p.join('rootProj', assetPath)))
            .called(1);
        verify(() => console.printSuccess(
              any(that: contains('You have freed up')),
            )).called(1);
      });

      test('reports failure when compression frees no space', () async {
        final fs = MockFileSystemClient();
        final console = MockConsole();
        final client = MockCompressionClient();
        when(() => fs.lengthSync(any())).thenReturn(100);
        when(() => client.compressMedia(any())).thenReturn(0);

        final compressor = AssetCompressor(
          allAssets: {},
          fs: fs,
          console: console,
          client: client,
        );

        final result = await compressor.compressFile(assetPath);

        expect(result!.hasCompressed, isFalse);
        expect(result.spaceOfMediaAssetsAfterCompress, 100);
        verify(() => console.printError(
              any(that: contains('Unable to compress this asset')),
            )).called(1);
      });
    });

    group('compressMultiple', () {
      const assets = {
        'assets/logo.png',
        'assets/theme.mp3',
        'videos/intro.mp4',
      };

      setUp(() {
        registerFallbackValue(() => 0.0);
      });

      test('does nothing when analysis found no assets', () async {
        final console = MockConsole();
        final client = MockCompressionClient();
        final compressor = AssetCompressor(
          allAssets: {},
          fs: MockFileSystemClient(),
          console: console,
          client: client,
        );
        final analyzed = compressor.analyze();

        final result = await compressor.compressMultiple();

        expect(result, same(analyzed));
        expect(result!.hasCompressed, isFalse);
        expect(result.assetsForCompression, isEmpty);
        verify(() => console.printSuccess(
              any(that: contains('No assets to compress')),
            )).called(1);
        verifyNever(() => client.compressMedia(any()));
      });

      test('compresses analyzed assets after confirmation', () async {
        final fs = MockFileSystemClient();
        final console = MockConsole();
        final client = MockCompressionClient();
        when(() => fs.lengthSync(any())).thenReturn(100);
        when(() => client.compressMedia(any())).thenReturn(10);
        when(() => console.read()).thenReturn('y');
        stubPrintLoading<double>(console);

        final compressor = AssetCompressor(
          allAssets: assets,
          fs: fs,
          console: console,
          client: client,
        );
        final analyzed = compressor.analyze();

        final result = await compressor.compressMultiple();

        expect(result, same(analyzed));
        expect(analyzed.spaceOfMediaAssetsBeforeCompress, 100 * assets.length);
        expect(analyzed.hasCompressed, isTrue);
        expect(
          analyzed.spaceOfMediaAssetsAfterCompress,
          90 * assets.length,
        );
        for (final asset in assets) {
          verify(() => client.compressMedia(p.join('rootProj', asset)))
              .called(1);
        }
      });

      test('leaves assets untouched when the user declines', () async {
        final console = MockConsole();
        final client = MockCompressionClient();
        when(() => console.read()).thenReturn('n');

        final compressor = AssetCompressor(
          allAssets: assets,
          fs: MockFileSystemClient(),
          console: console,
          client: client,
        );
        final analyzed = compressor.analyze();

        final result = await compressor.compressMultiple();

        expect(result, same(analyzed));
        expect(result!.hasCompressed, isFalse);
        expect(result.spaceOfMediaAssetsAfterCompress, isNull);
        verify(() => console.printError(
              any(that: contains('Compression cancelled')),
            )).called(1);
        verifyNever(() => client.compressMedia(any()));
      });

      test('skips assets selected to ignore', () async {
        final console = MockConsole();
        final client = MockCompressionClient();
        final orderedAssets = assets.toList();
        when(() => console.printMultiSelect(
              message: any(named: 'message'),
              options: any(named: 'options'),
            )).thenReturn([0, 2]);
        when(() => console.read()).thenReturn('y');
        stubPrintLoading<double>(console);

        final compressor = AssetCompressor(
          allAssets: assets,
          fs: MockFileSystemClient(),
          console: console,
          client: client,
        );
        compressor.analyze();

        final result = await compressor.compressMultiple(
          selectAssetsToIgnore: true,
        );

        expect(result!.assetsForCompression, [orderedAssets[1]]);
        expect(result.hasCompressed, isTrue);
        verify(() => client.compressMedia(p.join('rootProj', orderedAssets[1])))
            .called(1);
        verifyNever(
            () => client.compressMedia(p.join('rootProj', orderedAssets[0])));
        verifyNever(
            () => client.compressMedia(p.join('rootProj', orderedAssets[2])));
      });

      test('does not compress when every asset is selected to ignore',
          () async {
        final console = MockConsole();
        final client = MockCompressionClient();
        when(() => console.printMultiSelect(
              message: any(named: 'message'),
              options: any(named: 'options'),
            )).thenReturn([0, 1, 2]);

        final compressor = AssetCompressor(
          allAssets: assets,
          fs: MockFileSystemClient(),
          console: console,
          client: client,
        );
        compressor.analyze();

        final result = await compressor.compressMultiple(
          selectAssetsToIgnore: true,
        );

        expect(result!.assetsForCompression, isEmpty);
        expect(result.hasCompressed, isFalse);
        verify(() => console.printSuccess(
              any(that: contains('Nothing to compress')),
            )).called(1);
        verifyNever(() => console.printInputPrompt(any()));
        verifyNever(() => client.compressMedia(any()));
      });

      test('keeps compressing other assets when one fails', () async {
        final fs = MockFileSystemClient();
        final console = MockConsole();
        final client = MockCompressionClient();
        final orderedAssets = assets.toList();
        when(() => fs.lengthSync(any())).thenReturn(100);
        when(() => client.compressMedia(any())).thenReturn(10);
        when(() => client.compressMedia(
              any(that: contains('theme.mp3')),
            )).thenThrow(Exception('transcoder failed'));
        when(() => console.read()).thenReturn('y');
        stubPrintLoading<double>(console);

        final compressor = AssetCompressor(
          allAssets: assets,
          fs: fs,
          console: console,
          client: client,
        );
        compressor.analyze();

        final result = await compressor.compressMultiple();

        expect(result!.hasCompressed, isTrue);
        expect(result.spaceOfMediaAssetsAfterCompress, 280);
        verify(() => console.printError(
              any(that: contains('Error compressing')),
            )).called(1);
        for (final asset in orderedAssets) {
          verify(() => client.compressMedia(p.join('rootProj', asset)))
              .called(1);
        }
      });
    });
  });
}
