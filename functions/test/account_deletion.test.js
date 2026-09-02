const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { deleteUserData } = require('../account_deletion');

const source = fs.readFileSync(path.join(__dirname, '../index.js'), 'utf8');
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');

function fakeDatabase() {
  const calls = [];
  return {
    calls,
    collection(name) {
      return {
        doc(uid) {
          calls.push({ name, uid });
          return { path: `${name}/${uid}` };
        },
      };
    },
    async recursiveDelete(ref) {
      calls.push({ recursiveDelete: ref.path });
    },
  };
}

test('account deletion requires authentication and uses authenticated UID', () => {
  assert.match(source, /exports\.deleteAccountData = onCall/);
  assert.match(source, /const uid = requireAuth\(request\)/);
  assert.match(source, /requireAuth\(request\)/);
  assert.match(source, /return request\.auth\.uid/);
});

test('account deletion is scoped to users/{uid}', async () => {
  const database = fakeDatabase();
  await deleteUserData(database, 'user-a');
  assert.deepEqual(database.calls, [
    { name: 'users', uid: 'user-a' },
    { recursiveDelete: 'users/user-a' },
  ]);
  assert.equal(database.calls.some((call) => call.uid === 'user-b'), false);
});

test('account deletion removes the user document and all current subcollections through recursive deletion', async () => {
  const database = fakeDatabase();
  await deleteUserData(database, 'user-a');
  assert.equal(database.calls.at(-1).recursiveDelete, 'users/user-a');
  assert.match(source, /recursiveDelete\(userRef\)/);
});

test('account deletion is safe to retry after the user path is already clean', async () => {
  const database = fakeDatabase();
  await deleteUserData(database, 'user-a');
  await deleteUserData(database, 'user-a');
  assert.equal(database.calls.filter((call) => call.recursiveDelete === 'users/user-a').length, 2);
});

test('account deletion never targets the global challenges collection', async () => {
  const database = fakeDatabase();
  await deleteUserData(database, 'user-a');
  assert.equal(database.calls.some((call) => call.name === 'challenges'), false);
  assert.doesNotMatch(source, /recursiveDelete\(db\.collection\('challenges'\)/);
});

test('clients still cannot directly delete user data', () => {
  assert.match(rules, /match \/users\/\{userId\}/);
  assert.match(rules, /allow delete: if false;/);
  assert.match(rules, /match \/dailyChallenges\/\{date\}/);
  assert.match(rules, /match \/activities\/\{activityId\}/);
  assert.match(rules, /match \/achievements\/\{achievementId\}/);
});
