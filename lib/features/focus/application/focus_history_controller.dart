import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/repositories.dart';
import '../../../core/di/providers.dart';
import '../../../models/focus_session_model.dart';

final focusHistoryControllerProvider = AsyncNotifierProvider<FocusHistoryController, List<FocusSession>>(FocusHistoryController.new);

class FocusHistoryController extends AsyncNotifier<List<FocusSession>> {
  FocusRepository get _repository => ref.read(focusRepositoryProvider);
  @override Future<List<FocusSession>> build() => _repository.getSessionHistory(limit: 100);
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.getSessionHistory(limit: 100));
  }
}
