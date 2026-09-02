const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { parseChallengeSeed, validateSeed, seedChallenges } = require('../scripts/seed_challenges');

const seedSource = fs.readFileSync(path.join(__dirname, '../../lib/features/challenges/data/challenge_seed_data.dart'), 'utf8');

test('seeding reads the existing Dart challenge seed as its only content source', () => {
  const records = parseChallengeSeed(seedSource);
  validateSeed(records);
  assert.equal(records.length, 50);
  assert.equal(new Set(records.map((record) => record.id)).size, 50);
});

test('seeding validates the expected category and difficulty distribution', () => {
  const records = parseChallengeSeed(seedSource);
  validateSeed(records);
  assert.deepEqual(
    Object.fromEntries(['easy', 'medium', 'hard', 'wild'].map((difficulty) => [difficulty, records.filter((record) => record.difficulty === difficulty).length])),
    { easy: 16, medium: 16, hard: 8, wild: 8 },
  );
  for (const category of ['random', 'social', 'health', 'money', 'learning', 'confidence', 'creativity', 'mindfulness']) {
    assert.equal(records.filter((record) => record.category === category).length, 6);
  }
});

test('repeated seeding upserts by challenge ID and does not delete unrelated documents', async () => {
  const writes = [];
  const database = {
    collection(name) {
      assert.equal(name, 'challenges');
      return {
        doc(id) {
          return { id, set: undefined };
        },
      };
    },
    batch() {
      return {
        set(ref, data, options) {
          writes.push({ path: `challenges/${ref.id}`, data, options });
        },
        async commit() {},
      };
    },
  };
  const records = parseChallengeSeed(seedSource);
  await seedChallenges(database, records);
  await seedChallenges(database, records);

  assert.equal(writes.length, 100);
  assert.equal(writes.every((write) => write.options.merge === true), true);
  assert.equal(writes.some((write) => write.path === 'users/user-a'), false);
  assert.equal(writes.some((write) => write.path.startsWith('challenges/')), true);
});
