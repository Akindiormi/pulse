# Pulse Design System

Ported from nextel-connect's premium glass aesthetic, adapted to Pulse's
existing token architecture. Source of truth: `lib/core/design/pulse_tokens.dart`,
`lib/core/design/pulse_icons.dart`, `lib/core/theme/app_theme.dart`.

## Color

Brand: deep green (`#0D3D2B`) as the anchor, emerald accent (`#2E8B57`) as
primary interactive color, gold (`#D4A017`) reserved for premium/reward
moments only (achievements, milestones) — never for standard UI chrome.

Never hardcode a hex value in a screen or widget file. Always reference
`PulseColors.*` or the theme's `ColorScheme`/`PulseThemeExtension`. This is
what let the entire app-wide rebrand happen by editing 3 files instead of 40.

Glass surfaces (`PulseColors.glassCard*`) are for elevated content — cards,
sheets, modals. Solid `surface`/`elevated` tokens are for base layers behind
the glass. Don't stack more than 2 levels of glass transparency or text
legibility drops below the 4.5:1 contrast floor.

## Typography

Plus Jakarta Sans throughout, via `AppTypography`. Roles: `display` (hero
numbers/streak counts), `headline`, `title`, `body`, `bodySmall`, `label`
(buttons/tags, uppercase-adjacent tracking), `metadata` (timestamps,
secondary info), `number`/`numberSmall` (tabular figures for stats — always
use these for anything counting up, never `body`).

Body text never below 15px. Never gray-on-gray — secondary text uses
`textSecondary`/`textMuted` tokens, which are contrast-checked against both
surface tones.

## Spacing & Radius

`PulseSpace` (4→64) and `PulseRadius` (12 small / 14 input / 16 button / 24
card) — no arbitrary padding literals. 8pt rhythm throughout.

## Icons — Phosphor, no exceptions

- One family only: Phosphor. Never emoji, never mixed with Cupertino/Material
  glyphs in the same screen.
- Reference `PulseIcons.*` semantic getters, not raw `PhosphorIcons.*` calls
  in screens — keeps every glyph swap to one file.
- Weight signals hierarchy: `light` for inactive/idle nav and secondary
  actions, `fill` for active/selected states, `duotone` reserved for reward
  moments (streak flame, trophy, milestone flag) so they read as special.
- Sizes only from `PulseIconSize` (18/24/28/40) — never a literal.
- Every icon-only tappable control needs a `Semantics`/`tooltip` label and a
  minimum 44×44 hit area (use padding/`InkWell` bounds, not icon size, to hit
  this — don't inflate the glyph itself past `lg`).

## Motion

150–300ms for micro-interactions (button press, card tap, nav switch).
Streak/achievement celebrations (`pulse_celebration.dart`) can run longer
since they're reward moments, not utility transitions. Respect
`prefers-reduced-motion` — check `PulseMotionPolicy` before adding new
animated widgets rather than hand-rolling a new check.

## Contrast checklist (verify per screen, both themes)

- Primary text ≥ 4.5:1, secondary text ≥ 3:1, on both light and dark surface.
- Dividers/borders visible in both themes — `glassBorder` token, not a
  theme-specific one-off.
- Gold accent text/icons on light surfaces need a solid (non-glass) backing
  — it drops below contrast floor directly on `glassCard`.

## What NOT to do

- No raw `Color(0x...)` literals in `features/` or `widgets/` outside the
  theme/design folders — three of these caused the orange-brand leak this
  doc's changes fixed (celebration particles, button text, splash mark).
- No `TextStyle()` built from scratch when an `AppTypography` role fits —
  ad-hoc styles drift from the scale over time.
- No icon without a semantic label if it's the only content in a tappable
  control.
