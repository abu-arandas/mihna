import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../config/theme.dart';

// Mihna's motion: calm, quick and done once. Every number comes from [AppTheme]'s motion tokens, and with
// reduce motion on (MediaQuery.disableAnimations) every widget here shows its end state at once.

/// Whether the person asked for less motion.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fades its child in as it rises a little into place, once, after [delay].
class Appear extends StatelessWidget {
  const Appear({required this.child, this.delay = Duration.zero, super.key});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return _Delayed(
      delay: delay,
      duration: AppTheme.slow,
      curve: AppTheme.enter,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, AppTheme.rise * (1 - t)), child: child),
      ),
    );
  }
}

/// Plays [builder] from 0 to 1 once, [delay] after it is first built.
class _Delayed extends StatefulWidget {
  const _Delayed({required this.delay, required this.duration, required this.curve, required this.builder, required this.child});

  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Widget Function(BuildContext context, double t, Widget child) builder;
  final Widget child;

  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: widget.curve);
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      unawaited(_c.forward());
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) unawaited(_c.forward());
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _t, child: widget.child, builder: (context, child) => widget.builder(context, _t.value, child!));
}

/// Gives a little under a press, the way a button does under a thumb.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, super.key});

  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(scale: _down && !reduceMotion(context) ? 0.97 : 1, duration: AppTheme.fast, curve: AppTheme.curve, child: widget.child),
  );
}

/// Pops its child (a little past its size and back) when [value] changes, if [when] agrees.
class PopOnChange extends StatefulWidget {
  const PopOnChange({required this.value, required this.child, this.when, super.key});

  final Object? value;
  final Widget child;
  final bool Function(Object? before, Object? now)? when;

  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppTheme.slow);

  @override
  void didUpdateWidget(PopOnChange old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && (widget.when?.call(old.value, widget.value) ?? true) && !reduceMotion(context)) {
      unawaited(_c.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    // Up to 1.25 and back, on a sine so it starts and ends at rest.
    builder: (context, child) => Transform.scale(scale: 1 + 0.25 * math.sin(_c.value * math.pi), child: child),
  );
}

/// Draws its child in from the start edge (the right in Arabic), once: the stitch line sewing itself.
class SewIn extends StatelessWidget {
  const SewIn({required this.child, this.delay = Duration.zero, super.key});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return _Delayed(
      delay: delay,
      duration: AppTheme.sew,
      curve: AppTheme.curve,
      child: child,
      builder: (context, t, child) => ClipRect(
        child: Align(alignment: AlignmentDirectional.centerStart, widthFactor: t.clamp(0.0, 1.0), child: child),
      ),
    );
  }
}

/// Grows from nothing to a little past its size and back, once: for a small, happy arrival.
class PopIn extends StatelessWidget {
  const PopIn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppTheme.slow,
      curve: AppTheme.pop,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: child,
    );
  }
}
