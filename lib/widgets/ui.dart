import 'dart:math' as math;

import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFFF2F2F4);
  static const card = Colors.white;
  static const ink = Color(0xFF0B0B0C);
  static const muted = Color(0xFF8A8A93);
  static const line = Color(0xFFE6E6EA);
  static const red = Color(0xFFE5252A);
  static const green = Color(0xFF16A34A);
  static const dark = Color(0xFF000000);
}

BoxDecoration cardDeco({Color color = C.card, double r = 28}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(r),
  boxShadow: const [
    BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8)),
  ],
);

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) =>
      Container(padding: padding, decoration: cardDeco(), child: child);
}

/// Round white icon button like the back / action buttons in the references.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.dark = false,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final bool dark;
  final String? tooltip;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? '',
    child: Material(
      color: dark ? const Color(0xFF1B1B1D) : Colors.white,
      shape: const CircleBorder(),
      elevation: dark ? 0 : 1,
      shadowColor: const Color(0x22000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            size: 22,
            color: onTap == null ? C.muted : (dark ? Colors.white : C.ink),
          ),
        ),
      ),
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.ok, this.compact = false});
  final bool? ok;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final color = ok == null ? C.muted : (ok! ? C.green : C.red);
    final label = ok == null
        ? 'NO READING'
        : (ok! ? 'IN RANGE' : 'OUT OF RANGE');
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ dot-matrix

const _font = <String, List<String>>{
  '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
  '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
  '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  '3': ['11110', '00001', '00001', '01110', '00001', '00001', '11110'],
  '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
  '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
  '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
  '-': ['00000', '00000', '00000', '11111', '00000', '00000', '00000'],
  '.': ['0', '0', '0', '0', '0', '0', '1'],
};

/// Dot-matrix number (as in the reference ECG card).
class DotNumber extends StatelessWidget {
  const DotNumber(this.text, {super.key, this.color = C.ink, this.dot = 5});
  final String text;
  final Color color;
  final double dot; // dot pitch

  @override
  Widget build(BuildContext context) {
    final glyphs = text.split('').map((c) => _font[c] ?? _font['-']!).toList();
    final width =
        glyphs.fold<double>(0, (w, g) => w + g.first.length * dot + dot) - dot;
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: CustomPaint(
            key: ValueKey('$text$color'),
            size: Size(width, 7 * dot),
            painter: _DotPainter(glyphs, color, dot),
          ),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.glyphs, this.color, this.dot);
  final List<List<String>> glyphs;
  final Color color;
  final double dot;
  @override
  void paint(Canvas canvas, Size size) {
    final on = Paint()..color = color;
    final off = Paint()..color = color.withValues(alpha: .10);
    double x = 0;
    for (final g in glyphs) {
      final cols = g.first.length;
      for (int r = 0; r < g.length; r++) {
        for (int c = 0; c < cols; c++) {
          canvas.drawCircle(
            Offset(x + c * dot + dot / 2, r * dot + dot / 2),
            dot * .38,
            g[r][c] == '1' ? on : off,
          );
        }
      }
      x += cols * dot + dot;
    }
  }

  @override
  bool shouldRepaint(_DotPainter o) => o.glyphs != glyphs || o.color != color;
}

// ------------------------------------------------------------ particle ring

/// Animated red dotted ring from the "Record ECG" reference.
class DotRing extends StatefulWidget {
  const DotRing({super.key, this.size = 300, this.intensity = 1});
  final double size;
  final double intensity;
  @override
  State<DotRing> createState() => _DotRingState();
}

class _DotRingState extends State<DotRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _RingPainter(_c.value, widget.intensity),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.k);
  final double t, k;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.width * .36;
    final rnd = math.Random(7);
    final paint = Paint();
    const n = 700;
    for (int i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi;
      final layer = rnd.nextDouble();
      final wave =
          math.sin(a * 5 + t * 2 * math.pi) * 7 * k +
          math.sin(a * 9 - t * 4 * math.pi) * 4 * k;
      final spread = (rnd.nextDouble() - .5) * 26 * (.4 + layer);
      final r = base + wave + spread + math.sin(t * 2 * math.pi) * 4 * k;
      final alpha = (1 - (spread.abs() / 14)).clamp(.12, 1.0);
      paint.color = const Color(0xFFE5252A).withValues(alpha: alpha * .85);
      canvas.drawCircle(
        c + Offset(math.cos(a) * r, math.sin(a) * r),
        .6 + layer * 1.3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.t != t;
}
