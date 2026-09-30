// Proves the fit loop on a real engine: a 4.4 MB, 1080p60 corpus clip must come out under
// a 1 MB limit, and a clip already under its limit must be returned untouched.
import 'dart:io';

import 'package:compress_video/compress_video.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:make_it_fit/src/fit.dart';
import 'package:path_provider/path_provider.dart';

Future<String> _copyAsset(String name) async {
  final Directory dir = await getTemporaryDirectory();
  final File out = File('${dir.path}/$name');
  final ByteData data = await rootBundle.load('integration_test/assets/$name');
  await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
  return out.path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a 4.4 MB clip comes out under a 1 MB limit', (WidgetTester tester) async {
    final String input = await _copyAsset('portrait_hibitrate_1080p60.mp4');
    final int inputBytes = await File(input).length();
    expect(inputBytes, greaterThan(mbToBytes(1)));

    final List<int> passes = <int>[];
    final FitRunner runner = FitRunner(
      compressor: CompressVideo(),
      inputPath: input,
      inputBytes: inputBytes,
      limitBytes: mbToBytes(1),
      onProgress: (int attempt, double percent) {
        if (!passes.contains(attempt)) passes.add(attempt);
      },
    );
    final FitOutcome outcome = await runner.run().timeout(const Duration(minutes: 4));

    // ignore: avoid_print
    print('FIT_RESULT input=$inputBytes output=${outcome.bytes} limit=${outcome.limitBytes} '
        'passes=${passes.length} fits=${outcome.fits}');
    expect(outcome.alreadyFit, isFalse);
    expect(outcome.fits, isTrue, reason: 'output must be under the limit');
    expect(outcome.bytes, lessThan(inputBytes));
    expect(File(outcome.path).existsSync(), isTrue);
    expect(outcome.path, isNot(input));
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('a clip already under the limit is returned untouched', (WidgetTester tester) async {
    final String input = await _copyAsset('portrait_hibitrate_1080p60.mp4');
    final int inputBytes = await File(input).length();
    final FitRunner runner = FitRunner(
      compressor: CompressVideo(),
      inputPath: input,
      inputBytes: inputBytes,
      limitBytes: mbToBytes(25),
      onProgress: (_, _) {},
    );
    final FitOutcome outcome = await runner.run();
    expect(outcome.alreadyFit, isTrue);
    expect(outcome.path, input);
    expect(outcome.bytes, inputBytes);
  });
}
