import 'trusted_challenge_backend.dart';

abstract interface class TrustedAccountBackend {
  Future<void> deleteAccountData();
}

class FirebaseCallableAccountBackend implements TrustedAccountBackend {
  FirebaseCallableAccountBackend(this._client);

  final TrustedCallableClient _client;

  @override
  Future<void> deleteAccountData() async {
    await _client.call('deleteAccountData', const <String, dynamic>{});
  }
}
