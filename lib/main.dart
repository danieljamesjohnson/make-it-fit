import 'package:compress_video/compress_video.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'src/fit.dart';

void main() => runApp(const MakeItFitApp());

/// One screen, three steps: set the size limit, pick a video, make it fit.
class MakeItFitApp extends StatelessWidget {
  const MakeItFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Make It Fit',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: const FitScreen(),
    );
  }
}

class FitScreen extends StatefulWidget {
  const FitScreen({super.key});

  @override
  State<FitScreen> createState() => _FitScreenState();
}

class _FitScreenState extends State<FitScreen> {
  final TextEditingController _limit = TextEditingController(text: '25');
  final ImagePicker _picker = ImagePicker();
  final CompressVideo _compressor = CompressVideo();

  XFile? _video;
  int? _videoBytes;
  FitStatus _status = FitStatus.idle;
  double _progress = 0;
  int _attempt = 0;
  FitOutcome? _outcome;
  String? _error;
  FitRunner? _runner;

  double? get _limitMb => double.tryParse(_limit.text.trim());

  bool get _busy => _status == FitStatus.working;

  Future<void> _pickVideo() async {
    final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final int bytes = await picked.length();
    setState(() {
      _video = picked;
      _videoBytes = bytes;
      _outcome = null;
      _error = null;
      _status = FitStatus.idle;
    });
  }

  Future<void> _run() async {
    final double? limitMb = _limitMb;
    final XFile? video = _video;
    if (limitMb == null || limitMb <= 0 || video == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _status = FitStatus.working;
      _progress = 0;
      _attempt = 0;
      _outcome = null;
      _error = null;
    });
    if (kIsWeb) {
      await _webPreview(mbToBytes(limitMb));
      return;
    }
    final FitRunner runner = FitRunner(
      compressor: _compressor,
      inputPath: video.path,
      inputBytes: _videoBytes ?? 0,
      limitBytes: mbToBytes(limitMb),
      onProgress: (int attempt, double percent) {
        if (!mounted) return;
        setState(() {
          _attempt = attempt;
          _progress = percent;
        });
      },
    );
    _runner = runner;
    try {
      final FitOutcome outcome = await runner.run();
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _status = FitStatus.done;
      });
    } on CompressVideoException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.reason == CompressVideoErrorReason.cancelled
            ? 'Cancelled.'
            : describeError(e);
        _status = FitStatus.idle;
      });
    } finally {
      _runner = null;
    }
  }

  /// The browser has no video encoder: this walks the same states with a pretend pass so the
  /// flow can be reviewed on the web. The result card says so.
  Future<void> _webPreview(int limitBytes) async {
    final int inputBytes = _videoBytes ?? 0;
    for (int p = 0; p <= 100; p += 4) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() {
        _attempt = 1;
        _progress = p.toDouble();
      });
    }
    if (!mounted) return;
    final bool already = inputBytes <= limitBytes;
    setState(() {
      _outcome = FitOutcome(
        path: _video!.path,
        bytes: already ? inputBytes : (limitBytes * 0.84).round(),
        inputBytes: inputBytes,
        limitBytes: limitBytes,
        alreadyFit: already,
      );
      _status = FitStatus.done;
    });
  }

  Future<void> _share() async {
    final FitOutcome? outcome = _outcome;
    if (outcome == null) return;
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(outcome.path, mimeType: 'video/mp4')]),
    );
  }

  @override
  void dispose() {
    _runner?.cancel();
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final double? limitMb = _limitMb;
    final bool canRun = !_busy && _video != null && limitMb != null && limitMb > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Make It Fit')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          if (kIsWeb) ...<Widget>[
            MaterialBanner(
              content: const Text(
                'Web preview: the real compression runs on Android, iOS and macOS. '
                'Here the Compress step is simulated so the flow can be reviewed.',
              ),
              leading: const Icon(Icons.info_outline),
              actions: const <Widget>[SizedBox.shrink()],
            ),
            const SizedBox(height: 16),
          ],
          Text('1. Size limit', style: text.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _limit,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              suffixText: 'MB',
              border: OutlineInputBorder(),
              helperText: 'The file will come out under this size.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final FitPreset p in FitPreset.values)
                ChoiceChip(
                  label: Text('${p.label} ${p.mb}'),
                  selected: limitMb == p.mb,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _limit.text = '${p.mb}'),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text('2. Video', style: text.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickVideo,
            icon: const Icon(Icons.video_library_outlined),
            label: Text(_video == null ? 'Pick a video' : 'Pick a different video'),
          ),
          if (_video != null && _videoBytes != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '${_video!.name}  ·  ${formatMb(_videoBytes!)}',
              style: text.bodyMedium,
            ),
          ],
          const SizedBox(height: 28),
          Text('3. Make it fit', style: text.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: canRun ? _run : null,
            icon: const Icon(Icons.compress),
            label: const Text('Compress'),
          ),
          if (_busy) ...<Widget>[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress / 100),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _attempt <= 1
                        ? 'Compressing… ${_progress.round()}%'
                        : 'Still a bit big, trying again (pass $_attempt)… ${_progress.round()}%',
                  ),
                ),
                TextButton(
                  onPressed: () => _runner?.cancel(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_outcome != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _outcome!.alreadyFit
                          ? 'Already fits: ${formatMb(_outcome!.bytes)}'
                          : 'Done: ${formatMb(_outcome!.bytes)} (was ${formatMb(_outcome!.inputBytes)})',
                      style: text.titleMedium,
                    ),
                    if (!_outcome!.fits) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        'Could not get under ${formatMb(_outcome!.limitBytes)} without '
                        'making it unwatchable. This is the smallest good version.',
                        style: text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _share,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum FitStatus { idle, working, done }
