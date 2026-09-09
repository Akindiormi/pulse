import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Icon design tokens for Pulse.
///
/// Rules (do not deviate — see ui-ux-pro-max icon guidelines):
/// 1. No emoji as structural/navigational icons, ever.
/// 2. One icon family only (Phosphor). No mixing with Material/Cupertino
///    glyphs in the same view.
/// 3. One weight per hierarchy level: [PulseIconWeight.inactive] for
///    unselected/idle states, [PulseIconWeight.active] for
///    selected/emphasized states. Never mix light and fill in the same row.
/// 4. Sizes come from [PulseIconSize] only — never an arbitrary literal.
class PulseIconSize {
  PulseIconSize._();
  static const sm = 18.0;
  static const md = 24.0;
  static const lg = 28.0;
  static const xl = 40.0;
}

class PulseIconWeight {
  PulseIconWeight._();
  static const inactive = PhosphorIconsStyle.light;
  static const active = PhosphorIconsStyle.fill;
  static const emphasis = PhosphorIconsStyle.duotone;
}

/// Semantic icon map — reference these, not raw Phosphor constants, so a
/// glyph swap only ever happens in one place.
class PulseIcons {
  PulseIcons._();

  // Navigation (shell)
  static IconData home(bool active) =>
      active ? PhosphorIcons.house(PulseIconWeight.active) : PhosphorIcons.house(PulseIconWeight.inactive);
  static IconData tasks(bool active) =>
      active ? PhosphorIcons.checkSquare(PulseIconWeight.active) : PhosphorIcons.checkSquare(PulseIconWeight.inactive);
  static IconData calendar(bool active) =>
      active ? PhosphorIcons.calendarBlank(PulseIconWeight.active) : PhosphorIcons.calendarBlank(PulseIconWeight.inactive);
  static IconData progress(bool active) =>
      active ? PhosphorIcons.chartLineUp(PulseIconWeight.active) : PhosphorIcons.chartLineUp(PulseIconWeight.inactive);
  static IconData profile(bool active) =>
      active ? PhosphorIcons.user(PulseIconWeight.active) : PhosphorIcons.user(PulseIconWeight.inactive);

  // Core actions
  static IconData add = PhosphorIcons.plus(PulseIconWeight.active);
  static IconData focus = PhosphorIcons.target(PulseIconWeight.inactive);
  static IconData notification = PhosphorIcons.bell(PulseIconWeight.inactive);
  static IconData notificationActive = PhosphorIcons.bell(PulseIconWeight.emphasis);
  static IconData settings = PhosphorIcons.gearSix(PulseIconWeight.inactive);
  static IconData search = PhosphorIcons.magnifyingGlass(PulseIconWeight.inactive);
  static IconData close = PhosphorIcons.x(PulseIconWeight.inactive);
  static IconData back = PhosphorIcons.caretLeft(PulseIconWeight.inactive);
  static IconData chevronRight = PhosphorIcons.caretRight(PulseIconWeight.inactive);
  static IconData check = PhosphorIcons.check(PulseIconWeight.active);
  static IconData edit = PhosphorIcons.pencilSimple(PulseIconWeight.inactive);
  static IconData delete = PhosphorIcons.trash(PulseIconWeight.inactive);
  static IconData share = PhosphorIcons.shareNetwork(PulseIconWeight.inactive);

  // Streak / gamification (emphasis weight — these are reward moments)
  static IconData streak = PhosphorIcons.flame(PulseIconWeight.emphasis);
  static IconData achievement = PhosphorIcons.trophy(PulseIconWeight.emphasis);
  static IconData milestone = PhosphorIcons.flagBanner(PulseIconWeight.emphasis);
  static IconData streakFreeze = PhosphorIcons.snowflake(PulseIconWeight.inactive);

  // Status / feedback
  static IconData success = PhosphorIcons.checkCircle(PulseIconWeight.active);
  static IconData error = PhosphorIcons.warningCircle(PulseIconWeight.active);
  static IconData info = PhosphorIcons.info(PulseIconWeight.inactive);
  static IconData empty = PhosphorIcons.trayEmpty(PulseIconWeight.inactive);
}
