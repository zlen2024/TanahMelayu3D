/**
 * Database Module for Godot Web RPG
 * Powered by Node 24 native node:sqlite (zero external dependencies).
 * Stores user accounts, hashed passwords, character stats (STR, VIT, AGI, INT), and inventory slots.
 */

const { DatabaseSync } = require('node:sqlite');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const DATA_DIR = path.resolve(__dirname, 'data');
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

const DB_PATH = process.env.DB_PATH || path.join(DATA_DIR, 'rpg.db');
const db = new DatabaseSync(DB_PATH);

// Initialize schema
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS characters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER UNIQUE NOT NULL,
    name TEXT NOT NULL,
    class_type TEXT NOT NULL DEFAULT 'warrior',
    skin INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    xp INTEGER DEFAULT 0,
    stat_str INTEGER DEFAULT 10,
    stat_vit INTEGER DEFAULT 10,
    stat_agi INTEGER DEFAULT 10,
    stat_int INTEGER DEFAULT 10,
    stat_points INTEGER DEFAULT 0,
    hp INTEGER DEFAULT 150,
    max_hp INTEGER DEFAULT 150,
    energy INTEGER DEFAULT 80,
    max_energy INTEGER DEFAULT 80,
    pos_x REAL DEFAULT 0,
    pos_y REAL DEFAULT 0,
    FOREIGN KEY(user_id) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    slot_index INTEGER NOT NULL,
    item_id TEXT NOT NULL,
    item_name TEXT NOT NULL,
    item_type TEXT NOT NULL,
    quantity INTEGER DEFAULT 1,
    FOREIGN KEY(user_id) REFERENCES users(id)
  );
