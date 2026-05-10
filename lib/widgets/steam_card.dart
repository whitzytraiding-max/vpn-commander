import 'package:flutter/material.dart';
import '../theme/colors.dart';

class SteamCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final double borderWidth;
  final double radius;

  const SteamCard({
    Key? key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderWidth = 1.5,
    this.radius = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RivetedPainter(
        borderColor: borderColor ?? kBorder,
        borderWidth: borderWidth,
        radius: radius,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: kBgMed,
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _RivetedPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;
  final double radius;

  _RivetedPainter({
    required this.borderColor,
    required this.borderWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, borderPaint);

    // Draw rivets at corners
    _drawRivet(canvas, const Offset(10, 10));
    _drawRivet(canvas, Offset(size.width - 10, 10));
    _drawRivet(canvas, Offset(10, size.height - 10));
    _drawRivet(canvas, Offset(size.width - 10, size.height - 10));
  }

  void _drawRivet(Canvas canvas, Offset center) {
    final outer = Paint()
      ..color = kRivet
      ..style = PaintingStyle.fill;
    final inner = Paint()
      ..color = kBrassDark
      ..style = PaintingStyle.fill;
    final shine = Paint()
      ..color = kBrassLight.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4, outer);
    canvas.drawCircle(center, 2.5, inner);
    canvas.drawCircle(center - const Offset(0.8, 0.8), 1, shine);
  }

  @override
  bool shouldRepaint(_RivetedPainter old) =>
      old.borderColor != borderColor || old.borderWidth != borderWidth;
}

class SteamLabel extends StatelessWidget {
  final String text;
  final double? fontSize;
  final Color? color;

  const SteamLabel(this.text, {Key? key, this.fontSize, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: fontSize ?? 10,
        color: color ?? kBrassLight,
        letterSpacing: 2.5,
      ),
    );
  }
}
