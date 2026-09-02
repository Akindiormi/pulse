const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const source = fs.readFileSync(path.join(__dirname, '../index.js'), 'utf8');
const flutterRepositories = fs.readFileSync(path.join(__dirname, '../../lib/core/database/firestore_repositories.dart'), 'utf8');
const flutterCompletion = fs.readFileSync(path.join(__dirname, '../../lib/features/challenges/application/complete_challenge.dart'), 'utf8');

 test('Firestore rules deny all client assignment writes', () => {
  assert.match(rules, /match \/dailyChallenges\/\{date\}/);
  assert.match(rules, /allow create: if false;/);
  assert.match(rules, /allow update: if false;/);
  assert.match(rules, /allow delete: if false;/);
});

test('Firestore rules deny direct activity and achievement writes', () => {
  assert.match(rules, /match \/activities\/\{activityId\}/);
  assert.match(rules, /match \/achievements\/\{achievementId\}/);
  assert.match(rules, /allow write: if false;/);
});

test('Firestore rules make challenge content read-only', () => {
  assert.match(rules, /match \/challenges\/\{challengeId\}/);
  assert.match(rules, /allow write: if false;/);
});

test('callable completion rejects every client field except idempotencyKey', () => {
  assert.match(source, /Only idempotencyKey is accepted/);
  assert.match(source, /key !== 'idempotencyKey'/);
  assert.doesNotMatch(source, /request\.data\.challengeId/);
  assert.doesNotMatch(source, /request\.data\.xpAwarded/);
  assert.doesNotMatch(source, /request\.data\.currentStreak/);
  assert.doesNotMatch(source, /request\.data\.level/);
  assert.doesNotMatch(source, /request\.data\.date/);
});

test('authoritative completion uses the authenticated UID', () => {
  assert.match(source, /return request\.auth\.uid/);
  assert.match(source, /const uid = requireAuth\(request\)/);
});

test('Flutter repositories no longer expose authoritative completion writes', () => {
  assert.doesNotMatch(flutterRepositories, /class FirestoreCompletionRepository/);
  assert.doesNotMatch(flutterRepositories, /recordCompletion/);
  assert.doesNotMatch(flutterRepositories, /unlock\(/);
  assert.doesNotMatch(flutterRepositories, /assignDailyChallenge/);
});

test('CompleteChallenge has no direct Firestore or local reward mutation path', () => {
  assert.doesNotMatch(flutterCompletion, /FirebaseFirestore/);
  assert.doesNotMatch(flutterCompletion, /XPService/);
  assert.doesNotMatch(flutterCompletion, /StreakService/);
  assert.doesNotMatch(flutterCompletion, /AchievementService/);
  assert.match(flutterCompletion, /TrustedChallengeBackend/);
});
