const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldPath, Timestamp } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');

initializeApp();
setGlobalOptions({ region: 'us-central1', enforceAppCheck: true });

const db = getFirestore();
const ACHIEVEMENTS = [
  { id: 'FIRST_STEP', type: 'activityCount', threshold: 1, xpReward: 25 },
  { id: 'GETTING_STARTED', type: 'streak', threshold: 3, xpReward: 50 },
  { id: 'WEEK_WARRIOR', type: 'streak', threshold: 7, xpReward: 100 },
  { id: 'TWO_WEEKS', type: 'streak', threshold: 14, xpReward: 150 },
  { id: 'UNSTOPPABLE', type: 'streak', threshold: 30, xpReward: 300 },
  { id: 'CENTURY', type: 'activityCount', threshold: 100, xpReward: 500 },
  { id: 'EXPLORER', type: 'categoryCount', threshold: 5, xpReward: 150 },
  { id: 'MASTER_EXPLORER', type: 'categoryCount', threshold: 8, xpReward: 300 },
];

const XP_THRESHOLDS = [0, 100, 250, 450, 700, 1000, 1400, 1850, 2350, 2900];

function levelForXP(xp) {
  let level = 1;
  for (let i = 0; i < XP_THRESHOLDS.length; i += 1) {
    if (xp >= XP_THRESHOLDS[i]) level = i + 1;
  }
  if (xp >= XP_THRESHOLDS[XP_THRESHOLDS.length - 1]) {
    level = XP_THRESHOLDS.length + Math.floor((xp - XP_THRESHOLDS[XP_THRESHOLDS.length - 1]) / 650);
  }
  return level;
}

function utcDateKey(date) {
  return date.toISOString().slice(0, 10);
}

function utcDayDifference(a, b) {
  const aDay = Date.UTC(a.getUTCFullYear(), a.getUTCMonth(), a.getUTCDate());
  const bDay = Date.UTC(b.getUTCFullYear(), b.getUTCMonth(), b.getUTCDate());
  return Math.round((bDay - aDay) / 86400000);
}

function calculateStreak(lastActivityDate, currentStreak, longestStreak, now) {
  if (!lastActivityDate) return { previous: 0, current: 1, longest: Math.max(1, longestStreak), changed: true };
  const difference = utcDayDifference(lastActivityDate, now);
  if (difference === 0) return { previous: currentStreak, current: currentStreak, longest: longestStreak, changed: false };
  const next = difference === 1 ? currentStreak + 1 : 1;
  return { previous: currentStreak, current: next, longest: Math.max(longestStreak, next), changed: true };
}

function stableIndex(input, length) {
  let hash = 7;
  for (const codeUnit of input) hash = (hash * 31 + codeUnit.charCodeAt(0)) & 0x7fffffff;
  return hash % length;
}

async function chooseChallenge(transaction, date) {
  const snapshot = await transaction.get(db.collection('challenges').where('active', '==', true));
  const challenges = snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((a, b) => a.id.localeCompare(b.id));
  if (challenges.length === 0) throw new HttpsError('failed-precondition', 'No active challenges are available.');
  return challenges[stableIndex(date, challenges.length)];
}

function requireAuth(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication is required.');
  return request.auth.uid;
}

function requireEmptyOrObject(data) {
  if (data == null) return;
  if (typeof data !== 'object' || Array.isArray(data)) throw new HttpsError('invalid-argument', 'Request data must be an object.');
  const keys = Object.keys(data);
  if (keys.length !== 0) throw new HttpsError('invalid-argument', 'This operation does not accept client-controlled arguments.');
}

exports.getOrAssignDailyChallenge = onCall(async (request) => {
  const uid = requireAuth(request);
  requireEmptyOrObject(request.data);
  const now = new Date();
  const date = utcDateKey(now);
  const userRef = db.collection('users').doc(uid);
  const assignmentRef = userRef.collection('dailyChallenges').doc(date);

  return db.runTransaction(async (transaction) => {
    const [userSnapshot, assignmentSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(assignmentRef),
    ]);
    if (!userSnapshot.exists) throw new HttpsError('failed-precondition', 'User profile does not exist.');

    let assignment = assignmentSnapshot.exists ? assignmentSnapshot.data() : null;
    if (!assignment || assignment.source !== 'server') {
      const challenge = await chooseChallenge(transaction, date);
      assignment = {
        challengeId: challenge.id,
        date,
        assignedAt: Timestamp.now(),
        completed: false,
        completedAt: null,
        source: 'server',
        assignmentVersion: 1,
      };
      transaction.set(assignmentRef, assignment);
    }

    const challengeSnapshot = await transaction.get(db.collection('challenges').doc(assignment.challengeId));
    if (!challengeSnapshot.exists || challengeSnapshot.data().active !== true) {
      throw new HttpsError('failed-precondition', 'The assigned challenge is unavailable.');
    }
    return { date, challengeId: assignment.challengeId, completed: assignment.completed === true };
  });
});

