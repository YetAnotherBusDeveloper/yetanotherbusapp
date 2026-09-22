import 'package:flutter/material.dart';

/// Short, non-overshooting transitions. No decorative translation or bobbing.
abstract final class AppMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 220);
  static const curve = Curves.easeInOutCubic;

  static Duration duration(BuildContext context, [Duration value = standard]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;

  static const pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: AppFadePageTransitionsBuilder(),
      TargetPlatform.iOS: AppFadePageTransitionsBuilder(),
      TargetPlatform.macOS: AppFadePageTransitionsBuilder(),
      TargetPlatform.windows: AppFadePageTransitionsBuilder(),
      TargetPlatform.linux: AppFadePageTransitionsBuilder(),
      TargetPlatform.fuchsia: AppFadePageTransitionsBuilder(),
    },
  );
}

class AppFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const AppFadePageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.standard;

  @override
  Duration get reverseTransitionDuration => AppMotion.quick;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: AppMotion.curve)),
      child: child,
    );
  }
}
