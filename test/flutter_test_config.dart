import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Tests run inside Flutter's TestWidgetsFlutterBinding, which blocks real
  // HTTP requests. Keep Google Fonts from starting asynchronous network font
  // loads when the Manrope TTFs are not bundled yet; the UI still exercises
  // the complete typography contract through its configured text styles.
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
