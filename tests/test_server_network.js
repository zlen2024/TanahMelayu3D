/**
 * Automated Multiplayer Network Test Suite
 * Tests multi-client WebSocket synchronization across players, chat, movement, combat,
 * Host Authority election, level tally synchronization, and monster synchronization.
 */

const { WebSocket } = require('../server/node_modules/ws');
const http = require('http');
const { spawn } = require('child_process');
const path = require('path');

const TEST_PORT = 8099;
const SERVER_URL = `ws://localhost:${TEST_PORT}`;
const HEALTH_URL = `http://localhost:${TEST_PORT}/health`;

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(condition, name) {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  ✅ [PASS] ${name}`);
  } else {
    failedTests++;
    console.error(`  ❌ [FAIL] ${name}`);
  }
}

function startTestServer() {
  return new Promise((resolve) => {
    const serverPath = path.resolve(__dirname, '../server/server.js');
    const child = spawn(process.execPath, [serverPath], {
      env: { ...process.env, PORT: TEST_PORT.toString() },
      stdio: 'pipe'
    });
    child.stdout.on('data', (data) => {
      if (data.toString().includes('running on port')) {
        resolve(child);
      }
    });
    setTimeout(() => resolve(child), 800);
  });
}

async function testHealthEndpoint() {
  console.log('\n--- 1. Testing Server Health Endpoint ---');
  return new Promise((resolve) => {
    http.get(HEALTH_URL, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        assert(res.statusCode === 200, 'HTTP 200 OK returned from /health');
        try {
          const json = JSON.parse(data);
          assert(json.status === 'online', 'Status field is "online"');
          assert(typeof json.clients_connected === 'number', 'clients_connected is reported');
        } catch (e) {
          assert(false, 'Valid JSON returned: ' + e.message);
        }
        resolve();
      });
    }).on('error', (err) => {
      assert(false, 'Health check failed: ' + err.message);
      resolve();
    });
  });
}

async function testMultiplayerFlow() {
  console.log('\n--- 2. Testing Multi-Client Level Tally & Monster Sync ---');
  
  return new Promise((resolve) => {
    const clientA = new WebSocket(SERVER_URL);
    let clientB = null;
    let clientC = null;
    
    let clientA_Id = null;
    let clientB_Id = null;

    clientA.on('open', () => {
      console.log('  [Client A] Connected');
    });

    clientA.on('message', (raw) => {
      const msg = JSON.parse(raw.toString());
      
      if (msg.type === 'welcome') {
        clientA_Id = msg.id;
        assert(clientA_Id > 0, `Client A assigned unique ID (${clientA_Id})`);
        assert(msg.is_host === true, 'Client A (first connected) designated as room host');

        // Client A joins as Level 1
        clientA.send(JSON.stringify({
          type: 'player_join',
          name: 'Knight_Alpha',
          skin: 0,
          pos: [100, 100],
          level: 1
        }));

        // Connect Client B
        clientB = new WebSocket(SERVER_URL);
        
        clientB.on('open', () => {
          console.log('  [Client B] Connected');
        });

        clientB.on('message', (rawB) => {
          const msgB = JSON.parse(rawB.toString());
          
          if (msgB.type === 'welcome') {
            clientB_Id = msgB.id;
            assert(clientB_Id !== clientA_Id, `Client B assigned distinct ID (${clientB_Id})`);
            assert(msgB.is_host === false, 'Client B (secondary) designated as non-host');

            // Client B sends player_join
            clientB.send(JSON.stringify({
              type: 'player_join',
              name: 'Mage_Beta',
              skin: 1,
              pos: [-100, 50],
              level: 1
            }));

            // Client A levels up to Level 5 and broadcasts stat_sync
            setTimeout(() => {
              clientA.send(JSON.stringify({
                type: 'stat_sync',
                stat: 'level',
                val: 5
              }));

              // Client A (Host) broadcasts monster state
              clientA.send(JSON.stringify({
                type: 'monsters_sync',
                monsters: [
                  { idx: 0, pos: [200, -100], flip: true, hp: 60, dead: false }
                ]
              }));
            }, 100);
          }

          // Client B receives stat_sync from Client A
          if (msgB.type === 'stat_sync' && msgB.id === clientA_Id) {
            assert(msgB.stat === 'level' && msgB.val === 5, 'Client B received real-time Level 5 stat_sync for Client A');
          }

          // Client B receives authoritative monster sync from Client A
          if (msgB.type === 'monsters_sync') {
            assert(Array.isArray(msgB.monsters), 'Client B received synchronized monster positions from Host (Client A)');
            assert(msgB.monsters[0].pos[0] === 200, 'Monster 0 synchronized coordinates [200, -100] match');

            // Now test Client C joining late: does it get Knight_Alpha with Level 5?
            clientC = new WebSocket(SERVER_URL);
            clientC.on('message', (rawC) => {
              const msgC = JSON.parse(rawC.toString());
              if (msgC.type === 'existing_players') {
                const alpha = msgC.players.find(p => p.name === 'Knight_Alpha');
                assert(alpha != null, 'Client C received existing players list with Knight_Alpha');
                assert(alpha && alpha.level === 5, 'Client C receives Knight_Alpha with persisted Level 5 (level tally correct!)');

                clientA.close();
                clientB.close();
                clientC.close();
                resolve();
              }
            });
          }
        });
      }
    });

    // Timeout safety
    setTimeout(() => {
      if (clientA.readyState === WebSocket.OPEN) clientA.close();
      if (clientB && clientB.readyState === WebSocket.OPEN) clientB.close();
      if (clientC && clientC.readyState === WebSocket.OPEN) clientC.close();
      resolve();
    }, 6000);
  });
}

async function testAuthAndInventoryFlow() {
  console.log('\n--- 3. Testing SQLite User Registration, Classes & Inventory Persistence ---');
  
  return new Promise((resolve) => {
    const client = new WebSocket(SERVER_URL);
    const testUser = `Hero_${Date.now()}`;
    const testPass = 'Secret123';
    
    client.on('message', (raw) => {
      const msg = JSON.parse(raw.toString());
      
      if (msg.type === 'welcome') {
        // Test Registration as Warrior
        client.send(JSON.stringify({
          type: 'register',
          username: testUser,
          password: testPass,
          class_type: 'warrior'
        }));
      }
      
      if (msg.type === 'auth_success') {
        assert(msg.user && msg.user.username === testUser, 'User registered successfully with SQLite');
        assert(msg.character && msg.character.class_type === 'warrior', 'Character class registered as Warrior');
        assert(msg.character.hp === 180, 'Warrior starting HP matches 180');
        assert(msg.character.energy === 60, 'Warrior starting Energy matches 60');
        assert(Array.isArray(msg.inventory), 'Starter inventory returned');
        assert(msg.inventory[0] && msg.inventory[0].id === 'potion_hp', 'Starter inventory contains Health Potions');

        // Test Picking up an equipment item
        client.send(JSON.stringify({
          type: 'item_pickup',
          item: {
            id: 'sword',
            name: 'Iron Blade (+5 STR)',
            type: 'equipment',
            quantity: 1
          }
        }));
      }

      if (msg.type === 'inventory_sync') {
        const hasSword = msg.inventory.some(it => it && it.id === 'sword');
        assert(hasSword, 'Inventory synced with newly picked up Iron Blade');

        // Test re-login with wrong password
        const clientFail = new WebSocket(SERVER_URL);
        clientFail.on('message', (rawFail) => {
          const msgFail = JSON.parse(rawFail.toString());
          if (msgFail.type === 'welcome') {
            clientFail.send(JSON.stringify({
              type: 'login',
              username: testUser,
              password: 'WrongPassword'
            }));
          }
          if (msgFail.type === 'auth_error') {
            assert(true, 'Login correctly rejected for invalid password');
            clientFail.close();

            // Test re-login with correct password
            const clientSuccess = new WebSocket(SERVER_URL);
            clientSuccess.on('message', (rawSucc) => {
              const msgSucc = JSON.parse(rawSucc.toString());
              if (msgSucc.type === 'welcome') {
                clientSuccess.send(JSON.stringify({
                  type: 'login',
                  username: testUser,
                  password: testPass
                }));
              }
              if (msgSucc.type === 'auth_success') {
                assert(msgSucc.user.username === testUser, 'Re-login succeeded with correct password');
                const persistentSword = msgSucc.inventory.some(it => it && it.id === 'sword');
                assert(persistentSword, 'Inventory items persisted in SQLite across connections');

                client.close();
                clientSuccess.close();
                resolve();
              }
            });
          }
        });
      }
    });

    setTimeout(() => {
      if (client.readyState === WebSocket.OPEN) client.close();
      resolve();
    }, 6000);
  });
}

/**
 * Host authority must belong to a client that has actually entered the world.
 *
 * The lobby auto-connects before the player logs in, and authority is claimed
 * on connect -- so a tab parked on the login screen could hold it and never
 * simulate anything. Browsers additionally throttle background tabs, which
 * stalls monster AI and respawn for every other player.
 */
async function testHostAuthorityTransfer() {
  console.log('');
  console.log('--- 4. Testing Host Authority Transfer (idle lobby client) ---');

  const seen = { idle: [], joiner: [] };
  const connect = (tag) => new Promise((resolve) => {
    const ws = new WebSocket(SERVER_URL);
    ws.on('message', (raw) => seen[tag].push(JSON.parse(raw.toString()).type));
    ws.on('open', () => resolve(ws));
  });

  // First connection wins authority on connect, and then just sits there.
  const idle = await connect('idle');
  await new Promise((r) => setTimeout(r, 250));
  assert(seen.idle.includes('welcome'), 'Idle lobby client receives welcome');

  // Second connection actually joins the world.
  const joiner = await connect('joiner');
  await new Promise((r) => setTimeout(r, 250));
  joiner.send(JSON.stringify({
    type: 'player_join', name: 'Hero_Joiner', skin: 0, pos: [0, 0], level: 1
  }));
  await new Promise((r) => setTimeout(r, 500));

  assert(seen.joiner.includes('host_promoted'),
    'Joining client is promoted to host over the idle lobby client');
  assert(seen.idle.includes('host_revoked'),
    'Idle lobby client has host authority revoked');

  idle.close();
  joiner.close();
  await new Promise((r) => setTimeout(r, 200));
}

async function run() {
  console.log('=======================================================');
  console.log('🌐 RUNNING AUTOMATED SERVER & NETWORK MULTIPLAYER TESTS');
  console.log('=======================================================');

  const testServer = await startTestServer();

  try {
    await testHealthEndpoint();
    await testMultiplayerFlow();
    await testAuthAndInventoryFlow();
    await testHostAuthorityTransfer();
  } finally {
    testServer.kill();
  }

  console.log('\n=======================================================');
  console.log(`📊 SERVER TEST SUMMARY: ${totalTests} Total | ${passedTests} Passed | ${failedTests} Failed`);
  if (failedTests === 0) {
    console.log('🎉 ALL NETWORK MULTIPLAYER TESTS PASSED!');
  } else {
    console.error('❌ SOME NETWORK TESTS FAILED!');
  }
  console.log('=======================================================\n');

  process.exit(failedTests > 0 ? 1 : 0);
}

run();
