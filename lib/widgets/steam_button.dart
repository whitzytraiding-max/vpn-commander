import 'package:flutter/material.dart';
import '../theme/colors.dart';

class SteamButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final bool danger;
  final bool small;

  const SteamButton({
    Key? key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color,
    this.danger = false,
    this.small = false,
  }) : super(key: key);

  @override
  State<SteamButton> createState() => _SteamButtonState();
}

class _SteamButtonState extends State<SteamButton> {
  bool _pressed = false;

  Color get _baseColor =>
      widget.danger ? kRedDim : (widget.color ?? kBrassDark);
  Color get _topColor =>
      widget.danger ? kRedOn : (widget.color ?? kBrass);

  @override
  Widget build(BuildContext context) {
    final pad = widget.small
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 12);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: pad,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _pressed
                ? [_baseColor, _baseColor]
                : [_topColor.withOpacity(0.9), _baseColor],
          ),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: _pressed ? _baseColor : _topColor, width: 1),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: _topColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: widget.small ? 14 : 18,
                color: kParchment,
              ),
              SizedBox(width: widget.small ? 6 : 8),
            ],
            Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                color: kParchment,
                fontSize: widget.small ? 10 : 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