`);

try {
  db.exec("ALTER TABLE characters ADD COLUMN class_type TEXT DEFAULT 'warrior'");
} catch (e) {
  // column already exists
}

function hashPassword(password, salt) {
  return crypto.scryptSync(password, salt, 32).toString('hex');
}

function registerUser(username, password, classType = 'warrior', skin = null) {
  username = username.trim();
  if (!username || username.length < 2) {
    return { success: false, error: 'Username must be at least 2 characters.' };
  }
  if (!password || password.length < 3) {
    return { success: false, error: 'Password must be at least 3 characters.' };
  }

  // Check if user already exists
  const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
  if (existing) {
    return { success: false, error: 'Username already taken.' };
  }

  const salt = crypto.randomBytes(16).toString('hex');
  const passwordHash = hashPassword(password, salt);

  const insertUser = db.prepare('INSERT INTO users (username, password_hash, salt) VALUES (?, ?, ?)');
  const userResult = insertUser.run(username, passwordHash, salt);
  const userId = Number(userResult.lastInsertRowid);

  const validClass = (classType || 'warrior').toLowerCase();
  const base = classBaseline(validClass);
  const { str, vit, agi, int, hp, maxHp, energy, maxEnergy, hpPots, mpPots } = base;
  const defaultSkin = base.skin;

  const finalSkin = skin !== null && skin !== undefined ? skin : defaultSkin;

  // Create initial character
  const insertChar = db.prepare(`
    INSERT INTO characters (
      user_id, name, class_type, skin, level, xp,
      stat_str, stat_vit, stat_agi, stat_int, stat_points,
      hp, max_hp, energy, max_energy, pos_x, pos_y
    ) VALUES (?, ?, ?, ?, 1, 0, ?, ?, ?, ?, 0, ?, ?, ?, ?, 0, 0)
  `);
  insertChar.run(userId, username, validClass, finalSkin, str, vit, agi, int, hp, maxHp, energy, maxEnergy);

  // Add starter items
  const insertInv = db.prepare(`
    INSERT INTO inventory (user_id, slot_index, item_id, item_name, item_type, quantity)
    VALUES (?, ?, ?, ?, ?, ?)
  `);
  insertInv.run(userId, 0, 'potion_hp', 'Health Potion', 'consumable', hpPots);
  insertInv.run(userId, 1, 'potion_mp', 'Energy Potion', 'consumable', mpPots);

  return loginUser(username, password);
}

function loginUser(username, password) {
  username = username.trim();
  const user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
  if (!user) {
    return { success: false, error: 'User not found. Please register first.' };
  }

  const calculatedHash = hashPassword(password, user.salt);
  const isMatch = crypto.timingSafeEqual(
    Buffer.from(calculatedHash, 'hex'),
    Buffer.from(user.password_hash, 'hex')
  );

  if (!isMatch) {
    return { success: false, error: 'Incorrect password.' };
  }

  // Characters that levelled before the server granted points are topped up
  // here, so the panel and the DB agree from the moment they log in.
  reconcileStatPoints(user.id);

  const character = db.prepare('SELECT * FROM characters WHERE user_id = ?').get(user.id);
  const inventoryRows = db.prepare('SELECT * FROM inventory WHERE user_id = ? ORDER BY slot_index ASC').all(user.id);

  // Format 16-slot inventory array
  const inventory = new Array(16).fill(null);
  for (const row of inventoryRows) {
    if (row.slot_index >= 0 && row.slot_index < 16) {
      inventory[row.slot_index] = {
        slot: row.slot_index,
        id: row.item_id,
        name: row.item_name,
        type: row.item_type,
        quantity: row.quantity
      };
    }
  }

  return {
    success: true,
    user: { id: user.id, username: user.username },
    character: {
      name: character.name,
      class_type: character.class_type || 'warrior',
      skin: character.skin,
      level: character.level,
      xp: character.xp,
      str: character.stat_str,
      vit: character.stat_vit,
      agi: character.stat_agi,
      int: character.stat_int,
      stat_points: character.stat_points,
      hp: character.hp,
      max_hp: character.max_hp,
      energy: character.energy,
      max_energy: character.max_energy,
      pos: [character.pos_x, character.pos_y]
    },
    inventory
  };
}

function saveCharacter(userId, charData) {
  const stmt = db.prepare(`
    UPDATE characters SET
      level = ?, xp = ?,
      stat_str = ?, stat_vit = ?, stat_agi = ?, stat_int = ?, stat_points = ?,
      hp = ?, max_hp = ?, energy = ?, max_energy = ?,
      pos_x = ?, pos_y = ?
    WHERE user_id = ?
  `);
  stmt.run(
    charData.level ?? 1, charData.xp ?? 0,
    charData.str ?? 10, charData.vit ?? 10, charData.agi ?? 10, charData.int ?? 10, charData.stat_points ?? 0,
    charData.hp ?? 100, charData.max_hp ?? 100, charData.energy ?? 50, charData.max_energy ?? 50,
    charData.pos ? charData.pos[0] : 0, charData.pos ? charData.pos[1] : 0,
    userId
  );
}

const POINTS_PER_LEVEL = 3;

/**
 * Starting attributes per class. Used both when creating a character and when
 * working out how many attribute points an existing one has already spent.
 */
const CLASS_BASELINES = {
  warrior: { str: 14, vit: 12, agi: 9,  int: 5,  hp: 180, maxHp: 180, energy: 60,  maxEnergy: 60,  skin: 0, hpPots: 3, mpPots: 1 },
  mage:    { str: 5,  vit: 8,  agi: 9,  int: 16, hp: 120, maxHp: 120, energy: 120, maxEnergy: 120, skin: 1, hpPots: 1, mpPots: 3 },
  archer:  { str: 10, vit: 10, agi: 15, int: 7,  hp: 140, maxHp: 140, energy: 80,  maxEnergy: 80,  skin: 2, hpPots: 2, mpPots: 2 }
};

function classBaseline(classType) {
  return CLASS_BASELINES[(classType || 'warrior').toLowerCase()] || CLASS_BASELINES.warrior;
}

/**
 * Backfill attribute points for characters that levelled before the server
 * started granting them (see grantLevelPoints).
 *
 * Derived from level rather than added blindly, and it subtracts what has
 * already been spent, so it is idempotent: running it twice grants nothing the
 * second time.
 */
function reconcileStatPoints(userId) {
  const char = db.prepare('SELECT * FROM characters WHERE user_id = ?').get(userId);
  if (!char) return { granted: 0 };

  const base = classBaseline(char.class_type);
  const spent = Math.max(0,
    (char.stat_str - base.str) + (char.stat_vit - base.vit) +
    (char.stat_agi - base.agi) + (char.stat_int - base.int));
  const earned = Math.max(0, char.level - 1) * POINTS_PER_LEVEL;
  const owed = earned - spent - char.stat_points;

  if (owed <= 0) return { granted: 0 };

  db.prepare('UPDATE characters SET stat_points = stat_points + ? WHERE user_id = ?')
    .run(owed, userId);
  console.log(`[Backfill] user ${userId}: Lv.${char.level} -> +${owed} attribute points`);
  return { granted: owed };
}

/**
 * Character payload sent to the client.
 * MUST include class_type: GameState.load_character_stats() defaults a missing
 * one to "warrior", which would silently re-class the player.
 */
function characterPayload(row) {
  return {
    class_type: row.class_type,
    level: row.level,
    xp: row.xp,
    str: row.stat_str,
    vit: row.stat_vit,
    agi: row.stat_agi,
    int: row.stat_int,
    stat_points: row.stat_points,
    hp: row.hp,
    max_hp: row.max_hp,
    energy: row.energy,
    max_energy: row.max_energy
  };
}

/**
 * Levelling grants attribute points. The client raises its own level locally,
 * so the points have to be derived server-side from the reported level rather
 * than taken on trust as a point count.
 */
function grantLevelPoints(userId, reportedLevel) {
  const char = db.prepare('SELECT * FROM characters WHERE user_id = ?').get(userId);
  if (!char) return { success: false, error: 'Character not found.' };

  const level = Math.max(1, Math.min(Math.floor(Number(reportedLevel) || 1), 999));
  if (level <= char.level) return { success: false, error: 'Not a level increase.' };

  const gained = (level - char.level) * POINTS_PER_LEVEL;
  db.prepare('UPDATE characters SET level = ?, stat_points = stat_points + ? WHERE user_id = ?')
    .run(level, gained, userId);

  const updated = db.prepare('SELECT * FROM characters WHERE user_id = ?').get(userId);
  return { success: true, gained, character: characterPayload(updated) };
}

function allocateStat(userId, statName) {
  const char = db.prepare('SELECT * FROM characters WHERE user_id = ?').get(userId);
  if (!char || char.stat_points <= 0) {
    return { success: false, error: 'No stat points available.' };
  }

  let updateCol = '';
  if (statName === 'str') updateCol = 'stat_str = stat_str + 1';
  else if (statName === 'vit') updateCol = 'stat_vit = stat_vit + 1, max_hp = max_hp + 10, hp = hp + 10';
  else if (statName === 'agi') updateCol = 'stat_agi = stat_agi + 1';
  else if (statName === 'int') updateCol = 'stat_int = stat_int + 1, max_energy = max_energy + 5, energy = energy + 5';
  else return { success: false, error: 'Invalid stat name.' };

  db.exec(`
    UPDATE characters SET
      ${updateCol},
      stat_points = stat_points - 1
    WHERE user_id = ${userId}
  `);

  const updatedChar = db.prepare('SELECT * FROM characters WHERE user_id = ?').get(userId);
  return { success: true, character: characterPayload(updatedChar) };
}

function addInventoryItem(userId, item) {
  const itemType = item.slot_type || item.type || 'item';
  const itemName = item.name || 'Item';
  const itemId = item.id || 'unknown';
  const itemQty = item.quantity || 1;

  // If stackable (consumable/gold), try to find existing slot
  if (itemType === 'consumable' || itemType === 'currency') {
    const existing = db.prepare('SELECT * FROM inventory WHERE user_id = ? AND item_id = ?').get(userId, itemId);
    if (existing) {
      db.prepare('UPDATE inventory SET quantity = quantity + ? WHERE id = ?').run(itemQty, existing.id);
      return getFullInventory(userId);
    }
  }

  // Find first empty slot (0 to 15)
  const occupiedSlots = db.prepare('SELECT slot_index FROM inventory WHERE user_id = ?').all(userId).map(r => r.slot_index);
  let emptySlot = -1;
  for (let i = 0; i < 16; i++) {
    if (!occupiedSlots.includes(i)) {
      emptySlot = i;
      break;
    }
  }

  if (emptySlot === -1) {
    return { success: false, error: 'Bag is full!' };
  }

  db.prepare(`
    INSERT INTO inventory (user_id, slot_index, item_id, item_name, item_type, quantity)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(userId, emptySlot, itemId, itemName, itemType, itemQty);

  return getFullInventory(userId);
}

