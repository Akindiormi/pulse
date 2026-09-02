import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/achievement_model.dart';
import '../../models/activity_model.dart';
import '../../models/challenge_model.dart';
import '../../models/user_model.dart';
import 'repositories.dart';

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository(this.firestore);
  final FirebaseFirestore firestore;
  DocumentReference<Map<String, dynamic>> _ref(String uid) => firestore.collection('users').doc(uid);

  @override
  Future<void> createOrUpdateUser({required String uid, String? displayName, String? photoUrl}) async {
    final ref = _ref(uid);
    await firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final profile = <String, dynamic>{'displayName': displayName, 'photoUrl': photoUrl};
      if (snapshot.exists) {
        tx.update(ref, profile);
      } else {
        tx.set(ref, {...profile, 'username': displayName, 'createdAt': FieldValue.serverTimestamp(), 'totalActivities': 0, 'currentStreak': 0, 'longestStreak': 0, 'xp': 0, 'level': 1, 'lastActivityDate': null, 'completedCategories': <String>[], 'unlockedAchievements': <String>[]});
      }
    });
  }

  @override
  Future<Map<String, dynamic>?> getUser(String uid) async => (await _ref(uid).get()).data();
}

class FirestoreChallengeRepository implements ChallengeRepository {
  FirestoreChallengeRepository(this.firestore);
  final FirebaseFirestore firestore;
  DocumentReference<Map<String, dynamic>> _assignmentRef(String uid, String date) => firestore.collection('users').doc(uid).collection('dailyChallenges').doc(date);

  @override
  Future<Map<String, dynamic>?> getDailyAssignment({required String uid, required String date}) async => (await _assignmentRef(uid, date).get()).data();

  @override
  Future<void> assignDailyChallenge({required String uid, required String date, required String challengeId}) async {
    final assignment = _assignmentRef(uid, date);
    await firestore.runTransaction((tx) async {
      final existing = await tx.get(assignment);
      if (existing.exists) return;
      tx.set(assignment, {'challengeId': challengeId, 'date': date, 'assignedAt': FieldValue.serverTimestamp(), 'completed': false, 'completedAt': null});
    });
  }

  @override
  Future<Map<String, dynamic>?> getChallenge(String challengeId) async => (await firestore.collection('challenges').doc(challengeId).get()).data();

  @override
  Future<List<Challenge>> getActiveChallenges() async {
    final snapshot = await firestore.collection('challenges').where('active', isEqualTo: true).get();
    return snapshot.docs.map((doc) => Challenge.fromMap(doc.id, doc.data())).toList(growable: false);
  }
}

class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository(this.firestore);
  final FirebaseFirestore firestore;
  CollectionReference<Map<String, dynamic>> _collection(String uid) => firestore.collection('users').doc(uid).collection('activities');

  @override Future<bool> isCompleted({required String uid, required String activityId}) async => (await _collection(uid).doc(activityId).get()).exists;

  @override
  Future<void> recordCompletion({required String uid, required String activityId, required String challengeId, required String date, required int xpAwarded}) async {
    final ref = _collection(uid).doc(activityId);
    await firestore.runTransaction((tx) async { if ((await tx.get(ref)).exists) return; tx.set(ref, {'userId': uid, 'challengeId': challengeId, 'date': date, 'xpAwarded': xpAwarded, 'completedAt': FieldValue.serverTimestamp()}); });
  }

  @override
  Future<List<ActivityModel>> getActivities(String uid) async {
    final snapshot = await _collection(uid).orderBy('completedAt', descending: true).get();
    return snapshot.docs.map((doc) => ActivityModel.fromMap(doc.id, doc.data())).toList(growable: false);
  }

  @override
  Future<Set<String>> getCompletedCategories(String uid) async {
    final activities = await getActivities(uid);
    final categories = <String>{};
    for (final activity in activities) {
      if (activity.category != null) {
        categories.add(activity.category!);
      } else {
        final challenge = await FirestoreChallengeRepository(firestore).getChallenge(activity.challengeId);
        final category = challenge?['category'];
        if (category is String) categories.add(category);
      }
    }
    return categories;
  }
}

class FirestoreAchievementRepository implements AchievementRepository {
  FirestoreAchievementRepository(this.firestore);
  final FirebaseFirestore firestore;
  CollectionReference<Map<String, dynamic>> _collection(String uid) => firestore.collection('users').doc(uid).collection('achievements');
  @override Future<Set<String>> getUnlockedIds(String uid) async => (await _collection(uid).get()).docs.map((doc) => doc.id).toSet();
  @override Future<void> unlock({required String uid, required AchievementRecord record}) async => _collection(uid).doc(record.achievementId).set(record.toMap(), SetOptions(merge: false));
}

class FirestoreCompletionRepository implements CompletionRepository {
  FirestoreCompletionRepository(this.firestore);
  final FirebaseFirestore firestore;

  @override
  Future<CompletionMutation> runAtomic({required String uid, required String activityId, required String date, required CompletionCalculator calculate}) async {
    final userRef = firestore.collection('users').doc(uid);
    final assignmentRef = userRef.collection('dailyChallenges').doc(date);
    final activityRef = userRef.collection('activities').doc(activityId);
    return firestore.runTransaction((tx) async {
      final userSnapshot = await tx.get(userRef);
      final assignmentSnapshot = await tx.get(assignmentRef);
      final activitySnapshot = await tx.get(activityRef);
      if (!userSnapshot.exists) throw StateError('Cannot complete a challenge before the user document exists.');
      final user = UserModel.fromMap(uid, userSnapshot.data() ?? const <String, dynamic>{});
      final assignmentData = assignmentSnapshot.data();
      final assignment = assignmentData == null ? null : DailyChallengeAssignment.fromMap(assignmentData, date: date);
      Challenge? challenge;
      if (assignment != null && assignment.challengeId.isNotEmpty) {
        final challengeSnapshot = await tx.get(firestore.collection('challenges').doc(assignment.challengeId));
        if (challengeSnapshot.exists) challenge = Challenge.fromMap(challengeSnapshot.id, challengeSnapshot.data() ?? const <String, dynamic>{});
      }
      final mutation = calculate(CompletionState(user: user, assignment: assignment, challenge: challenge, activityExists: activitySnapshot.exists));
      if (!mutation.completed) return mutation;
      final activity = mutation.activity;
      if (activity == null) throw StateError('A successful completion must contain an activity record.');
      tx.create(activityRef, activity.toMap());
      tx.update(userRef, {'totalActivities': mutation.user.totalActivities, 'currentStreak': mutation.user.currentStreak, 'longestStreak': mutation.user.longestStreak, 'xp': mutation.user.xp, 'level': mutation.user.level, 'lastActivityDate': mutation.user.lastActivityDate, 'completedCategories': mutation.user.completedCategories.toList()..sort(), 'unlockedAchievements': mutation.user.unlockedAchievements.toList()..sort()});
      tx.update(assignmentRef, {'completed': true, 'completedAt': activity.completedAt});
      for (final record in mutation.newAchievements) tx.create(userRef.collection('achievements').doc(record.achievementId), record.toMap());
      return mutation;
    });
  }
}
