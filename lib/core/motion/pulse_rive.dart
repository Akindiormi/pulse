import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import 'pulse_motion_attachment.dart';
import 'pulse_motion_policy.dart';

/// Presentation-only adapter around the Rive runtime. Business services never
/// receive this controller.
class PulseRiveMotionController {
  PulseRiveMotionController(this._controller);
  final rive.RiveWidgetController _controller;

  void pause() {
    try { _controller.active = false; } catch (_) {}
  }

  void resume() {
    try { _controller.active = true; } catch (_) {}
  }

  bool trigger(String name) {
    if (name.trim().isEmpty) return false;
    try {
      final input = _controller.stateMachine.trigger(name);
      if (input == null) return false;
      input.fire();
      return true;
    } catch (_) { return false; }
  }

  bool setBoolean(String name, bool value) {
    if (name.trim().isEmpty) return false;
    try {
      final input = _controller.stateMachine.boolean(name);
      if (input == null) return false;
      input.value = value;
      return true;
    } catch (_) { return false; }
  }

  bool setNumber(String name, double value) {
    if (name.trim().isEmpty) return false;
    try {
      final input = _controller.stateMachine.number(name);
      if (input == null) return false;
      input.value = value;
      return true;
    } catch (_) { return false; }
  }
}

/// Optional Rive visual. Missing assets, machines, or inputs fall back to the
/// normal Pulse UI so animation can never break product functionality.
class PulseRiveMotionHost extends StatefulWidget {
  const PulseRiveMotionHost({
    super.key,
    required this.assetPath,
    required this.intent,
    required this.state,
    required this.fallback,
    this.artboardName,
    this.stateMachineName,
    this.triggerForState = const <String, String>{},
    this.booleanInputs = const <String, bool>{},
    this.numberInputs = const <String, double>{},
    this.fit = rive.Fit.contain,
    this.alignment = Alignment.center,
    this.semanticLabel,
  });

  final String assetPath;
  final PulseMotionIntent intent;
  final Enum state;
  final Widget fallback;
  final String? artboardName;
  final String? stateMachineName;
  final Map<String, String> triggerForState;
  final Map<String, bool> booleanInputs;
  final Map<String, double> numberInputs;
  final rive.Fit fit;
  final Alignment alignment;
  final String? semanticLabel;

  @override
  State<PulseRiveMotionHost> createState() => _PulseRiveMotionHostState();
}

class _PulseRiveMotionHostState extends State<PulseRiveMotionHost> {
  late rive.FileLoader _loader;
  PulseRiveMotionController? _controller;

  @override
  void initState() {
    super.initState();
    _loader = rive.FileLoader.fromAsset(widget.assetPath, riveFactory: rive.Factory.rive);
  }

  String _stateName(Enum state) => state.toString().split('.').last;

  void _applyInputs() {
    final controller = _controller;
    if (controller == null || PulseMotionPolicy.isReducedMotion(context)) return;
    for (final entry in widget.booleanInputs.entries) {
      controller.setBoolean(entry.key, entry.value);
    }
    for (final entry in widget.numberInputs.entries) {
      controller.setNumber(entry.key, entry.value);
    }
    final trigger = widget.triggerForState[_stateName(widget.state)];
    if (trigger != null) controller.trigger(trigger);
  }

  @override
  void didUpdateWidget(covariant PulseRiveMotionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _controller = null;
      _loader.dispose();
      _loader = rive.FileLoader.fromAsset(widget.assetPath, riveFactory: rive.Factory.rive);
    }
    if (oldWidget.state != widget.state ||
        oldWidget.booleanInputs != widget.booleanInputs ||
        oldWidget.numberInputs != widget.numberInputs ||
        oldWidget.triggerForState != widget.triggerForState) {
      _applyInputs();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (PulseMotionPolicy.isReducedMotion(context) || widget.assetPath.trim().isEmpty) {
      return widget.fallback;
    }
    final visual = rive.RiveWidgetBuilder(
      fileLoader: _loader,
      artboardSelector: widget.artboardName == null
          ? const rive.ArtboardDefault()
          : rive.ArtboardSelector.byName(widget.artboardName!),
      stateMachineSelector: widget.stateMachineName == null
          ? const rive.StateMachineDefault()
          : rive.StateMachineSelector.byName(widget.stateMachineName!),
      onLoaded: (loaded) {
        _controller = PulseRiveMotionController(loaded.controller);
        _applyInputs();
      },
      builder: (context, rive.RiveState state) => switch (state) {
        rive.RiveLoading() => widget.fallback,
        rive.RiveLoaded() => rive.RiveWidget(
            controller: state.controller,
            fit: widget.fit,
            alignment: widget.alignment,
          ),
        rive.RiveFailed() => widget.fallback,
      },
    );
    final label = widget.semanticLabel;
    return label == null || label.trim().isEmpty ? visual : Semantics(label: label, child: visual);
  }

  @override
  void dispose() {
    _controller?.pause();
    _loader.dispose();
    _controller = null;
    super.dispose();
  }
}

/// Connects an existing PulseMotionAttachment payload to the Rive host.
class PulseRiveAttachment extends StatelessWidget {
  const PulseRiveAttachment({
    super.key,
    required this.data,
    required this.assetPath,
    required this.fallback,
    this.artboardName,
    this.stateMachineName,
    this.triggerForState = const <String, String>{},
    this.booleanInputs = const <String, bool>{},
    this.numberInputs = const <String, double>{},
    this.fit = rive.Fit.contain,
    this.alignment = Alignment.center,
    this.semanticLabel,
  });

  final PulseMotionAttachmentData data;
  final String assetPath;
  final Widget fallback;
  final String? artboardName;
  final String? stateMachineName;
  final Map<String, String> triggerForState;
  final Map<String, bool> booleanInputs;
  final Map<String, double> numberInputs;
  final rive.Fit fit;
  final Alignment alignment;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => PulseRiveMotionHost(
        assetPath: assetPath,
        intent: data.intent,
        state: data.state,
        fallback: fallback,
        artboardName: artboardName,
        stateMachineName: stateMachineName,
        triggerForState: triggerForState,
        booleanInputs: booleanInputs,
        numberInputs: numberInputs,
        fit: fit,
        alignment: alignment,
        semanticLabel: semanticLabel,
      );
}
