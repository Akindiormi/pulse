import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Manrope is currently supplied through google_fonts. CI has network access,
  // so allow the package to fetch the font instead of failing when no local
  // TTF asset has been bundled yet.
  GoogleFonts.config.allowRuntimeFetching = true;
  await testMain();
}
