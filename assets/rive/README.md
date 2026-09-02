# Pulse Rive assets

Place production `.riv` files in the appropriate feature folder:

- `splash/`
- `onboarding/`
- `auth/`
- `challenge/`
- `progression/`
- `achievements/`
- `profile/`
- `navigation/`

No production Rive artwork is included by Phase 5 unless supplied separately.

When an asset is added, connect it through `PulseMotionAttachment` →
`PulseRiveAttachment` / `PulseRiveMotionHost`. Do not put Rive controllers in
business services or repositories.
