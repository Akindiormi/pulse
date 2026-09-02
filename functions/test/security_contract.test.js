const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const source = fs.readFileSync(path.join(__dirname, '../index.js'), 'utf8');

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

test('callable completion does not accept client-controlled progress inputs', () => {
  assert.match(source, /Only idempotencyKey is accepted/);
  for (const forbidden of ['challengeId', 'xpAwarded', 'xp:', 'currentStreak:', 'level:', 'date:']) {
    assert.ok(!source.includes(`request.data.${forbidden}`), `unexpected client-controlled input: ${forbidden}`);
  }
});

test('authoritative completion uses the authenticated UID', () => {
  assert.match(source, /return request\.auth\.uid/);
  assert.match(source, /const uid = requireAuth\(request\)/);
});
