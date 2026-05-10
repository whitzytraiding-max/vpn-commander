import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class StatusGauge extends StatelessWidget {
  final bool online;
  final int? pingMs;
  final String label;
  final double size;

  const StatusGauge({
    Key? key,
    required this.online,
    this.pingMs,
    required this.label,
    this.size = 120,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugePainter(online: online, pingMs: pingMs),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    online ? Icons.wifi : Icons.wifi_off,
                    color: online ? kGreenOn : kRedOn,
                    size: size * 0.22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    online ? 'ONLINE' : 'OFFLINE',
                    style: TextStyle(
                      color: online ? kGreenOn : kRedOn,
                      fontSize: size * 0.1,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  if (pingMs != null)
                    Text(
                      '${pingMs}ms',
                      style: TextStyle(
                        color: kParchDim,
                        fontSize: size * 0.09,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: kBrassLight,
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final bool online;
  final int? pingMs;

  _GaugePainter({required this.online, this.pingMs});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 6;

    final bgPaint = Paint()
      ..color = kBgDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = online ? kGreenOn : kRedDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final borderPaint = Paint()
      ..color = kBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Outer decorative ring
    canvas.drawCircle(Offset(cx, cy), r + 8, borderPaint);
    canvas.drawCircle(Offset(cx, cy), r - 14, borderPaint);

    // Arc background
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Arc foreground
    final sweep = online ? math.pi * 1.5 : math.pi * 0.15;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi * 0.75,
      sweep,
      false,
      fgPaint..color = online ? kGreenOn : kRedOn,
    );

    // Tick marks
    final tickPaint = Paint()
      ..color = kBorder
      ..strokeWidth = 1;
    for (int i = 0; i <= 10; i++) {
      final angle = math.pi * 0.75 + (math.pi * 1.5 * i / 10);
      final inner = r - 20;
      final outer = r - 10;
      canvas.drawLine(
        Offset(cx + inner * math.cos(angle), cy + inner * math.sin(angle)),
        Offset(cx + outer * math.cos(angle), cy + outer * math.sin(angle)),
        tickPaint,
      );
    }

    // Glow when online
    if (online) {
      final glowPaint = Paint()
        ..color = kGreenOn.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset(cx, cy), r - 14, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.online != online || old.pingMs != pingMs;
}

class GearSpinner extends StatefulWidget {
  final double size;
  final Color? color;

  const GearSpinner({Key? key, this.size = 32, this.color}) : super(key: key);

  @override
  State<GearSpinner> createState() => _GearSpinnerState();
}

class _GearSpinnerState extends State<GearSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _GearPainter(
          angle: _ctrl.value * 2 * math.pi,
          color: widget.color ?? kBrass,
        ),
      ),
    );
  }
}

class _GearPainter extends CustomPainter {
  final double angle;
  final Color color;

  _GearPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);
    final teeth = 8;
    final innerR = r * 0.55;
    final outerR = r * 0.85;
    final holeR = r * 0.25;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    final path = Path();
    for (int i = 0; i < teeth; i++) {
      final a1 = (2 * math.pi * i / teeth) - (math.pi / teeth / 2);
      final a2 = a1 + (math.pi / teeth / 2);
      final a3 = a2 + (math.pi / teeth / 2);
      final a4 = a3 + (math.pi / teeth / 2);

      if (i == 0) {
        path.moveTo(innerR * math.cos(a1), innerR * math.sin(a1));
      } else {
        path.lineTo(innerR * math.cos(a1), innerR * math.sin(a1));
      }
      path.lineTo(outerR * math.cos(a1), outerR * math.sin(a1));
      path.lineTo(outerR * math.cos(a2), outerR * math.sin(a2));
      path.lineTo(innerR * math.cos(a3), innerR * math.sin(a3));
      path.lineTo(outerR * math.cos(a3), outerR * math.sin(a3));
      path.lineTo(outerR * math.cos(a4), outerR * math.sin(a4));
      path.lineTo(innerR * math.cos(a4), innerR * math.sin(a4));
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset.zero, holeR, Paint()..color = kBgDark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GearPainter old) => old.angle != angle;
}
