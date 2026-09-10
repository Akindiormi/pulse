import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  const SupabaseBootstrap();

  Future<void> initialize() async {
    const rawUrl = String.fromEnvironment('SUPABASE_URL');
    const rawKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    final url = rawUrl.trim();
    final publishableKey = rawKey.trim();
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError('Pulse Supabase configuration is missing. Build with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.');
    }
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }
}
