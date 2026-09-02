import 'package:flutter/material.dart';

class PulseMotionPolicy {
  static bool userReducedMotion = false;

  static Duration duration(BuildContext context, Duration normal) =>
      (MediaQuery.of(context).disableAnimations || userReducedMotion) ? Duration.zero : normal;
}
