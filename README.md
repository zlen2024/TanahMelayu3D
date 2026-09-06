# ⚔️ Godot 4 Web Online RPG Proof-of-Concept (POC)

A high-performance, web-deployable 2D Top-Down Multiplayer Action RPG built with **Godot 4.3** and **GDScript 2.0**, featuring real-time multiplayer over **WebSockets**, synchronized combat, monster AI, leveling, and in-game chat.

Built to be **1-shot prompted**, tested locally in multiple browser tabs, and deployed to **itch.io**, **GitHub Pages**, and **Render** with zero friction.

---

## 🌟 Key Features

- **Web Browser Native (WebAssembly)**:
  - Runs in Chrome, Firefox, Edge, Safari, and mobile web browsers without plugins.
  - **Single-Threaded Export (Godot 4.3)**: No need for Cross-Origin-Opener-Policy (`COOP`) or Cross-Origin-Embedder-Policy (`COEP`) headers. Runs on any static web host.
- **WebSocket Multiplayer Architecture**:
  - Uses Godot 4's `WebSocketMultiplayerPeer` (since web browsers do not support raw UDP/ENet sockets).
  - High-Level Multiplayer RPC synchronization (`@rpc`) for smooth movement interpolation and zero-lag experience.
- **2D Action RPG Mechanics**:
  - 8-directional player movement with custom skins (Blue Knight, Red Paladin, Green Ranger).
  - Overhead floating nameplate & real-time health bar.
  - Melee sword slashes & ranged magic projectile attacks (`Shift + Space`).
  - Slime monsters & King Slime Boss with server-authoritative wandering, aggro, pathing, and attacks.
  - Floating combat text (damage numbers, heal popups, and level up fanfares).
  - XP progression system with level up stats scaling (HP and Attack).
  - Collectible loot drops (XP gems and Health potions).
- **In-Game Systems**:
  - Real-time multiplayer chat box with BBCode formatting and auto-scroll.
  - In-game HUD: HP bar, XP progression bar, active player count, and connected heroes leaderboard.
  - Integrated Lobby: Nickname customization, skin selector, server address input, Host, Join, and Dedicated Server modes.
- **Backend & Cloud Deployment**:
  - Ultra-lightweight standalone Node.js WebSocket relay server (`server/server.js`) ready for 1-click deployment on free cloud hosts (Render, Railway, Glitch).
  - Built-in headless Godot server mode for self-hosted VPS environments.

---

## 🎮 Controls

| Action | Desktop Controls |
|---|---|
| **Move** | `W`, `A`, `S`, `D` or Arrow Keys |
| **Melee Attack** | `Spacebar` or `Left Click` |
| **Cast Spell** | `Shift` + `Spacebar` |
| **Chat** | `Enter` (press to type, press again to broadcast) |

---

## 🚀 Quick Start (Local Development)

### 1. Install Dependencies
Ensure you have **Node.js** (v18+) installed:
```powershell
cd server
npm install
cd ..
```

### 2. Start the Unified Server
Run the unified server (serves web files AND handles WebSockets on port 8080):
```powershell
node server/server.js
```
*(Single port: works with local browsers, VS Code dev tunnels, and cloud hosting!)*

### 3. Play Multiplayer in Browser!
1. Open your browser to: [http://localhost:8080](http://localhost:8080)
2. Open a **second tab** or an **incognito window** to the same address.
3. In Tab 1: Enter nickname "Knight_1", click **Join Realm**.
4. In Tab 2: Enter nickname "Ranger_2", click **Join Realm**.
5. Both players will appear in the world together! Move around, swing swords, chat in real-time, and defeat slimes!

---

## 📦 Building the Web Release

To rebuild the Web HTML5/WASM bundle:
```powershell
powershell -ExecutionPolicy Bypass -File tools/build_web.ps1
```
This will automatically:
1. Ensure the Godot 4.3 CLI and export templates are installed.
2. Compile and package the Web release into the `dist/` directory:
   - `dist/index.html`
   - `dist/index.js`
   - `dist/index.wasm`
   - `dist/index.pck`
   - `dist/godot_web_rpg_itch.zip` (pre-packaged for itch.io)

---

## 🌐 Deploying to the Public Web

### Option A: Uploading to itch.io (HTML5 Game)
1. Run `tools/build_web.ps1` to produce `dist/godot_web_rpg_itch.zip`.
2. Go to [itch.io](https://itch.io) -> **Create new project**.
3. Under **Kind of project**, choose **HTML**.
4. Upload `godot_web_rpg_itch.zip` and check the checkbox **This file will be played in the browser**.
5. Set Viewport dimensions: `1024` x `576`.
6. Click **Save & View Page**!

### Option B: Hosting the WebSocket Backend for FREE on Render.com
1. Fork or push this repository to GitHub.
2. Go to [Render.com](https://render.com) and create a **New Web Service**.
3. Connect your repository.
4. Settings:
   - **Root Directory**: `server`
   - **Build Command**: `npm install`
   - **Start Command**: `node server.js`
5. Render provides a free HTTPS/WSS URL like:
   `https://your-rpg-server.onrender.com`
6. In your web game lobby, enter:
   `wss://your-rpg-server.onrender.com`
   *(Always use `wss://` on HTTPS sites)*

---

## 🤖 1-Shot Prompting
Want to recreate or extend this project using AI? Check out [`ONE_SHOT_PROMPT.md`](ONE_SHOT_PROMPT.md) for the master prompt specifications, architectural blueprints, and prompt engineering instructions.
