import 'dart:typed_data';

import 'package:compress_video/compress_video.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'src/fit.dart';
import 'src/ui.dart';

void main() => runApp(const MakeItFitApp());

/// One screen: choose a video, choose what it has to fit under, make it fit, share.
class MakeItFitApp extends StatelessWidget {
  const MakeItFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme base = GoogleFonts.interTextTheme();
    return MaterialApp(
      title: 'Make It Fit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Paper.canvas,
        colorScheme: const ColorScheme.light(
          primary: Paper.text,
          onPrimary: Colors.white,
          surface: Paper.canvas,
          onSurface: Paper.text,
          error: Paper.danger,
        ),
        textTheme: base.apply(bodyColor: Paper.text, displayColor: Paper.text),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
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

enum _Phase { pick, ready, working, done }

class _FitScreenState extends State<FitScreen> {
  final ImagePicker _picker = ImagePicker();
  final CompressVideo _compressor = CompressVideo();
  final TextEditingController _custom = TextEditingController(text: '10');

  XFile? _video;
  int? _videoBytes;
  Uint8List? _thumb;
  FitPreset? _preset = FitPreset.email;
  _Phase _phase = _Phase.pick;
  double _progress = 0;
  int _attempt = 0;
  FitOutcome? _outcome;
  String? _error;
  FitRunner? _runner;

  double? get _limitMb =>
      _preset?.mb.toDouble() ?? double.tryParse(_custom.text.trim());

  Future<void> _pickVideo() async {
    final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final int bytes = await picked.length();
    Uint8List? thumb;
    if (!kIsWeb) {
      try {
        thumb = await _compressor.getThumbnail(picked.path, maxDimensionPx: 720);
      } on CompressVideoException {
        thumb = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _video = picked;
      _videoBytes = bytes;
      _thumb = thumb;
      _outcome = null;
      _error = null;
      _phase = _Phase.ready;
    });
  }

  void _reset() {
    _runner?.cancel();
    setState(() {
      _video = null;
      _videoBytes = null;
      _thumb = null;
      _outcome = null;
      _error = null;
      _progress = 0;
      _phase = _Phase.pick;
    });
  }

  Future<void> _run() async {
    final double? limitMb = _limitMb;
    final XFile? video = _video;
    if (limitMb == null || limitMb <= 0 || video == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.working;
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
        _phase = _Phase.done;
      });
    } on CompressVideoException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.reason == CompressVideoErrorReason.cancelled ? null : describeError(e);
        _phase = _Phase.ready;
      });
    } finally {
      _runner = null;
    }
  }

  /// The browser has no video encoder: walk the same states with a pretend pass so the
  /// flow can be reviewed on the web. The footer says so.
  Future<void> _webPreview(int limitBytes) async {
    final int inputBytes = _videoBytes ?? 0;
    for (int p = 0; p <= 100; p += 3) {
      await Future<void>.delayed(const Duration(milliseconds: 45));
      if (!mounted || _phase != _Phase.working) return;
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
      _phase = _Phase.done;
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
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool working = _phase == _Phase.working;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              children: <Widget>[
                Text(
                  'Make it fit.',
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Shrink a video so it sends.',
                  style: text.bodyLarge?.copyWith(color: Paper.muted),
                ),
                const SizedBox(height: 28),
                VideoHero(
                  video: _video,
                  bytes: _videoBytes,
                  thumbnail: _thumb,
                  enabled: !working,
                  onTap: _pickVideo,
                ),
                const SizedBox(height: 24),
                AnimatedOpacity(
                  duration: Motion.quick,
                  opacity: _video == null ? 0.45 : 1,
                  child: IgnorePointer(
                    ignoring: _video == null || working || _phase == _Phase.done,
                    child: LimitPicker(
                      selected: _preset,
                      customController: _custom,
                      onChanged: (FitPreset? p) => setState(() => _preset = p),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedSize(
                  duration: Motion.settle,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: Motion.settle,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _action(text),
                  ),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: Paper.danger),
                  ),
                ],
                const SizedBox(height: 40),
                Text(
                  kIsWeb
                      ? 'Web preview. Compression is simulated here; on the phone it runs for real, '
                          'entirely on the device.'
                      : 'Everything happens on this phone. Your original is never changed.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: Paper.faint, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(TextTheme text) {
    switch (_phase) {
      case _Phase.pick:
      case _Phase.ready:
        final bool ready = _video != null && (_limitMb ?? 0) > 0;
        return BigButton(
          key: const ValueKey<String>('go'),
          label: 'Make it fit',
          enabled: ready,
          onPressed: _run,
        );
      case _Phase.working:
        return Column(
          key: const ValueKey<String>('working'),
          children: <Widget>[
            ProgressButton(
              progress: _progress / 100,
              label: _attempt <= 1
                  ? 'Shrinking'
                  : 'Still a little big, pass $_attempt',
            ),
            const SizedBox(height: 10),
            QuietButton(label: 'Cancel', onPressed: () => _runner?.cancel()),
          ],
        );
      case _Phase.done:
        final FitOutcome o = _outcome!;
        return Column(
          key: const ValueKey<String>('done'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ResultPanel(outcome: o),
            const SizedBox(height: 12),
            BigButton(label: 'Share', icon: Icons.arrow_outward_rounded, onPressed: _share),
            const SizedBox(height: 10),
            QuietButton(label: 'Start over', onPressed: _reset),
          ],
        );
    }
  }
}
