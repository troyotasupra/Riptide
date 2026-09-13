# Riptide

Co-op (1–6 players) survival on a hostile modern sea. Start on an island with a
raft, push out to procedurally generated islands, find better boats and
Delta Force-style gear, and hold on to it when modern pirates come for it.

Built in **Godot 4.7** (GDScript). Low-poly art, characters and sound effects are
generated in code or come from CC0 packs (see Credits).

## Play

- **From source:** `C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe --path C:\src\riptide`
- **Standalone build:** `powershell -File tools\build.ps1` makes `build\Riptide.exe`.
  That single file is the whole game — send it to friends.

On the menu, set your name, open **Character** to make your crew member (and pick
the crew colour and emblem you fly when you host), then **Host new world** or
**Continue saved world**. The host autosaves every 2 minutes and when leaving.

## Playing with friends over the internet (Tailscale)

1. Everyone installs [Tailscale](https://tailscale.com/download) and signs in.
2. The host invites friends to their tailnet (Tailscale admin console → *Share* or *Users → Invite*).
3. The host opens the game, hosts, and reads their **100.x.x.x** address from the
   Tailscale tray icon (the pause menu also lists addresses).
4. Friends type that 100.x.x.x address on the menu and press **Join crew** (port 24570).

No router port forwarding is needed. On the same Wi-Fi you can skip Tailscale and
use the host's LAN address instead. If Windows Firewall asks, allow Riptide on
private networks.

## Controls

| Keyboard / mouse | Controller | Action |
| --- | --- | --- |
| WASD / mouse | Left / right stick | Move / look |
| Space | A | Jump · climb out of water |
| C | B | Crouch |
| Shift | L3 | Sprint · pull hard while paddling |
| E (hold) | X (hold) | Interact · gather |
| Left click | RT | Use item · swing a tool · build |
| R | D-pad → | Rotate the structure you're placing |
| 1–8 / wheel | LB / RB | Hotbar |
| Q | D-pad ↓ | Drop the held item |
| G | D-pad ↑ | Give the held item to the crewmate you're looking at |
| F | Y | Paddle a raft |
| Tab | View | Inventory (gear, pockets/rig/backpack grids, hotbar, open container) |

Inventory: drag items between grids, the hotbar and containers · R (or RB) rotates
while dragging · Shift-drag moves half a stack · Ctrl-click or double-click sends an
item across (pack ⇄ container) · right-click for actions (use, wear, split, drop) ·
drag outside the panels to drop. On a controller: A pick up/place, Y send across,
X actions, B cancel.
| B | D-pad ← | Survival book (crafting) |
| Esc | Menu | Pause · settings · save and leave |
| F3 | — | Debug info |

In the backpack: right-click (X) splits a stack, shift-click (Y) moves between
hotbar and pack, Q (LT) drops. Click an item, then a "Wearing" slot to put it on.

## Tests

```
C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path C:\src\riptide --script res://tests/run_tests.gd
```

Scripted in-world checks: `-- --host --profile=testhost --spawn=boat --scenario=camp`
(host) and `-- --join=127.0.0.1 --profile=testcrew --scenario=client` (second copy).
Test runs use their own save file and profiles, never your real ones.

## Layout

- `autoload/` — `Net` (sessions, roster), `Settings`, `Profile` (id, name, look), `Sound`, `SaveGame`, `Ocean`, `GameState`, `Controls` (keyboard + controller)
- `data/` — items, recipes, resources, structures, notes, character appearance options
- `ocean/` — Gerstner waves (`waves.gd` and `water.gdshader` must match)
- `boats/` — buoyant boats, the deck-proxy trick for walking on moving decks, the moored sailboat
- `player/` — first-person controller, code-built character model and view model, survival, inventory, equipment
- `world/` — islands, props, camp systems (containers, fires, structures, bags, sleep), objectives
- `ui/` — menu, character creator, HUD, panels, pause and settings
- `tests/` — headless logic tests

## Credits

- Sound effects: [Kenney](https://kenney.nl) — Impact Sounds, RPG Audio, Interface Sounds (CC0)
- Ocean ambience: "Sea and river wave sounds" on [OpenGameArt](https://opengameart.org/content/sea-and-river-wave-sounds) (CC0)
