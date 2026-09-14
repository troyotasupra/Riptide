# Riptide

Co-op (1–6 players) survival on a hostile modern sea. Wash up on a small island
with nothing, build a raft and oars, row to bigger procedurally generated
islands, find better boats and Delta Force-style gear, and hold on to it when
modern pirates come for it.

**Getting started:** gather fiber, flint and driftwood; twist rope and make a stone
hatchet in the crafting book (B); chop a tree for logs; carve an oar; place a raft
frame on the beach, add 6 logs and 3 rope, then hold E to push it into the water.
Row toward the smoke on the big island — the fishing shack by its dock has a
survival book, a bunk, a locked footlocker, and a john boat tied up outside.

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
| Shift | L3 | Sprint · pull hard while rowing |
| E (hold) | X (hold) | Interact · gather |
| Left click | RT | Use item · swing a tool · build |
| R | D-pad → | Rotate the structure you're placing |
| 1–8 / wheel | LB / RB | Hotbar |
| Q | D-pad ↓ | Drop the held item |
| G | D-pad ↑ | Give the held item to the crewmate you're looking at |
| F | Y | Take / let go of the oars (you need an oar in your pack) |
| Q / E while rowing | LT / RT while rowing | Stroke the left / right oar — both to go straight; hold S (stick back) to back-row |
| Tab | View | Inventory (gear, pockets/rig/backpack grids, hotbar, open container) |
| B | D-pad ← | Crafting / survival book |
| Esc | Menu | Pause · settings · save and leave |
| F3 | — | Debug info |

Sharks patrol the open water between the islands and the reef. They only go after
people in the water — never anyone aboard a boat, never in the shallows. Strike
them with a spear, machete, hatchet or knife (look at one, left click); a dead
shark leaves meat floating in a bag. At 0 health you're **downed**: crawl, and a
crewmate can hold E on you to revive you before you bleed out (60 s; alone, you
black out after a few seconds). Bitten too often — or bitten while down — a shark
can take a limb for good. A torn page at the castaway camp teaches peg legs and
hook hands (use one from your inventory to strap it on).

Rowing: plain strokes cost no stamina (you even catch your breath slowly); Shift
pulls harder for about 20 seconds of a full stamina bar. Two crewmates sitting on
opposite sides each work their own side's oar.

Inventory: drag items between grids, the hotbar and containers · R (or RB) rotates
while dragging · Shift-drag moves half a stack · Ctrl-click or double-click sends an
item across (pack ⇄ container) · right-click for actions (use, wear, split, drop) ·
drag outside the panels to drop. On a controller: A pick up/place, Y send across,
X actions, B cancel.

## Tests

```
C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path C:\src\riptide --script res://tests/run_tests.gd
```

Scripted in-world checks: `-- --host --profile=teststart --scenario=starter` (starter
island → raft → rowing → john boat), `-- --host --profile=testhost --spawn=shack --scenario=camp`
(host) and `-- --join=127.0.0.1 --profile=testcrew --scenario=client` (second copy).
Screenshots: `--scenario=dock|structures|lineup|inventory` with `--shot=file.png`.
Test runs use their own save file and profiles, never your real ones.

## Layout

- `autoload/` — `Net` (sessions, roster), `Settings`, `Profile` (id, name, look), `Sound`, `SaveGame`, `Ocean`, `GameState`, `Controls` (keyboard + controller)
- `data/` — items, recipes, resources, structures, notes, character appearance options
- `ocean/` — Gerstner waves (`waves.gd` and `water.gdshader` must match)
- `boats/` — buoyant boats, the deck-proxy trick for walking on moving decks, left/right oar rowing, mooring lines, the raft and the john boat
- `player/` — first-person controller, code-built character model and view model, survival, inventory, equipment
- `world/` — islands, props, camp systems (containers, fires, structures, bags, sleep), objectives
- `ui/` — menu, character creator, HUD, panels, pause and settings
- `tests/` — headless logic tests

## Credits

- Sound effects: [Kenney](https://kenney.nl) — Impact Sounds, RPG Audio, Interface Sounds (CC0)
- Ocean ambience: "Sea and river wave sounds" on [OpenGameArt](https://opengameart.org/content/sea-and-river-wave-sounds) (CC0)
