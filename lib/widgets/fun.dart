import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../config/theme.dart';
import 'motion.dart';

// Mihna's sense of humour: one short, kind line on an empty list, a finished list and the not-found page,
// written separately in Arabic and English. Never on an error, never at the person's expense.

/// A number for this run of the app, so the line picked holds while pages redraw and changes next time.
final int _visit = DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// One of a few (already translated) lines for the same moment, so the joke does not go stale.
String funLine(List<String> lines) => lines[_visit % lines.length];

/// A wheel nut in the brand's colours, the one ornament of the not-found page: a hexagon with a threaded hole and an
/// amber washer.
class WheelNut extends StatelessWidget {
  const WheelNut({this.size = 72, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _NutPainter(scheme.primary, scheme.secondary, scheme.surface)),
      ),
    );
  }
}

class _NutPainter extends CustomPainter {
  _NutPainter(this.body, this.washer, this.hole);

  final Color body;
  final Color washer;
  final Color hole;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.94;
      i == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
    }
    hex.close();
    canvas
      ..drawPath(
        hex,
        Paint()
          ..color = body
          ..style = PaintingStyle.fill
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(c, r * 0.5, Paint()..color = washer)
      ..drawCircle(c, r * 0.3, Paint()..color = hole);
    final thread = Paint()
      ..color = body.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.04;
    canvas.drawCircle(c, r * 0.22, thread);
  }

  @override
  bool shouldRepaint(_NutPainter old) => old.body != body || old.washer != washer || old.hole != hole;
}

/// The not-found page's picture: a wheel nut, lost from the page, rolls in from the end side and settles with a wobble.
/// Tapped, it hops.
class LostNut extends StatefulWidget {
  const LostNut({this.size = 80, this.label = 'The lost nut', super.key});

  final double size;
  final String label;

  @override
  State<LostNut> createState() => _LostNutState();
}

class _LostNutState extends State<LostNut> with TickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _hop = AnimationController(vsync: this, duration: AppTheme.slow + AppTheme.fast);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _roll.value = 1;
    } else if (_roll.status == AnimationStatus.dismissed) {
      unawaited(_roll.forward());
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final from = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return Semantics(
      button: true,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (!reduceMotion(context)) unawaited(_hop.forward(from: 0));
            },
            child: SizedBox(
              width: size * 2.2,
              height: size * 1.5,
              child: AnimatedBuilder(
                animation: Listenable.merge([_roll, _hop]),
                builder: (context, _) {
                  final t = _roll.value;
                  final r = AppTheme.enter.transform(t);
                  final wobble = math.sin(t * math.pi * 5) * (1 - t) * 0.18;
                  final hop = math.sin(_hop.value * math.pi) * size * 0.4;
                  final x = from * size * 1.5 * (1 - r);
                  final turns = -from * (1 - r) * math.pi * 3 + wobble + _hop.value * math.pi * 2 * -from;
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Transform.translate(
                        offset: Offset(x, 0),
                        child: Container(
                          width: size * (0.8 - 0.3 * hop / size),
                          height: size * 0.1,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(size),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: size * 0.05 + hop,
                        child: Transform.translate(
                          offset: Offset(x, 0),
                          child: Transform.rotate(
                            angle: turns,
                            child: WheelNut(size: size),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
