/**
 * Unified Game Web Host & WebSocket Multiplayer Server
 * Serves the exported Godot Web files (dist/) AND handles WebSocket multiplayer on the SAME PORT.
 * Handles Host Authority election for synchronized monsters and persistent player stats.
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer, WebSocket } = require('ws');
const db = require('./db');

const PORT = process.env.PORT || 8080;
const DIST_DIR = path.resolve(__dirname, '../dist');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.json': 'application/json',
  '.css': 'text/css',
  '.wav': 'audio/wav',
  '.zip': 'application/zip'
};

// In-memory player state
const players = new Map();
let nextClientId = 100;
let hostClientId = null;

// 1. Create HTTP server for both Static Web Files & Health checks
const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  let reqPath = req.url.split('?')[0];

  if (reqPath === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'online',
      service: 'Godot Web RPG Unified Host & WebSocket Server',
      port: PORT,
      clients_connected: wss.clients.size,
      active_players: players.size,
      host_id: hostClientId,
      timestamp: new Date().toISOString()
    }));
    return;
  }

  if (reqPath === '/' || reqPath === '') {
    reqPath = '/index.html';
  }

  const filePath = path.join(DIST_DIR, reqPath);

  if (!filePath.startsWith(DIST_DIR)) {
    res.writeHead(403);
    res.end('Access denied');
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('404 Not Found: ' + reqPath);
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    res.setHeader('Content-Type', contentType);

    // The exported game keeps stable filenames (index.pck / .wasm / .js), so
    // without this the browser happily serves a stale build after a rebuild
    // and the new code silently never runs.
    res.setHeader('Cache-Control', 'no-cache, must-revalidate');

    const stream = fs.createReadStream(filePath);
    stream.pipe(res);
  });
});

// 2. Attach WebSocket Server to the SAME HTTP Server
const wss = new WebSocketServer({ server });

function broadcast(data, excludeWs = null) {
  const jsonStr = typeof data === 'string' ? data : JSON.stringify(data);
  for (const client of wss.clients) {
    if (client !== excludeWs && client.readyState === WebSocket.OPEN) {
      client.send(jsonStr);
    }
  }
}

wss.on('connection', (ws, req) => {
  const clientId = nextClientId++;
  ws.clientId = clientId;
  const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

  if (hostClientId === null) {
    hostClientId = clientId;
    console.log(`[Host] Client ${clientId} elected as room host.`);
  }

  const isHost = (hostClientId === clientId);
  console.log(`[+] WebSocket connected: ID ${clientId} (Host: ${isHost}) from ${clientIp} (Total: ${wss.clients.size})`);

  // Send welcome packet with assigned ID and host authority status
  ws.send(JSON.stringify({
    type: 'welcome',
    id: clientId,
    is_host: isHost
  }));

  ws.on('message', (rawMessage) => {
    try {
      const msg = JSON.parse(rawMessage.toString());

      switch (msg.type) {
        case 'register': {
          const res = db.registerUser(msg.username || '', msg.password || '', msg.class_type || 'warrior', msg.skin);
          if (!res.success) {
            ws.send(JSON.stringify({ type: 'auth_error', error: res.error }));
          } else {
            ws.userId = res.user.id;
            ws.send(JSON.stringify({
              type: 'auth_success',
              user: res.user,
              character: res.character,
              inventory: res.inventory
            }));
          }
          break;
        }

        case 'login': {
          const res = db.loginUser(msg.username || '', msg.password || '');
          if (!res.success) {
            ws.send(JSON.stringify({ type: 'auth_error', error: res.error }));
          } else {
            ws.userId = res.user.id;
            ws.send(JSON.stringify({
              type: 'auth_success',
              user: res.user,
              character: res.character,
              inventory: res.inventory
            }));
          }
          break;
        }

        case 'stat_allocate': {
          if (ws.userId) {
            const res = db.allocateStat(ws.userId, msg.stat);
            if (res.success) {
              ws.send(JSON.stringify({
                type: 'stat_allocated',
                character: res.character
              }));
              if (players.has(clientId)) {
                const p = players.get(clientId);
                p[msg.stat] = res.character[msg.stat];
                p.max_hp = res.character.max_hp;
                p.max_energy = res.character.max_energy;
                p.stat_points = res.character.stat_points;
              }
            } else {
              ws.send(JSON.stringify({ type: 'error_msg', text: res.error }));
            }
          }
          break;
        }

        case 'item_pickup': {
          if (ws.userId && msg.item) {
            const res = db.addInventoryItem(ws.userId, msg.item);
            if (res.success) {
              ws.send(JSON.stringify({
                type: 'inventory_sync',
                inventory: res.inventory
              }));
            } else {
              ws.send(JSON.stringify({ type: 'error_msg', text: res.error }));
            }
          }
          break;
        }

        case 'item_use': {
          if (ws.userId && typeof msg.slot === 'number') {
            const res = db.useInventoryItem(ws.userId, msg.slot);
            if (res.success) {
              ws.send(JSON.stringify({
                type: 'item_used',
                item_id: res.used_item_id,
                inventory: res.inventory
              }));
            }
          }
          break;
        }

        case 'player_join':
          msg.id = clientId;
          players.set(clientId, msg);
          console.log(`[Join] Hero "${msg.name}" (ID: ${clientId}, Lv.${msg.level || 1}) entered the realm.`);

          // Host authority is claimed on connect, but the lobby auto-connects
          // before the player enters the world -- so a tab left sitting on the
          // login screen can hold authority and never simulate anything.
          // Browsers also throttle background tabs, which stalls monster AI and
          // respawn for everyone. Hand authority to a client that has actually
          // joined.
          if (hostClientId === null || !players.has(hostClientId)) {
            const previousHost = hostClientId;
            hostClientId = clientId;
            if (previousHost !== null && previousHost !== clientId) {
              for (const c of wss.clients) {
                if (c.clientId === previousHost && c.readyState === WebSocket.OPEN) {
                  c.send(JSON.stringify({ type: 'host_revoked' }));
                }
              }
            }
            if (previousHost !== clientId) {
              ws.send(JSON.stringify({ type: 'host_promoted' }));
              console.log(`[Host] Client ${clientId} promoted (previous host ${previousHost} had not joined).`);
            }
          }

          // Send list of all existing players with up-to-date levels to new player
          const existing = [];
          for (const [pid, pdata] of players.entries()) {
            if (pid !== clientId) {
              existing.push(pdata);
            }
          }
          ws.send(JSON.stringify({
            type: 'existing_players',
            players: existing
          }));

          broadcast(msg, ws);
          break;

        case 'move':
          msg.id = clientId;
          if (players.has(clientId)) {
            const p = players.get(clientId);
            p.pos = msg.pos;
            p.flip = msg.flip;
          }
          broadcast(msg, ws);
          break;

        case 'stat_sync':
          msg.id = clientId;
          if (players.has(clientId)) {
            const p = players.get(clientId);
            p[msg.stat] = msg.val;
            console.log(`[Stat] Hero ID ${clientId} updated ${msg.stat} -> ${msg.val}`);
          }
          // Levelling happens client-side, but the attribute points it earns
          // must be granted here -- the DB is what allocateStat() checks, and
          // without this every allocation is rejected as "no points available".
          if (msg.stat === 'level' && ws.userId) {
            const lvl = db.grantLevelPoints(ws.userId, msg.val);
            if (lvl.success) {
              console.log(`[Level] Hero ID ${clientId} -> Lv.${msg.val} (+${lvl.gained} points)`);
              ws.send(JSON.stringify({ type: 'stat_allocated', character: lvl.character }));
            }
          }
          broadcast(msg, ws);
          break;

        case 'monsters_sync':
          // Host broadcasts authoritative monster coordinates and state
          broadcast(msg, ws);
          break;

        case 'chat':
          console.log(`[Chat] ${msg.sender}: ${msg.text}`);
          broadcast(msg);
          break;

        case 'attack':
        case 'take_damage':
        case 'heal':
        case 'monster_hit':
          msg.sender_id = clientId;
          broadcast(msg, ws);
          break;

        case 'roll':
          msg.id = clientId;
          broadcast(msg, ws);
          break;

        case 'pk_toggle':
          msg.id = clientId;
          if (players.has(clientId)) {
            players.get(clientId).is_pk = msg.enabled;
          }
          broadcast(msg);
          break;

        case 'player_died': {
          msg.victim_id = clientId;
          if (msg.is_pk && msg.attacker_id) {
            // Roll 50% chance to drop unbound item from victim's inventory
            const rollSuccess = Math.random() < 0.5;
            if (rollSuccess && ws.userId) {
              const inv = db.getUserInventory(ws.userId);
              const items = inv.filter(it => it != null);
              if (items.length > 0) {
                const dropped = items[Math.floor(Math.random() * items.length)];
                db.useInventoryItem(ws.userId, dropped.slot);
                broadcast({
                  type: 'loot_dropped',
                  item: dropped,
                  pos: players.get(clientId)?.pos || [0, 0]
                });
                broadcast({
                  type: 'chat',
                  sender: 'SYSTEM',
                  text: `[PK] A PvP fatality occurred! ${dropped.name} was dropped!`,
                  is_sys: true
                });
              }
            }
          }
          broadcast(msg, ws);
          break;
        }

        default:
          broadcast(msg, ws);
          break;
      }
    } catch (err) {
      console.error(`[!] Error parsing message from ${clientId}:`, err.message);
    }
  });

  ws.on('close', (code) => {
    console.log(`[-] Client ${clientId} disconnected (code: ${code})`);
    if (players.has(clientId)) {
      const p = players.get(clientId);
      if (ws.userId) {
        db.saveCharacter(ws.userId, {
          level: p.level || 1,
          xp: p.xp || 0,
          str: p.str || 10,
          vit: p.vit || 10,
          agi: p.agi || 10,
          int: p.int || 10,
          stat_points: p.stat_points || 0,
          hp: p.hp || 100,
          max_hp: p.max_hp || 100,
          energy: p.energy || 50,
          max_energy: p.max_energy || 50,
          pos: p.pos || [0, 0]
        });
      }
      players.delete(clientId);
      broadcast({
        type: 'player_leave',
        id: clientId,
        name: p.name
      });
    }

    // Elect new host if current host disconnected
    if (hostClientId === clientId) {
      hostClientId = null;
      for (const client of wss.clients) {
        if (client.readyState === WebSocket.OPEN && client.clientId) {
          hostClientId = client.clientId;
          client.send(JSON.stringify({ type: 'host_promoted' }));
          console.log(`[Host] Promoted Client ${hostClientId} to new room host.`);
          break;
        }
      }
    }
  });

  ws.on('error', (err) => {
    console.error(`[!] WebSocket error on client ${clientId}:`, err.message);
  });
});

server.listen(PORT, () => {
  console.log(`========================================================`);
  console.log(`⚔️ Godot Web RPG Unified Server running on port ${PORT}`);
  console.log(`🎮 Web Client URL: http://localhost:${PORT}`);
  console.log(`🔌 WebSocket URL:  ws://localhost:${PORT}`);
  console.log(`🌐 Health check:   http://localhost:${PORT}/health`);
  console.log(`========================================================`);
});
