# The Master 1-Shot Prompt for Godot 4 Web Online RPG POC

> **Usage**: Copy and paste the prompt below directly into any state-of-the-art AI assistant (Gemini, Claude, GPT-4, Cursor) to generate a complete, working 2D Web-based Online RPG Proof-of-Concept in Godot 4 in a single turn.

---

```markdown
<SYSTEM_ROLE>
You are an expert game developer and systems architect specializing in Godot Engine 4 (GDScript 2.0) and web networking. Your objective is to build a complete, runnable, 2D Top-Down Online Action RPG Proof-of-Concept (POC) that runs directly inside modern web browsers via WebAssembly/HTML5, with real-time multiplayer over WebSockets, and export presets ready for itch.io and GitHub Pages.
</SYSTEM_ROLE>

<CRITICAL_BROWSER_CONSTRAINTS>
1. NO RAW SOCKETS / ENET: Web browsers cannot establish raw UDP or TCP sockets. You MUST use Godot 4's `WebSocketMultiplayerPeer`.
2. COMPATIBILITY RENDERER: Use `renderer/rendering_method="gl_compatibility"` in `project.godot`. Forward+ and Mobile renderers frequently fail or exhibit shader compilation errors on WebGL2.
3. SINGLE-THREADED EXPORT (Godot 4.3+): Configure `variant/thread_support=false` in `export_presets.cfg` to eliminate Cross-Origin Isolation requirements (COOP/COEP headers). This enables 1-click deployment on itch.io and GitHub Pages.
4. INPUT HANDLING IN BROWSER: In browser canvas, mouse clicks and keyboard focus can lose focus if not configured properly. Ensure `html/focus_canvas_on_start=true`.
</CRITICAL_BROWSER_CONSTRAINTS>

<PROJECT_SPECIFICATION>
Please generate all necessary files, project configuration, and scripts for the following complete project structure:

1. Project Configuration (`project.godot`):
   - Godot 4 format (config_version=5)
   - Autoloads: `SoundManager`, `GameState`, `NetworkManager`
   - Input actions: `move_left`, `move_right`, `move_up`, `move_down`, `attack` (Space/Click), `chat_toggle` (Enter)
   - Display: 1024x576, canvas_items stretch mode, expand aspect

2. Network Layer (`scripts/network/`):
   - `network_manager.gd`: Uses `WebSocketMultiplayerPeer`. Implements `start_host(port)`, `start_client(url)`, and `start_dedicated_server(port)`. Handles peer connected/disconnected signals, player spawning via RPC, and reconnection cleanup.
   - `game_state.gd`: Autoload tracking player directory, names, levels, current/max HP, and real-time chat broadcasts with `@rpc("any_peer", "call_local", "reliable")`.
   - `sound_manager.gd`: Plays retro sound effects for attack, hit, item pickup, level up, and chat blips.

3. Entity Systems (`scripts/entities/` & `scenes/`):
   - `player.gd` + `player.tscn`:
     * Top-down 2D CharacterBody2D with smooth 8-directional movement.
     * Differentiates local player (enabled Camera2D, reads Input) from remote players (smooth lerp interpolation).
     * Nameplate and floating health bar over head.
     * Melee sword slash and ranged magic projectile casting.
     * XP progression, level up stat increases (HP, attack), and visual level-up fanfare.
     * Respawn mechanic upon defeat.
   - `monster.gd` + `monster.tscn`:
     * Server-authoritative Slime monster.
     * Roams/wanders near spawn; aggros on closest player within range.
     * Deals contact damage; takes damage from player attacks with red flash and floating damage numbers.
     * Drops XP gems and health potions upon defeat.
     * Boss variant: "King Slime" with higher health and golden crown.
   - `projectile.gd` + `projectile.tscn`: Magic projectile fired by players that collides with monsters and obstacles.
   - `loot_drop.gd` + `loot_drop.tscn`: Collectible gem/potion with floating bobbing animation.

4. User Interface (`scripts/ui/` & `scenes/`):
   - `lobby_ui.gd`: Modal allowing player to input Nickname, choose Character Class/Skin, enter Server URL (`ws://...`), and click "Host Game", "Join Realm", or "Dedicated Server".
   - `hud.gd`: Displays local HP bar, XP bar, Level, active player count, and connected heroes leaderboard.
   - `chat_box.gd`: In-game chat log with BBCode formatting and auto-scroll. Pressing Enter focuses the input line; pressing Enter again broadcasts the message across all clients.

5. Cloud / Local Server (`server/`):
   - `server.js`: Unified single-port HTTP static host and WebSocket multiplayer server (`ws`). Serves the exported HTML/WASM bundle AND handles real-time WebSockets on the exact same port (`8080` or `process.env.PORT`). Works seamlessly with dev tunnels, ngrok, Render, and Railway without port mismatch.

6. Web Export Configuration (`export_presets.cfg`):
   - Target "Web" with `variant/thread_support=false`, `export_path="dist/index.html"`.
```

---

## Key Technical Details & Best Practices

### 1. WebSocket Multi-client Architecture
```mermaid
graph TD
    A[Web Player 1 (Browser WASM)] -->|WebSocket ws:// or wss://| S[Multiplayer Server / Relay]
    B[Web Player 2 (Browser WASM)] -->|WebSocket ws:// or wss://| S
    C[Web Player N (Mobile / Desktop)] -->|WebSocket ws:// or wss://| S
    S -->|High-Level RPC State Sync| A
    S -->|High-Level RPC State Sync| B
    S -->|High-Level RPC State Sync| C
```

### 2. Free Cloud Server Deployment (Render.com)
1. Push this repository to GitHub.
2. Go to [Render.com](https://render.com) -> New **Web Service**.
3. Set **Root Directory**: `server`
4. Set **Build Command**: `npm install`
5. Set **Start Command**: `node server.js`
6. Render will assign a free URL like: `https://your-rpg-server.onrender.com`.
7. In the Godot Web game lobby, players enter:
   `wss://your-rpg-server.onrender.com`
   *(Notice `wss://` secure WebSockets for HTTPS domains!)*

### 3. Static Web Client Deployment (itch.io)
1. Export the web build using `tools/build_web.ps1` to produce `dist/godot_web_rpg_itch.zip`.
2. Create a new game on [itch.io](https://itch.io).
3. Under **Kind of project**, select **HTML**.
4. Upload `godot_web_rpg_itch.zip` and check the checkbox **This file will be played in the browser**.
5. Set Viewport dimensions: `1024` x `576`.
6. Click Save & View!
