import 'dart:math' as math;
import 'package:flutter/material.dart';

extension AdaptiveDataWidget on Widget {
  Widget withAdaptivePageViewport({double minHeight = 760}) =>
      AdaptivePageViewport(minHeight: minHeight, child: this);
  Widget withAdaptiveTable() => AdaptiveTable(child: this);
}

/// Stack form fields on phones and use two columns on narrow tablets.
class AdaptiveRow extends StatelessWidget {
  const AdaptiveRow({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 760) {
        return Row(
          crossAxisAlignment: crossAxisAlignment,
          mainAxisAlignment: mainAxisAlignment,
          children: children,
        );
      }
      final columns = constraints.maxWidth >= 600 ? 2 : 1;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            if (child is Expanded)
              SizedBox(width: width, child: child.child)
            else if (child is! SizedBox || child.child != null)
              child,
        ],
      );
    },
  );
}

/// Keep data columns legible with horizontal scrolling on smaller displays.
class AdaptiveTable extends StatelessWidget {
  const AdaptiveTable({super.key, required this.child, this.minWidth = 1000});
  final Widget child;
  final double minWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= minWidth) return child;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: minWidth,
          height: constraints.maxHeight,
          child: child,
        ),
      );
    },
  );
}

/// Let stacked filters scroll instead of overflowing a short screen/keyboard.
class AdaptivePageViewport extends StatelessWidget {
  const AdaptivePageViewport({
    super.key,
    required this.child,
    this.minHeight = 760,
  });
  final Widget child;
  final double minHeight;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxHeight >= minHeight && constraints.maxWidth >= 760)
        return child;
      return SingleChildScrollView(
        child: SizedBox(
          width: constraints.maxWidth,
          height: math.max(minHeight, constraints.maxHeight),
          child: child,
        ),
      );
    },
  );
}
