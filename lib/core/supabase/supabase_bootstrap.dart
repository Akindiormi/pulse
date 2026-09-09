import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  const SupabaseBootstrap();

  Future<void> initialize() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError('Pulse Supabase configuration is missing. Build with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.');
    }
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }
}
