Reserved for supplied Pulse auth `.riv` artwork.

## Expected file

`assets/rive/auth/auth.riv` (see `PulseRiveAssets.auth`).

## Expected state machine contract

The auth screen (`lib/features/auth/presentation/auth_screen.dart`) drives an
optional avatar through `PulseRiveAttachment`, wired to `PulseAuthAvatarState`
(`lib/core/motion/pulse_motion_state.dart`). Until a matching `.riv` file
exists here, the screen falls back to nothing (no placeholder, no broken
image) — this is intentional and safe.

When building the asset in the Rive editor, name the state machine's trigger
inputs *exactly* as follows so they wire up automatically:

| Trigger name       | Fires when                                              |
|---------------------|----------------------------------------------------------|
| `idle`              | No field is focused, nothing has failed validation       |
| `emailFocused`       | The email field has focus                                |
| `passwordFocused`    | The password field has focus (e.g. avatar covers its eyes)|
| `error`             | A touched field fails validation on blur                  |
| `success`           | Sign-in/sign-up completes successfully                    |

Name expressions after these interface states, not emotions — that's what
lets the trigger names above map directly onto the state machine with no
further code changes needed.

Default artboard/state machine names are used (no need to set
`artboardName`/`stateMachineName` unless the exported file uses non-default
names — if it does, update the `PulseRiveAttachment` call in
`auth_screen.dart` to match).
