import 'package:flutter/material.dart';
import '../theme/color_palette.dart';

class PageWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool scrollable;
  final Color? backgroundColor;

  const PageWrapper({
    super.key,
    required this.child,
    this.padding,
    this.scrollable = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPadding = padding ?? const EdgeInsets.all(16.0);
    final bgColor = backgroundColor ?? AppColors.background;

    if (scrollable) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: bgColor,
        child: SingleChildScrollView(
          padding: defaultPadding,
          child: child,
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bgColor,
      padding: defaultPadding,
      child: child,
    );
  }
}