function useInventoryItem(userId, slotIndex) {
  const item = db.prepare('SELECT * FROM inventory WHERE user_id = ? AND slot_index = ?').get(userId, slotIndex);
  if (!item) {
    return { success: false, error: 'Item not found in slot.' };
  }

  const itemId = item.item_id;
  const itemType = item.item_type;

  if (itemType === 'consumable') {
    if (item.quantity > 1) {
      db.prepare('UPDATE inventory SET quantity = quantity - 1 WHERE id = ?').run(item.id);
    } else {
      db.prepare('DELETE FROM inventory WHERE id = ?').run(item.id);
    }
  }

  const inventory = getFullInventory(userId);
  return {
    success: true,
    used_item_id: itemId,
    inventory: inventory.inventory
  };
}

function getFullInventory(userId) {
  const rows = db.prepare('SELECT * FROM inventory WHERE user_id = ? ORDER BY slot_index ASC').all(userId);
  const inventory = new Array(16).fill(null);
  for (const row of rows) {
    if (row.slot_index >= 0 && row.slot_index < 16) {
      inventory[row.slot_index] = {
        slot: row.slot_index,
        id: row.item_id,
        name: row.item_name,
        type: row.item_type,
        quantity: row.quantity
      };
    }
  }
  return { success: true, inventory };
}

module.exports = {
  db,
  registerUser,
  loginUser,
  saveCharacter,
  allocateStat,
  grantLevelPoints,
  reconcileStatPoints,
  addInventoryItem,
  useInventoryItem,
  getFullInventory
};
