import 'package:media_asset_optimizer/src/app/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../mocks/mock_io.dart';

void main() {
  group('Cli', () {
    final mockConsole = MockConsole();
    test('parses quality with --all', () {
      final cli = Cli(console: mockConsole);

      expect(
        cli.start(['--all', '--quality', '75']),
        CliMode.compressAll,
      );
      expect(cli.quality, 75);
    });

    test('parses the short quality flag', () {
      final cli = Cli(console: mockConsole);

      expect(cli.start(['-a', '-q', '25']), CliMode.compressAll);
      expect(cli.quality, 25);
    });

    test('keeps quality null when not provided', () {
      final cli = Cli(console: mockConsole);

      expect(cli.start(['--all']), CliMode.compressAll);
      expect(cli.quality, isNull);
    });

    test('parses a single file', () {
      final cli = Cli(console: mockConsole);

      expect(
        cli.start(['--single-file', 'assets/logo.png']),
        CliMode.compressFile,
      );
      expect(cli.singleFile, 'assets/logo.png');
    });

    test('parses the short single file flag', () {
      final cli = Cli(console: mockConsole);

      expect(cli.start(['-f', 'assets/logo.png']), CliMode.compressFile);
      expect(cli.singleFile, 'assets/logo.png');
    });

    test('rejects quality outside 1-100', () {
      for (final quality in ['0', '101', 'high']) {
        final cli = Cli(console: mockConsole);
        expect(
          cli.start(['--all', '--quality', quality]),
          CliMode.none,
        );
      }
    });

    test('does not launch the tutorial for --select', () {
      expect(
          Cli(console: mockConsole).start(['--select']), CliMode.compressSome);
    });

    test('parses the help flag', () {
      expect(Cli(console: mockConsole).start(['-h']), CliMode.none);
      expect(Cli(console: mockConsole).start(['--help']), CliMode.none);
    });

    test('parses the output flag', () {
      const folder = 'out/compressed';
      final cli = Cli(console: mockConsole);
      expect(
        cli.start(['--all', '--output-path', folder]),
        CliMode.compressAll,
      );
      expect(cli.outputPath, p.join('out', 'compressed'));
      expect(cli.start(['-a', '-o', folder]), CliMode.compressAll);
      expect(cli.outputPath, p.join('out', 'compressed'));
    });

    test('parses the output path in single file mode', () {
      const folder = 'out/compressed';
      final cli = Cli(console: mockConsole);

      expect(
        cli.start(['--single-file', 'assets/logo.png', '-o', folder]),
        CliMode.compressFile,
      );
      expect(cli.singleFile, 'assets/logo.png');
      expect(cli.outputPath, p.join('out', 'compressed'));
    });
  });
}
