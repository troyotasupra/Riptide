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

- **From source (Windows):** `C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe --path C:\src\riptide`
- **From source (macOS):** `/Applications/Godot_v4.7.2.app/Contents/MacOS/Godot --path ~/dev/riptide`
- **Standalone build:** `powershell -ExecutionPolicy Bypass -File tools\build.ps1` makes
  `build\Riptide.exe`. (Windows blocks `.ps1` files by default — that flag applies to
  this one command only and changes nothing on the machine.)
  That single file is the whole game — send it to friends.

On the menu, set your name, open **Character** to make your crew member (and pick
the crew colour and emblem you fly when you host), then **Host new world** or
**Continue saved world**. The host autosaves every 2 minutes and when leaving.

## Playing with friends

Friends connect straight to the host's address. Only the **host** sets anything
up, and only once. Everyone needs the same build of the game — a copy on
different code is turned away with a message saying so.

**On the same Wi-Fi**, nothing needs forwarding. The host presses **Esc** and reads
their address (`192.168.x.x`) off the pause menu; friends type it in and press
**Join crew**.

**Over the internet**, the host forwards one port on their router:

1. Give the host machine a fixed address on the home network — a *DHCP reservation*
   in the router — so the forward doesn't break when the address changes. The pause
   menu (**Esc**) shows the address the game is on now.
2. In the router's admin page, add a port forward:
   - **external port 24570 → internal port 24570**
   - **protocol: UDP.** The game speaks ENet, which is UDP. A TCP-only forward
     looks right and never works.
   - **to:** the host machine's fixed address
3. Let the game through the host's firewall. On Windows, say yes when it asks, for
   private *and* public networks. On macOS, *System Settings → Network → Firewall →
   Options*, and allow incoming connections for Godot (or Riptide).
4. The host finds their public address — search "what is my ip", or run
   `curl https://api.ipify.org`. This is **not** the address in the pause menu,
   which only lists the home network.
5. Friends type that public address and press **Join crew**.

The port is **24570** and a world holds **6 players**. If someone can't get in, the
usual causes in order: the forward is TCP instead of UDP; the host's address on the
home network changed; the firewall is still blocking; or the ISP puts you behind
CGNAT — if the router's own WAN address doesn't match what "what is my ip" says,
nothing can reach you from outside and you'd need a VPN or relay instead.

## Controls

| Keyboard / mouse | Controller | Action |
| --- | --- | --- |
| WASD / mouse | Left / right stick | Move / look |
| Space | A | Jump · swim up when deep · climb out of water |
| C | B | Crouch · dive while swimming |
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
| Left click | RT | Gun: fire |
| Right click (hold) | LT | Gun: aim down the sights |
| R | D-pad → | Gun: reload, or clear a jam |
| X | R3 | Gun: switch fire mode |
| Shift while aiming | L3 | Hold your breath to steady the sights |
| Left click (hold / tap) | RT | Fishing rod: charge and cast · strike · hold to reel |
| Right click | LT | Fishing rod: pick the bait |
| F while fighting a fish | Y | Cut the line |
| Esc | Menu | Pause · settings · save and leave |
| F3 | — | Debug info |
| F1 | — | Developer panel (developer mode only) |
| V | — | Fly (developer mode only) — Space up, C down, Shift fast |

The sea is calm in the shallows — coves, the dock, the beach — and gets rougher the
further out you go, roughest of all in a storm. On the camp island a pool sits high
on the hill and its stream falls over a rock band all the way down to the sea.

Guns: the M1911, Uzi, M4, Mossberg and Intervention, each on its own ammunition —
.45, 9mm, 5.56, 12 gauge and .408 never interchange. Bullets are real: they take
time to reach what you shot at and drop on the way, and every gun is sighted in at
60 m, so at distance you hold over and lead a moving target. The kick climbs while
you hold the trigger and most of it comes back on its own. Attachments (optics,
muzzle devices, grips, magazines, stocks, lasers) fit where they belong and each
one trades something away — a suppressor is quiet but fouls the gun and slows your
sights, an extended magazine holds ten more but takes longer to change. Guns foul
as you shoot; a neglected one jams (R clears it) and a cleaning kit puts it right.
Magnified optics draw the world through the lens, so a scope really is a scope.

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

