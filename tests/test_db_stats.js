/**
 * Unit tests for the attribute-point logic in server/db.js.
 *
 * These talk to the module directly rather than over the protocol, because the
 * cases that matter (a character whose level ran ahead of its stored points)
 * cannot be produced through the normal message flow.
 *
 * Uses a throwaway DB via DB_PATH, set before db.js is required.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');

const DB_FILE = path.join(os.tmpdir(), `rpg_stats_test_${process.pid}.db`);
process.env.DB_PATH = DB_FILE;

const db = require('../server/db');

let total = 0, passed = 0, failed = 0;
function assert(cond, name) {
  total++;
  if (cond) { passed++; console.log(`  ✅ [PASS] ${name}`); }
  else { failed++; console.error(`  ❌ [FAIL] ${name}`); }
}

function characterRow(userId) {
  return db.db.prepare('SELECT * FROM characters WHERE user_id = ?').get(userId);
}

function run() {
  console.log('=======================================================');
  console.log('\u{1F9EA} RUNNING DB ATTRIBUTE-POINT TESTS');
  console.log('=======================================================');

  console.log('');
  console.log('--- 1. Level-up grants points ---');
  const reg = db.registerUser('LevelTester', 'pw123', 'archer');
  assert(reg.success, 'Archer registered');
  const uid = reg.user.id;
  assert(reg.character.class_type === 'archer', 'Registration payload carries class_type');
  assert(reg.character.stat_points === 0, 'New character starts with 0 points');

  const up = db.grantLevelPoints(uid, 3);
  assert(up.success && up.gained === 6, `Levelling 1 -> 3 grants 6 points (got ${up.gained})`);
  assert(up.character.class_type === 'archer', 'grantLevelPoints payload carries class_type');
  assert(characterRow(uid).level === 3, 'Stored level advanced to 3');

  const noop = db.grantLevelPoints(uid, 3);
  assert(!noop.success, 'Re-reporting the same level grants nothing');
  const lower = db.grantLevelPoints(uid, 2);
  assert(!lower.success, 'A lower level than stored grants nothing');

  console.log('');
  console.log('--- 2. Backfill for characters that levelled before the fix ---');
  const reg2 = db.registerUser('BackfillTester', 'pw123', 'archer');
  const uid2 = reg2.user.id;
  // Simulate the pre-fix state: level advanced by saveCharacter, points never granted.
  db.db.prepare('UPDATE characters SET level = 5, stat_points = 0 WHERE user_id = ?').run(uid2);

  const back = db.reconcileStatPoints(uid2);
  assert(back.granted === 12, `Level 5 with nothing spent backfills 12 points (got ${back.granted})`);

  const again = db.reconcileStatPoints(uid2);
  assert(again.granted === 0, 'Backfill is idempotent - a second run grants nothing');

  console.log('');
  console.log('--- 3. Backfill accounts for points already spent ---');
  const reg3 = db.registerUser('SpentTester', 'pw123', 'warrior');
  const uid3 = reg3.user.id;
  // Level 5 (12 earned), but 4 points already sunk into STR, and 2 still banked.
  db.db.prepare(
    'UPDATE characters SET level = 5, stat_str = stat_str + 4, stat_points = 2 WHERE user_id = ?'
  ).run(uid3);

  const back3 = db.reconcileStatPoints(uid3);
  assert(back3.granted === 6, `12 earned - 4 spent - 2 banked = 6 backfilled (got ${back3.granted})`);
  assert(characterRow(uid3).stat_points === 8, 'Ends with 12 earned - 4 spent = 8 available');

  console.log('');
  console.log('--- 4. Backfill runs on login ---');
  const reg4 = db.registerUser('LoginTester', 'pw123', 'mage');
  const uid4 = reg4.user.id;
  db.db.prepare('UPDATE characters SET level = 4, stat_points = 0 WHERE user_id = ?').run(uid4);

  const login = db.loginUser('LoginTester', 'pw123');
  assert(login.success, 'Login succeeded');
  assert(login.character.stat_points === 9, `Login backfills Lv.4 to 9 points (got ${login.character.stat_points})`);
  assert(login.character.class_type === 'mage', 'Login payload carries class_type');

  console.log('');
  console.log('--- 5. Allocation now actually works ---');
  const alloc = db.allocateStat(uid4, 'int');
  assert(alloc.success, 'Allocating a point succeeds once points exist');
  assert(alloc.character.stat_points === 8, 'Point count decremented');
  assert(alloc.character.class_type === 'mage', 'allocateStat payload carries class_type (would re-class the hero without it)');

  console.log('');
  console.log('=======================================================');
  console.log(`\u{1F4CA} DB TEST SUMMARY: ${total} Total | ${passed} Passed | ${failed} Failed`);
  console.log(failed === 0 ? '\u{1F389} ALL DB ATTRIBUTE TESTS PASSED!' : '❌ SOME DB TESTS FAILED!');
  console.log('=======================================================');
}

try {
  run();
} finally {
  try { fs.unlinkSync(DB_FILE); } catch (e) { /* best effort */ }
}
process.exit(failed > 0 ? 1 : 0);
