import 'package:flutter/material.dart';
import '../../../core/theme/color_palette.dart';

class DraggableJoystick extends StatefulWidget {
  final bool enabled;
  final Function(double dx, double dy)? onPositionChanged;
  final double size;
  final double innerSize;

  const DraggableJoystick({
    super.key,
    this.enabled = true,
    this.onPositionChanged,
    this.size = 220,
    this.innerSize = 90,
  });

  @override
  State<DraggableJoystick> createState() => _DraggableJoystickState();
}

class _DraggableJoystickState extends State<DraggableJoystick> {
  Offset _position = Offset.zero;

  void _updatePosition(Offset localPosition) {
    if (!widget.enabled) return;

    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPosition - center;
    final distance = delta.distance;
    final maxDistance = (widget.size - widget.innerSize) / 2;

    setState(() {
      if (distance <= maxDistance) {
        _position = delta;
      } else {
        // Constrain to circle boundary
        _position = delta * (maxDistance / distance);
      }
    });

    // Normalize the position to -1 to 1 range
    final normalizedX = _position.dx / maxDistance;
    final normalizedY = _position.dy / maxDistance;
    
    widget.onPositionChanged?.call(normalizedX, normalizedY);
  }

  void _resetPosition() {
    setState(() {
      _position = Offset.zero;
    });
    widget.onPositionChanged?.call(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: widget.enabled ? (details) {
        _updatePosition(details.localPosition);
      } : null,
      onPanUpdate: widget.enabled ? (details) {
        _updatePosition(details.localPosition);
      } : null,
      onPanEnd: widget.enabled ? (details) {
        _resetPosition();
      } : null,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.enabled ? AppColors.primary : AppColors.border,
            width: 3,
          ),
          color: widget.enabled
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.background,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Direction indicators (optional)
            if (widget.enabled) ...[
              // Top indicator
              Positioned(
                top: 10,
                child: Container(
                  width: 4,
                  height: 15,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Bottom indicator
              Positioned(
                bottom: 10,
                child: Container(
                  width: 4,
                  height: 15,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Left indicator
              Positioned(
                left: 10,
                child: Container(
                  width: 15,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Right indicator
              Positioned(
                right: 10,
                child: Container(
                  width: 15,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
            // Draggable inner circle
            Transform.translate(
              offset: _position,
              child: Container(
                width: widget.innerSize,
                height: widget.innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.enabled ? AppColors.primary : AppColors.border,
                  boxShadow: [
                    if (widget.enabled)
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Icon(
                  Icons.directions_boat,
                  color: Colors.white,
                  size: 45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
