# Play & build with friends over Tailscale (this fork)

This fork runs Mirror Classic fully self-hosted for a small group on a [Tailscale](https://tailscale.com) network. It needs no Firebase, no cloud accounts, and none of the old Mirror servers (those are shut down).

- **Login** is handled by `mirror-web-server` itself. Users are stored in MongoDB and tokens are signed with `LOCAL_AUTH_SECRET`. Firebase is only used if you set `AUTH_PROVIDER=firebase`.
- **One machine is the host.** It runs the web server (accounts, spaces, assets) and the game server for the space it opens. Everyone else joins that game server over Tailscale.

### Which Godot do I open?

Use **the Mirror fork of Godot that you build with the scripts below** (it reports `4.3.1.rc.mirror`). Don't use stock Godot 4.3, 4.4 or 4.5. The project depends on engine modules that only exist in the fork (`TMSceneSync`, `JBody3D`/Jolt, etc.), so stock Godot fails with errors like `Could not resolve class "MirrorHttpClient"`. Opening the project in a newer Godot also rewrites project files, so don't do it even once.

| OS | Build the editor (one time, ~10–20 min) | Result |
| --- | --- | --- |
| macOS (Apple Silicon) | `./setup-mac.sh` | `godot-engine/bin/MirrorGodot.app` |
| Linux: Arch / Omarchy, Debian/Ubuntu, Fedora | `./setup-linux.sh` | `godot-engine/bin/godot.linuxbsd.editor.x86_64` |
| Windows | `powershell -ExecutionPolicy Bypass -File setup-win.ps1` (requirements are at the top of `scripts/build-engine-windows.ps1`) | `godot-engine\bin\godot.windows.editor.x86_64.exe` |

The scripts fetch the engine source (the `godot-engine` submodule pinned by this repo) and its module submodules, install build dependencies, and compile. Open the resulting editor, click **Import**, choose `mirror-godot-app/project.godot`, let it import, then close and reopen the editor once.

### Everyone: get the code and join the tailnet

```sh
git clone https://github.com/Erscheinung/the-mirror.git
cd the-mirror
git checkout dev
```

Install Tailscale and run `tailscale up` (or use the app). The host shares their machine with friends who are on other tailnets (Tailscale admin console → Machines → Share).

### Host: set up and start the server (macOS or Linux)

```sh
scripts/setup-server.sh      # one time: MongoDB + Redis, Node 22, builds the server, writes mirror-web-server/.env
scripts/start-server.sh      # every session; leave it running (port 9000)
```

- **macOS**: dependencies come from Homebrew. The script trusts MongoDB's official tap (`brew trust mongodb/brew`), which newer Homebrew requires.
- **Linux**: MongoDB and Redis run as docker/podman containers, because MongoDB isn't in Arch's official repos. On Arch/Omarchy run `sudo pacman -S docker && sudo systemctl enable --now docker` first, and use Node 22 (`sudo pacman -S nodejs-lts-jod` or `mise use -g node@22`). The server doesn't run on Node 23+.
- `setup-server.sh` detects your Tailscale IP, writes `mirror-web-server/.env` with freshly generated secrets, and switches your game to the **host** role. `.env` is gitignored. Keep it private and don't commit it.
- On macOS, click **Allow** when the firewall asks about incoming connections for `node` (web server, TCP 9000) and Godot (game server, UDP 27015).

Then open the project in the Mirror editor and press **Play** (F5):

1. Sign up (email and password are only stored on your server) or click **Join as Guest**.
2. Create a space and open it. A headless game server for that space starts on your machine.

### Friends: join the host

```sh
scripts/set-mirror-host.sh <host-tailscale-ip> join                                         # macOS / Linux
powershell -ExecutionPolicy Bypass -File scripts\set-mirror-host.ps1 <host-tailscale-ip> join   # Windows
```

Open the project in the Mirror editor, press **Play**, sign up or click **Join as Guest** (the account lives on the host's server), then open a space. With the **join** role, opening a space connects you to the game server the host has running, so you all build in the same world in real time. You can also type `<host-ip>:27015` into the **Join by IP** panel.

`set-mirror-host.sh` copies a preset from `mirror-godot-app/addons/mirror_internal/env_configs/` (`tailscale-host.cfg` / `tailscale-join.cfg`) to `mirror-godot-app/override.cfg`. That file is gitignored, so each person's role stays local. You can also switch presets from the environment dropdown in the top-right of the editor.

### Working on this branch together

- `git pull` to get each other's code changes. Rebuild the engine only when the `godot-engine` submodule commit changes.
- Things you build in-game (spaces, objects, scripts, uploaded assets) are saved on the host's server (MongoDB and `mirror-web-server/localStorage`), not in git.
- After pulling web server changes, the host reruns `scripts/setup-server.sh` (it keeps the existing `.env`) and restarts `scripts/start-server.sh`.
- If the host's Tailscale IP changes, everyone reruns `set-mirror-host` with the new IP. The host also updates `ASSET_STORAGE_URL` in `.env`.

### Troubleshooting

- **Friends can't connect**: from the friend's machine, check `curl http://<host-ip>:9000/` and `tailscale ping <host-ip>`. Make sure the host's firewall allows `node` and Godot.
- **`SlowBuffer` / `Cannot read properties of undefined` when starting the server**: you're on Node 23+. Use Node 22.
- **Logins stop working after a restart**: `LOCAL_AUTH_SECRET` is missing from `.env`, so a random secret is used each run.
- **Security**: only run this on your tailnet. The game server trusts the user id in a player's token without verifying it (upstream behaviour), and the web server has no rate limiting.
- **Analytics**: the Godot client still sends usage events to the original Mirror Mixpanel/PostHog projects (see the analytics note at the bottom of this README).

# Update, Jul 2025: From Godot to the Next Era

We've announced more details about our new Mirror Engine, a TypeScript game engine. [Sign up for the alpha here](https://mirrorengine.io/alpha-signup).

[![Mirror Engine is a new TypeScript game engine](https://img.youtube.com/vi/knxeNfux4lE/0.jpg)](https://www.youtube.com/watch?v=knxeNfux4lE)

# Update, Nov 2024: Transitioning from Godot

We've made the extremely difficult decision to transition from Godot but we have exciting things in store. Check out our "Thank You & Technical Reflections" below.

Our V2 announcement will first be on Discord: https://mirrorengine.io/discord

After the V2 announcement, this existing code based will be moved to `/mirror-classic` in this repo and "Mirror Classic" will refer to the Godot code. Mirror Classic will remain permissively MIT-licensed and parts of the V2 are planned to be open-core.

[![Video: Transitioning from Godot: Thank You and Technical Reflections](https://img.youtube.com/vi/n_kkiNqAwIU/0.jpg)](https://youtu.be/n_kkiNqAwIU)

# Mirror Classic: Get Started

The **easiest** way is via our compiled Mirror Official app: [Get Started](https://docs.themirror.space/docs/get-started)

## Docs

[The docs site](https://docs.themirror.space/docs/open-source-code/get-started) (`/mirror-docs`) is our primary source of truth for documentation, not this README. We intend to keep this README slim since documentation is and will continue to be extensive.

# Features

- **[(Real) Real-Time Game Development](https://www.themirror.space/blog/real-real-time-game-development)**: Like Inception, the aim is to build worlds in real-time with friends, colleagues, and players. Read more about our approach on our blog [here](https://www.themirror.space/blog/real-real-time-game-development).
- **All-in-one game development**: The Mirror is both the editor and the game, providing everything you need out-of-the-box to quickly create and play games, digital experiences, virtual worlds, and more.
- **Editor**: Built-in and networked: A lightweight, real-time, multiplayer editor to build in real-time.
- **Physics** via [Jolt](https://github.com/jrouwe/JoltPhysics), a AAA physics engine used by Horizon Zero Dawn.
- **Advanced networking**: Keep your game in sync and rewind when things get out of sync.
- **Visual scripting**: Even if you don't know how to code, you can implement game logic quickly and easily.
- **Traditional coding**: GDScript in-world editor so you can live edit your game code. If you're new to GDScript, it's like Python, super newbie-friendly, and is easy to learn.
- **Material editor**: No need to exit the editor to make changes to your materials: Everything is in real-time
- **Shader editing**: Real-time shader editing with text will be available in the future
- **Asset management**: Assets are automatically stored in the cloud or via local storage (self-hosted) so you can simplify your workflows in real-time without needing to restart the editor. Much less hassle and easy collaboration with team members.
- **Open asset system**: Built around GLTF, The Mirror supports seats, lights, equipables, and custom physics shapes, all direct from Blender.
- **Mirror UI elements**, including a table class which can easily map _any_ data to UI elements without duplicating state in a performant way.
- **Collision shape generation**: Convex and concave supported
- **Audio**: Easily add audio to your game in real-time without opening a separate editor; no need to recompile
- **Player controllers**: Out-of-the-box FPS (first-person shooter), TPS (third-person shooter), and VR (virtual reality) supported.
- **VR-ready**: Just put on the tethered headset when playing! We test with Meta Quest 2 and 3.
- **Intentional architecture**: (Space)Objects are a simple game object abstraction with the aim of supporting **any** type of Godot node in the future.
- **Bidirectionality with Godot**: Start in The Mirror and end in Godot, or start in Godt and end in The Mirror. Our aim is to make it easy to transition between the two or develop side-by-side: your choice.
  ![Bidirectionality with Godot](bidirectionality-with-godot.jpg)
- **Godot plugin:** Coming soon

# Join the Community

**1. Join our [Discord](https://discord.com/invite/CK6fH3Cynk)**

**2. Read our docs: [Site](https://docs.themirror.space), [monorepo `/mirror-docs`](https://github.com/the-mirror-gdp/the-mirror/tree/dev/mirror-docs)**

**3. Check out our [open-source announcement post](https://www.themirror.space/blog/freedom-to-own-open-sourcing-the-mirror)**

**4. Subscribe on [Youtube](https://www.youtube.com/@JaredDMcCluskey).**

# What is The Mirror and why?

The Mirror is a Roblox & UEFN alternative, an all-in-one game engine built on Godot.

The goal is to be both the editor and the game, like Inception: build a world with friends in real-time. This saves you a plethora of work: Enjoy not having to worry about infrastructure, backend HTTP routes, websockets, asset management, authentication, netsync, and various systems from scratch.

This repo is The Mirror's source code: the Godot app (client/server), the web server, and the docs in one place. We've included everything we can provide to help you build your games as fast as possible.

## Build the Open-Source Code

1. Git clone the repository (you do **not** need to clone with submodules; they are optional)
2. Build a precompiled Mirror fork of Godot engine: https://github.com/mirror-engine/godot
3. Open the Godot editor (The Mirror fork), click import, and choose the `project.godot` from the `/mirror-godot-app` folder.
   Note that if you see this popup, you can safely ignore it and proceed.

![image](https://github.com/the-mirror-gdp/the-mirror/assets/11920077/53f84e88-aa31-4245-93af-decdec253168)

4. Close the Godot editor and open it again, to ensure that everything loads correctly, now that all files have been imported.
5. **Hit play in the Godot editor!**
6. Create a new Space, and you will automatically join it. Or, join an existing Space.

## Godot Fork

The Mirror is built on a custom fork of Godot and required to use The Mirror's code. The fork is open source and can be found [here](https://github.com/the-mirror-gdp/godot).

_Analytics Disclaimer: We use Posthog and Mixpanel and it automatically collects analytics in the open source repo. You can disable this manually by commenting out the `mirror-godot-app/scripts/autoload/analytics/analytics.gd` file methods. We are transitioning from Posthog to Mixpanel and Posthog will be removed in a future release. We will make this easier in the future to disable. The Mirror Megaverse Inc., a US Delaware C Corp, is the data controller of the Posthog and Mixpanel instances. You are free to disable the analytics and even plug in your own Posthog or Mixpanel API keys to capture the analytics yourself for your games!_