Swimming: hold C to dive and Space to swim back up, Shift to swim hard. Your breath
lasts about 45 seconds under water and comes back quickly at the surface — run out
and you drown. Stuck in the ground? Esc → Unstuck (and anyone wedged by terrain
loading around them is freed automatically).

Cooking: press E on a fire, the stove or a drying rack with an empty hand to see
what's on it — each slot shows what it's becoming and how long it has left, and you
can take one thing or everything. Hold food, water or firewood and press E to put
something on, or to light it.

Fishing: with the rod in hand, hold left click to charge a cast and let go over
water. Right click picks the bait: grubs (found when you chop trees), berries and
cut bait (knife a sardine or mullet into 4) are used up; a lure or a jig is kept
unless the line snaps. When the bobber dips, click to strike, then hold to reel and
ease off while the fish pulls — too much tension snaps the line, too much slack
and it throws the hook. Reel it all the way in and it lands at your feet, flopping:
press E once to kill it, again to take it. What bites depends on the water (shore, reef, deep), the
bait, the time of day and the weather: sardines, mullet and pufferfish near shore,
snapper, grouper and barracuda on the reef, mahi-mahi and tuna out deep. Every
species you land goes in the fish log in the book. Out deep a shark may take the
fish on your line — hold on, or press F to cut it loose.

Weather: clear skies cloud over, rain sets in and storms roll through, each change
blending in over about 40 seconds. Rain soaks you unless you're under a roof or by a
fire; storms make the sea rougher and colder; wind pushes boats, so tie up or keep rowing.

Inventory: drag items between grids, the hotbar and containers · R (or RB) rotates
while dragging · Shift-drag moves half a stack · Ctrl-click or double-click sends an
item across (pack ⇄ container) · right-click for actions (use, wear, split, drop) ·
drag outside the panels to drop. On a controller: A pick up/place, Y send across,
X actions, B cancel.

## Developer mode

Tick **Developer mode when hosting** on the menu (or start with `-- --dev`). While the
host has it on, everyone in the session gets **F1**, a panel for flying and god
mode, healing, learning every recipe, time of day, weather and wind, teleports
(starter beach, fishing shack, castaway camp, wreck reef, open sea), fishing and
raft kits, spawning or killing sharks, fast bites, and any item by name. **V** flies
through anything.

## Tests

```
C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path C:\src\riptide --script res://tests/run_tests.gd
```

Scripted in-world checks: `-- --host --profile=teststart --scenario=starter` (starter
island → raft → rowing → john boat), `-- --host --profile=testhost --spawn=shack --scenario=camp`
(host) and `-- --join=127.0.0.1 --profile=testcrew --scenario=client` (second copy).
`-- --host --profile=testout --spawn=shack --scenario=outdoors --dev` (developer
tools, flying, weather and wind, rain, fishing), `--scenario=sharks --spawn=camp`.
Start the host with `--dev` and the `client` run checks developer mode from a crew member too.
Screenshots: `--scenario=dock|structures|lineup|inventory` with `--shot=file.png`, and
`--scenario=look --face=tree|tree_under|palm|palm_top|bush|fiber|shore|spring|waterfall|shackdoor|storm|dev|fishing|fish|cooking`.
`--scenario=guns` covers shooting: rate of fire, travel time at 200 m, reloads,
fire modes, attachments, fouling and jams. `--scenario=walk` covers getting about on foot: stepping over ledges, the shack door,
being freed when stuck, diving and breath.
Add `--mute` to silence a run (`--no-focus` runs are always muted).
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
