import 'package:flutter/material.dart';

class PulseMotionPolicy {
  static Duration duration(BuildContext context, Duration normal) => MediaQuery.of(context).disableAnimations ? Duration.zero : normal;
}
