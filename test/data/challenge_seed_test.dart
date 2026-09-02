import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/challenges/data/challenge_seed_data.dart';
import 'package:pulse/models/challenge_model.dart';

void main() {
  test('seed contains 48 unique active challenges across all categories and difficulties', () {
    expect(challengeSeedData.length, 48);
    expect(challengeSeedData.map((e) => e.id).toSet().length, 48);
    expect(challengeSeedData.every((e) => e.active), true);
    expect(challengeSeedData.map((e) => e.category).toSet(), ChallengeCategory.values.toSet());
    expect(challengeSeedData.map((e) => e.difficulty).toSet(), Difficulty.values.toSet());
    expect(challengeSeedData.every((e) => e.title.isNotEmpty && e.description.isNotEmpty && e.estimatedMinutes > 0 && e.xpReward > 0), true);
  });
}