exports.completeChallenge = onCall(async (request) => {
  const uid = requireAuth(request);
  if (request.data == null || typeof request.data !== 'object' || Array.isArray(request.data)) {
    throw new HttpsError('invalid-argument', 'Request data must be an object.');
  }
  const allowedKeys = Object.keys(request.data);
  if (allowedKeys.some((key) => key !== 'idempotencyKey')) {
    throw new HttpsError('invalid-argument', 'Only idempotencyKey is accepted.');
  }
  if (request.data.idempotencyKey != null && (typeof request.data.idempotencyKey !== 'string' || request.data.idempotencyKey.length > 128)) {
    throw new HttpsError('invalid-argument', 'Invalid idempotencyKey.');
  }

  const now = new Date();
  const date = utcDateKey(now);
  const userRef = db.collection('users').doc(uid);
  const assignmentRef = userRef.collection('dailyChallenges').doc(date);

  return db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    if (!userSnapshot.exists) throw new HttpsError('failed-precondition', 'User profile does not exist.');
    const user = userSnapshot.data();

    let assignmentSnapshot = await transaction.get(assignmentRef);
    if (!assignmentSnapshot.exists || assignmentSnapshot.data().source !== 'server') {
      const challenge = await chooseChallenge(transaction, date);
      const assignment = {
        challengeId: challenge.id,
        date,
        assignedAt: Timestamp.now(),
        completed: false,
        completedAt: null,
        source: 'server',
        assignmentVersion: 1,
      };
      transaction.set(assignmentRef, assignment);
      assignmentSnapshot = { exists: true, data: () => assignment };
    }

    const assignment = assignmentSnapshot.data();
    if (assignment.completed === true) {
      return { completed: false, alreadyCompleted: true, xpAwarded: 0 };
    }
    if (assignment.date !== date || assignment.source !== 'server' || typeof assignment.challengeId !== 'string') {
      throw new HttpsError('failed-precondition', 'The daily assignment could not be verified.');
    }

    const challengeRef = db.collection('challenges').doc(assignment.challengeId);
    const activityRef = userRef.collection('activities').doc(`${date}-${assignment.challengeId}`);
    const challengeSnapshot = await transaction.get(challengeRef);
    const activitySnapshot = await transaction.get(activityRef);
    if (activitySnapshot.exists) return { completed: false, alreadyCompleted: true, xpAwarded: 0 };
    if (!challengeSnapshot.exists || challengeSnapshot.data().active !== true) {
      throw new HttpsError('failed-precondition', 'The assigned challenge is no longer active.');
    }

    const challenge = challengeSnapshot.data();
    const reward = Number(challenge.xpReward);
    if (!Number.isInteger(reward) || reward < 0 || reward > 1000) {
      throw new HttpsError('failed-precondition', 'Challenge reward is invalid.');
    }

    const currentXP = Number(user.xp) || 0;
    const currentLevel = Number(user.level) || 1;
    const totalActivities = Number(user.totalActivities) || 0;
    const currentStreak = Number(user.currentStreak) || 0;
    const longestStreak = Number(user.longestStreak) || 0;
    const previousLast = user.lastActivityDate instanceof Timestamp ? user.lastActivityDate.toDate() : null;
    const streak = calculateStreak(previousLast, currentStreak, longestStreak, now);
    const categories = new Set(Array.isArray(user.completedCategories) ? user.completedCategories.filter((v) => typeof v === 'string') : []);
    if (typeof challenge.category === 'string') categories.add(challenge.category);

    const unlocked = new Set(Array.isArray(user.unlockedAchievements) ? user.unlockedAchievements.filter((v) => typeof v === 'string') : []);
    const newAchievements = [];
    let achievementXP = 0;
    const nextActivityCount = totalActivities + 1;
    for (const achievement of ACHIEVEMENTS) {
      if (unlocked.has(achievement.id)) continue;
      const eligible = achievement.type === 'streak'
        ? streak.current >= achievement.threshold
        : achievement.type === 'activityCount'
          ? nextActivityCount >= achievement.threshold
          : categories.size >= achievement.threshold;
      if (!eligible) continue;
      unlocked.add(achievement.id);
      achievementXP += achievement.xpReward;
      newAchievements.push(achievement.id);
      transaction.create(userRef.collection('achievements').doc(achievement.id), {
        achievementId: achievement.id,
        unlockedAt: Timestamp.fromDate(now),
      });
    }

    const totalReward = reward + achievementXP;
    const nextXP = currentXP + totalReward;
    const nextLevel = levelForXP(nextXP);
    const activity = {
      userId: uid,
      challengeId: assignment.challengeId,
      date,
      xpAwarded: reward,
      completedAt: Timestamp.fromDate(now),
      category: challenge.category,
    };

    transaction.create(activityRef, activity);
    transaction.update(userRef, {
      totalActivities: nextActivityCount,
      currentStreak: streak.current,
      longestStreak: streak.longest,
      xp: nextXP,
      level: nextLevel,
      lastActivityDate: Timestamp.fromDate(now),
      completedCategories: [...categories].sort(),
      unlockedAchievements: [...unlocked].sort(),
    });
    transaction.update(assignmentRef, {
      completed: true,
      completedAt: Timestamp.fromDate(now),
    });

    return {
      completed: true,
      alreadyCompleted: false,
      challengeId: assignment.challengeId,
      xpAwarded: totalReward,
      challengeXP: reward,
      achievementXP,
      previousXP: currentXP,
      currentXP: nextXP,
      previousStreak: currentStreak,
      currentStreak: streak.current,
      longestStreak: streak.longest,
      previousLevel: currentLevel,
      newLevel: nextLevel,
      leveledUp: nextLevel > currentLevel,
      newAchievements,
    };
  });
});

exports.__test = { levelForXP, utcDateKey, utcDayDifference, calculateStreak, stableIndex };
