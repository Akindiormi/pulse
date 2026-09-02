const fs = require('node:fs');
const path = require('node:path');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const SEED_PATH = path.join(__dirname, '../../lib/features/challenges/data/challenge_seed_data.dart');
const EXPECTED_TOTAL = 48;
const DIFFICULTY_XP = { easy: 10, medium: 25, hard: 50, wild: 75 };
const EXPECTED_CATEGORIES = ['random', 'social', 'health', 'money', 'learning', 'confidence', 'creativity', 'mindfulness'];
const EXPECTED_COUNTS = { easy: 16, medium: 16, hard: 8, wild: 8 };

function parseChallengeSeed(source) {
  const records = [];
  const pattern = /_challenge\('([^']+)', '([^']*)', '([^']*)', ChallengeCategory\.([a-zA-Z]+), Difficulty\.([a-zA-Z]+), (\d+)(?:, cost: ([0-9.]+))?\)/g;
  let match;
  while ((match = pattern.exec(source)) !== null) {
    const [, id, title, description, category, difficulty, minutes, cost] = match;
    const xpReward = DIFFICULTY_XP[difficulty];
    if (xpReward == null) throw new Error(`Unsupported difficulty in seed: ${difficulty}`);
    records.push({
      id,
      title,
      description,
      category,
      difficulty,
      xpReward,
      estimatedMinutes: Number(minutes),
      ...(cost == null ? {} : { estimatedCost: Number(cost) }),
      active: true,
      createdAt: Timestamp.fromDate(new Date('2026-09-01T00:00:00.000Z')),
    });
  }
  return records;
}

function validateSeed(records) {
  if (records.length !== EXPECTED_TOTAL) throw new Error(`Expected ${EXPECTED_TOTAL} challenges, found ${records.length}.`);
  const ids = new Set(records.map((record) => record.id));
  if (ids.size !== records.length) throw new Error('Challenge seed contains duplicate IDs.');

  const categories = new Set(records.map((record) => record.category));
  if (categories.size !== EXPECTED_CATEGORIES.length || EXPECTED_CATEGORIES.some((category) => !categories.has(category))) {
    throw new Error('Challenge seed categories do not match the expected eight categories.');
  }
  for (const category of EXPECTED_CATEGORIES) {
    const count = records.filter((record) => record.category === category).length;
    if (count !== 6) throw new Error(`Expected 6 challenges in ${category}, found ${count}.`);
  }
  for (const [difficulty, expected] of Object.entries(EXPECTED_COUNTS)) {
    const count = records.filter((record) => record.difficulty === difficulty).length;
    if (count !== expected) throw new Error(`Expected ${expected} ${difficulty} challenges, found ${count}.`);
  }
  if (records.some((record) => record.active !== true)) throw new Error('Seed contains an inactive challenge.');
}

async function seedChallenges(database, records) {
  const batch = database.batch();
  for (const record of records) {
    batch.set(database.collection('challenges').doc(record.id), record, { merge: true });
  }
  await batch.commit();
}

async function main() {
  const source = fs.readFileSync(SEED_PATH, 'utf8');
  const records = parseChallengeSeed(source);
  validateSeed(records);

  initializeApp();
  const db = getFirestore();
  await seedChallenges(db, records);
  console.log(`Seeded ${records.length} challenges from ${SEED_PATH}. Existing IDs were upserted; unrelated documents were not deleted.`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}

module.exports = { parseChallengeSeed, validateSeed, seedChallenges };
