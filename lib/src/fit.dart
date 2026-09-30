import 'package:compress_video/compress_video.dart';

import 'fit_files_stub.dart' if (dart.library.io) 'fit_files_io.dart';

/// Size limits people actually hit, in decimal megabytes (1 MB = 1,000,000 bytes, the
/// unit every mail client and chat app quotes).
enum FitPreset {
  email('Email', 25),
  discord('Discord', 20),
  whatsapp('WhatsApp', 16);

  const FitPreset(this.label, this.mb);

  final String label;
  final int mb;
}

int mbToBytes(double mb) => (mb * 1000000).round();

String formatMb(int bytes) {
  final double mb = bytes / 1000000;
  return mb >= 100 ? '${mb.round()} MB' : '${mb.toStringAsFixed(1)} MB';
}

/// What a run produced. [fits] is false only when even the last, smallest pass could not
/// get under the limit; the file is still the smallest good version we made.
class FitOutcome {
  const FitOutcome({
    required this.path,
    required this.bytes,
    required this.inputBytes,
    required this.limitBytes,
    required this.alreadyFit,
  });

  final String path;
  final int bytes;
  final int inputBytes;
  final int limitBytes;
  final bool alreadyFit;

  bool get fits => bytes <= limitBytes;
}

/// Gets one video under a byte limit, or as close as a watchable encode allows.
///
/// The plugin's `targetSizeMb` lands within about 15 percent of the request, and hardware
/// encoders overshoot by a few percent, so a single pass at the limit is not a guarantee.
/// This asks for the limit minus a headroom, checks the real output size the plugin reports,
/// and if the file is still over the limit asks again with the target scaled down by the
/// miss, up to [maxAttempts] passes. Each pass steps the preset down one notch as well, so a
/// very long clip can still fit by shrinking its frame rather than starving its bitrate.
class FitRunner {
  FitRunner({
    required this.compressor,
    required this.inputPath,
    required this.inputBytes,
    required this.limitBytes,
    required this.onProgress,
    this.maxAttempts = 3,
    this.headroom = 0.90,
  });

  final CompressVideo compressor;
  final String inputPath;
  final int inputBytes;
  final int limitBytes;
  final void Function(int attempt, double percent) onProgress;
  final int maxAttempts;

  /// Fraction of the limit to ask for on the first pass.
  final double headroom;

  CompressJob? _current;
  bool _cancelled = false;

  Future<void> cancel() async {
    _cancelled = true;
    await _current?.cancel();
  }

  Future<FitOutcome> run() async {
    if (inputBytes <= limitBytes) {
      return FitOutcome(
        path: inputPath,
        bytes: inputBytes,
        inputBytes: inputBytes,
        limitBytes: limitBytes,
        alreadyFit: true,
      );
    }

    double targetBytes = limitBytes * headroom;
    String? bestPath;
    int bestBytes = inputBytes;
    const List<CompressPreset> ladder = <CompressPreset>[
      CompressPreset.p720,
      CompressPreset.p480,
      CompressPreset.p360,
    ];

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_cancelled) {
        throw const CompressVideoException(
          reason: CompressVideoErrorReason.cancelled,
          message: 'cancelled before pass started',
        );
      }
      final CompressPreset preset = ladder[(attempt - 1).clamp(0, ladder.length - 1)];
      final CompressJob job = compressor.compress(
        inputPath,
        options: CompressOptions(
          preset: preset,
          targetSizeMb: targetBytes / 1000000,
          audio: const AudioReencode(bitrateBps: 96000, channels: 2),
        ),
      );
      _current = job;
      job.progress.listen((double p) => onProgress(attempt, p));
      final CompressResult result = await job.result;
      _current = null;

      final int bytes = result.outputBytes;
      if (bytes < bestBytes) {
        if (bestPath != null) deleteFileQuietly(bestPath);
        bestPath = result.outputPath;
        bestBytes = bytes;
      } else if (result.outputPath != inputPath) {
        deleteFileQuietly(result.outputPath);
      }
      if (bestBytes <= limitBytes) break;
      if (result.usedOriginal) break; // Nothing smaller can be made without upscaling risk.

      // Scale the next request by how far this pass missed, with a little extra margin.
      targetBytes = targetBytes * (limitBytes / bytes) * 0.95;
    }

    return FitOutcome(
      path: bestPath ?? inputPath,
      bytes: bestBytes,
      inputBytes: inputBytes,
      limitBytes: limitBytes,
      alreadyFit: false,
    );
  }
}

String describeError(CompressVideoException e) {
  switch (e.reason) {
    case CompressVideoErrorReason.fileNotFound:
      return 'That video is no longer where it was. Pick it again.';
    case CompressVideoErrorReason.unsupportedInput:
      return 'This file is not a video this phone can decode.';
    case CompressVideoErrorReason.outOfSpace:
      return 'Not enough free space on the phone to write the smaller file.';
    case CompressVideoErrorReason.interrupted:
      return 'The system interrupted the job. Keep the app open and try again.';
    case CompressVideoErrorReason.encoderUnavailable:
      return 'The video encoder is busy or unavailable. Try again in a moment.';
    case CompressVideoErrorReason.decoderUnavailable:
      return 'This phone cannot decode that video format.';
    case CompressVideoErrorReason.cancelled:
      return 'Cancelled.';
    case CompressVideoErrorReason.io:
    case CompressVideoErrorReason.unknown:
      return 'Something went wrong: ${e.message}';
  }
}
