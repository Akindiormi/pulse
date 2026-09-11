import 'trusted_challenge_backend.dart';

abstract interface class TrustedAccountBackend {
  Future<void> deleteAccountData();
}

class SupabaseCallableAccountBackend implements TrustedAccountBackend {
  SupabaseCallableAccountBackend(this._client);
  final TrustedCallableClient _client;

  @override
  Future<void> deleteAccountData() async {
    await _client.call('delete-account', const <String, dynamic>{});
  }
}
