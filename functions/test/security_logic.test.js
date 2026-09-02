const test = require('node:test');
const assert = require('node:assert/strict');
const { __test } = require('../index');

const { levelForXP, utcDateKey, utcDayDifference, calculateStreak, stableIndex } = __test;

test('level calculation matches the client domain thresholds', () => {
  assert.equal(levelForXP(0), 1);
  assert.equal(levelForXP(99), 1);
  assert.equal(levelForXP(100), 2);
  assert.equal(levelForXP(249), 2);
  assert.equal(levelForXP(250), 3);
  assert.equal(levelForXP(2900), 10);
  assert.equal(levelForXP(3550), 11);
});

test('server date key is UTC and does not accept a client supplied date', () => {
  assert.equal(utcDateKey(new Date('2026-09-02T23:59:59.000Z')), '2026-09-02');
  assert.equal(utcDateKey(new Date('2026-09-03T00:00:00.000Z')), '2026-09-03');
});

test('calendar day difference is date based', () => {
  assert.equal(utcDayDifference(new Date('2026-09-01T23:59:59Z'), new Date('2026-09-02T00:00:01Z')), 1);
  assert.equal(utcDayDifference(new Date('2026-09-02T01:00:00Z'), new Date('2026-09-02T23:00:00Z')), 0);
});

test('streak starts at one and only increments on the next UTC calendar day', () => {
  const now = new Date('2026-09-02T12:00:00Z');
  assert.deepEqual(calculateStreak(null, 0, 0, now), { previous: 0, current: 1, longest: 1, changed: true });
  assert.deepEqual(calculateStreak(new Date('2026-09-02T01:00:00Z'), 5, 7, now), { previous: 5, current: 5, longest: 7, changed: false });
  assert.deepEqual(calculateStreak(new Date('2026-09-01T23:00:00Z'), 5, 7, now), { previous: 5, current: 6, longest: 7, changed: true });
  assert.deepEqual(calculateStreak(new Date('2026-08-30T23:00:00Z'), 5, 7, now), { previous: 5, current: 1, longest: 7, changed: true });
});

test('daily selection is deterministic for the same date', () => {
  assert.equal(stableIndex('2026-09-02', 50), stableIndex('2026-09-02', 50));
  assert.ok(stableIndex('2026-09-02', 50) >= 0);
  assert.ok(stableIndex('2026-09-02', 50) < 50);
});
