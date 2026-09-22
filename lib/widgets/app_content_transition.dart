import 'package:flutter/material.dart';

import '../core/app_motion.dart';

/// Fades in a changed state without retaining an outgoing list/platform view.
/// Use a semantic state (loading/error/content or selected panel), not a timer
/// or data revision, so background refreshes do not replay the whole page.
class AppContentTransition extends StatefulWidget {
  const AppContentTransition({
    required this.state,
    required this.child,
    super.key,
  });

  final Object? state;
  final Widget child;

  @override
  State<AppContentTransition> createState() => _AppContentTransitionState();
}

class _AppContentTransitionState extends State<AppContentTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: 1,
  );
  late final Animation<double> _opacity = _controller.drive(
    CurveTween(curve: AppMotion.curve),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(AppContentTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state == widget.state) return;
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}
