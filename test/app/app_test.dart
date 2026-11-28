import 'package:media_asset_optimizer/src/app.dart';
import 'package:media_asset_optimizer/src/io/file_system_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../mocks/mock_io.dart';

void main() {
  group('App output path', () {
    // A non-media file keeps the runner from touching the real filesystem;
    const singleFile = 'notes.txt';
    final projectRoot = p.join(p.current, 'fake_project');
    late FakeFileSystem fs;
    late MockConsole console;

    setUp(() {
      fs = FakeFileSystem(projectRoot: projectRoot, singleFile: singleFile);
      console = MockConsole();
    });

    // App.start is async but declares a void return type, so let its
    // microtasks settle before making assertions.
    Future<void> startApp(List<String> args) async {
      App(fs: fs, console: console).start(args);
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    test('rejects a file in place of an output directory', () async {
      await startApp(['--single-file', singleFile, '-o', singleFile]);

      verify(
        () => console.printError(any(that: contains('Directory is expected'))),
      ).called(1);
      expect(fs.createdDirs, isEmpty);
    });
  });
}

/// Filesystem double that records directory creation and never exits the
/// test process when App calls exitApp.
class FakeFileSystem extends FileSystemClient {
  FakeFileSystem({required String projectRoot, required this.singleFile})
      : _projectRoot = projectRoot,
        super(ignoredDirs: const ['test', 'build']);

  final String _projectRoot;

  @override
  String get projectRoot => _projectRoot;

  final String singleFile;
  final createdDirs = <String>[];
  Set<String> existingDirectories = {};

  @override
  void exitApp(int code) {}

  @override
  void cleanupOnAppExit({required Function onExit}) {}

  @override
  bool isDirectory(String path) =>
      existingDirectories.contains(p.normalize(path));

  @override
  bool isFile(String path) => p.basename(path) == p.basename(singleFile);

  @override
  void createDir(String path) => createdDirs.add(p.normalize(path));

  @override
  bool fileExists(String path) => true;
}
