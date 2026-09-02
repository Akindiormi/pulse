import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/activity_model.dart';
import '../../models/achievement_model.dart';
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
      if (snapshot.exists) {
        final profile = <String, dynamic>{'displayName': displayName};
        if (photoUrl != null) profile['photoUrl'] = photoUrl;
        tx.update(ref, profile);
      } else {
        tx.set(ref, {
          'displayName': displayName,
          'photoUrl': photoUrl,
          'username': displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'totalActivities': 0,
          'currentStreak': 0,
          'longestStreak': 0,
          'xp': 0,
          'level': 1,
          'lastActivityDate': null,
          'completedCategories': <String>[],
          'unlockedAchievements': <String>[],
        });
      }
    });
  }

  @override
  Future<void> updateProfileFields({required String uid, required Map<String, dynamic> fields}) async {
    await _ref(uid).update(UserProfileUpdate(fields).toFirestore());
  }

  @override
  Future<Map<String, dynamic>?> getUser(String uid) async => (await _ref(uid).get()).data();

  @override
  Future<UserModel?> getUserModel(String uid) async {
    final data = await getUser(uid);
    return data == null ? null : UserModel.fromMap(uid, data);
  }

  @override
  Future<void> updatePreferences({required String uid, required Map<String, dynamic> preferences}) => _ref(uid).update({'notificationPreferences': preferences});
}

class FirestoreChallengeRepository implements ChallengeRepository {
  FirestoreChallengeRepository(this.firestore);
  final FirebaseFirestore firestore;
  DocumentReference<Map<String, dynamic>> _assignmentRef(String uid, String date) => firestore.collection('users').doc(uid).collection('dailyChallenges').doc(date);
  @override Future<Map<String, dynamic>?> getDailyAssignment({required String uid, required String date}) async => (await _assignmentRef(uid, date).get()).data();
  @override Future<Map<String, dynamic>?> getChallenge(String challengeId) async => (await firestore.collection('challenges').doc(challengeId).get()).data();
  @override Future<List<Challenge>> getActiveChallenges() async { final snapshot = await firestore.collection('challenges').where('active', isEqualTo: true).get(); return snapshot.docs.map((doc) => Challenge.fromMap(doc.id, doc.data())).toList(growable: false); }
}

class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository(this.firestore);
  final FirebaseFirestore firestore;
  CollectionReference<Map<String, dynamic>> _collection(String uid) => firestore.collection('users').doc(uid).collection('activities');
  @override Future<bool> isCompleted({required String uid, required String activityId}) async => (await _collection(uid).doc(activityId).get()).exists;
  @override Future<List<ActivityModel>> getActivities(String uid) async { final snapshot = await _collection(uid).orderBy('completedAt', descending: true).get(); return snapshot.docs.map((doc) => ActivityModel.fromMap(doc.id, doc.data())).toList(growable: false); }
  @override Future<Set<String>> getCompletedCategories(String uid) async { final activities = await getActivities(uid); final categories = <String>{}; for (final activity in activities) { if (activity.category != null) { categories.add(activity.category!); } else { final challenge = await FirestoreChallengeRepository(firestore).getChallenge(activity.challengeId); final category = challenge?['category']; if (category is String) categories.add(category); } } return categories; }
}

class FirestoreAchievementRepository implements AchievementRepository {
  FirestoreAchievementRepository(this.firestore);
  final FirebaseFirestore firestore;
  CollectionReference<Map<String, dynamic>> _collection(String uid) => firestore.collection('users').doc(uid).collection('achievements');
  @override Future<Set<String>> getUnlockedIds(String uid) async => (await _collection(uid).get()).docs.map((doc) => doc.id).toSet();
  @override Future<List<AchievementRecord>> getUnlockedRecords(String uid) async => (await _collection(uid).get()).docs.map((doc) => AchievementRecord.fromMap(doc.id, doc.data())).toList(growable: false);
}
