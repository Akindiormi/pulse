import 'package:flutter/material.dart';

class PulseMotionPolicy {
  static bool userReducedMotion = false;

  static bool isReducedMotion(BuildContext context) =>
      MediaQuery.of(context).disableAnimations || userReducedMotion;

  static Duration duration(BuildContext context, Duration normal) =>
      isReducedMotion(context) ? Duration.zero : normal;

  static Curve curve(BuildContext context, {Curve normal = Curves.easeOutCubic}) =>
      isReducedMotion(context) ? Curves.linear : normal;

  static Duration microDuration(BuildContext context) =>
      duration(context, const Duration(milliseconds: 120));

  static Duration transitionDuration(BuildContext context) =>
      duration(context, const Duration(milliseconds: 260));
}
