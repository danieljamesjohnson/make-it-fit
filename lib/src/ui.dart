import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'fit.dart';

/// Palette: warm paper, near-black ink, one quiet accent. No brand colour shouting.
abstract final class Paper {
  static const Color canvas = Color(0xFFFAFAF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE6E5E1);
  static const Color text = Color(0xFF151513);
  static const Color muted = Color(0xFF6B6B66);
  static const Color faint = Color(0xFF9E9E98);
  static const Color fill = Color(0xFFF1F0EC);
  static const Color danger = Color(0xFFB4372F);
  static const Color good = Color(0xFF2F7A4C);
}

abstract final class Motion {
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration settle = Duration(milliseconds: 260);
}

const BorderRadius _r = BorderRadius.all(Radius.circular(18));

/// The video is the hero: a tall rounded surface that is the picker when empty and the
/// preview once chosen. Tapping it again changes the video.
class VideoHero extends StatelessWidget {
  const VideoHero({
    super.key,
    required this.video,
    required this.bytes,
    required this.thumbnail,
    required this.enabled,
    required this.onTap,
  });

  final XFile? video;
  final int? bytes;
  final Uint8List? thumbnail;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool has = video != null;
    return _Pressable(
      enabled: enabled,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.settle,
        curve: Curves.easeOutCubic,
        height: has ? 220 : 180,
        decoration: BoxDecoration(
          color: has ? Paper.text : Paper.surface,
          borderRadius: _r,
          border: Border.all(color: has ? Colors.transparent : Paper.line),
          boxShadow: has
              ? const <BoxShadow>[
                  BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 10)),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: Motion.settle,
          child: has ? _chosen(text) : _empty(text),
        ),
      ),
    );
  }

  Widget _empty(TextTheme text) {
    return Column(
      key: const ValueKey<String>('empty'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: Paper.fill, shape: BoxShape.circle),
          child: const Icon(Icons.add_rounded, color: Paper.text, size: 24),
        ),
        const SizedBox(height: 12),
        Text('Choose a video', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text('From your library', style: text.bodySmall?.copyWith(color: Paper.faint)),
      ],
    );
  }

  Widget _chosen(TextTheme text) {
    return Stack(
      key: const ValueKey<String>('chosen'),
      fit: StackFit.expand,
      children: <Widget>[
        if (thumbnail != null)
          Image.memory(thumbnail!, fit: BoxFit.cover)
        else
          const Center(child: Icon(Icons.videocam_rounded, color: Colors.white24, size: 48)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.transparent, Color(0xB3000000)],
              stops: <double>[0.45, 1],
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      video!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    Text(
                      formatMb(bytes ?? 0),
                      style: text.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text('Change', style: text.bodySmall?.copyWith(color: Colors.white60)),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Fit under" as one row of pills plus a custom number, inline, no second box.
class LimitPicker extends StatelessWidget {
  const LimitPicker({
    super.key,
    required this.selected,
    required this.customController,
    required this.onChanged,
  });

  /// `null` means the custom field is active.
  final FitPreset? selected;
  final TextEditingController customController;
  final ValueChanged<FitPreset?> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Fit under', style: text.bodyMedium?.copyWith(color: Paper.muted)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final FitPreset p in FitPreset.values)
              Pill(
                label: p.label,
                detail: '${p.mb} MB',
                selected: selected == p,
                onTap: () => onChanged(p),
              ),
            Pill(
              label: 'Custom',
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
          ],
        ),
        AnimatedSize(
          duration: Motion.settle,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: selected == null
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: customController,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            isDense: true,
                            suffixText: 'MB',
                            suffixStyle: TextStyle(color: Paper.muted),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Paper.line),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Paper.text),
                            ),
                          ),
                          onChanged: (_) => onChanged(null),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return _Pressable(
      enabled: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Paper.text : Paper.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Paper.text : Paper.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: text.bodyMedium?.copyWith(
                color: selected ? Colors.white : Paper.text,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (detail != null) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                detail!,
                style: text.bodySmall?.copyWith(
                  color: selected ? Colors.white60 : Paper.faint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The one button. Black when ready, quiet when not.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return _Pressable(
      enabled: enabled,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: Motion.quick,
        height: 56,
        decoration: BoxDecoration(
          color: enabled ? Paper.text : Paper.fill,
          borderRadius: _r,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              style: text.titleMedium?.copyWith(
                color: enabled ? Colors.white : Paper.faint,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (icon != null) ...<Widget>[
              const SizedBox(width: 6),
              Icon(icon, size: 18, color: enabled ? Colors.white : Paper.faint),
            ],
          ],
        ),
      ),
    );
  }
}

/// The same button, filling from the left as the encode runs.
class ProgressButton extends StatelessWidget {
  const ProgressButton({super.key, required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: _r,
      child: SizedBox(
        height: 56,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ColoredBox(color: Color(0xFF2A2A27)),
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: Motion.quick,
                widthFactor: progress.clamp(0.02, 1),
                child: const ColoredBox(color: Paper.text),
              ),
            ),
            Center(
              child: Text(
                '$label  ${(progress * 100).round()}%',
                style: text.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuietButton extends StatelessWidget {
  const QuietButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      enabled: true,
      onTap: onPressed,
      child: SizedBox(
        height: 40,
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Paper.muted),
          ),
        ),
      ),
    );
  }
}

/// The result: the new size, big, with the old size beside it.
class ResultPanel extends StatelessWidget {
  const ResultPanel({super.key, required this.outcome});

  final FitOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String headline = outcome.alreadyFit
        ? 'Already fits'
        : outcome.fits
            ? 'Fits'
            : 'As small as it gets';
    final String note = outcome.alreadyFit
        ? 'Under ${formatMb(outcome.limitBytes)} as it is. Nothing to do.'
        : outcome.fits
            ? 'Under ${formatMb(outcome.limitBytes)}. Ready to send.'
            : 'Could not get under ${formatMb(outcome.limitBytes)} and stay watchable.';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Paper.surface,
        borderRadius: _r,
        border: Border.all(color: Paper.line),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      formatMb(outcome.bytes),
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                      ),
                    ),
                    if (!outcome.alreadyFit) ...<Widget>[
                      const SizedBox(width: 10),
                      Text(
                        'was ${formatMb(outcome.inputBytes)}',
                        style: text.bodyMedium?.copyWith(
                          color: Paper.faint,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Paper.faint,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(note, style: text.bodySmall?.copyWith(color: Paper.muted, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: outcome.fits ? const Color(0xFFE8F3EC) : Paper.fill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              headline,
              style: text.bodySmall?.copyWith(
                color: outcome.fits ? Paper.good : Paper.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tap feedback by a small scale, no ink splash.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.enabled, required this.onTap, required this.child});

  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _down = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          scale: _down ? 0.985 : 1,
          child: widget.child,
        ),
      ),
    );
  }
}
