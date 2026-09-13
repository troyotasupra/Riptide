# Riptide

Co-op (1–6 players) survival on a hostile modern sea. Start on an island with a
raft, push out to procedurally generated islands, find better boats and
Delta Force-style gear, and hold on to it when modern pirates come for it.

Built in **Godot 4.7** (GDScript). Low-poly, generated-in-code art.

## Run it

- Open the project in Godot 4.7 and press Play, or:
  `C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe --path C:\src\riptide`
- **Host crew** on one machine. Friends use **Join crew** with your IP (shown
  on the host's HUD). Default port **24570** (UDP). For play over the internet,
  forward that port or use Tailscale/ZeroTier.
- Quick local co-op test (host + client windows): `powershell -File tools\coop_test.ps1`

## Controls (prototype)

| Key | Action |
| --- | --- |
| WASD | Move |
| Shift | Sprint (uses stamina) |
| Space | Jump · climb out of water |
| C / Ctrl | Crouch |
| E | Interact · hold to gather (faster with a knife or machete) |
| Left click | Use the selected hotbar item (eat, drink, read) · place a structure kit |
| R | Rotate the structure you're placing |
| 1–8 / wheel | Select hotbar slot |
| I | Backpack |
| B | Survival book (crafting) |
| F | Paddle while on a raft (WASD steers, Shift pulls hard for stamina) |
| Esc | Free the mouse (click to recapture) |
| F10 | Leave session |

The camp island is ~650 m from the start beach — steer for the smoke. An abandoned
sailboat is moored in its cove: swim to the stern ladder and climb aboard.

Saves: the host autosaves every 2 minutes and on leaving; **Continue saved world** on the menu.

## Tests

```
C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path C:\src\riptide --script res://tests/run_tests.gd
```

## Layout

- `autoload/` — `Net` (sessions, roster), `Ocean` (shared clock), `GameState`, `Controls`
- `ocean/` — Gerstner waves (`waves.gd` and `water.gdshader` must match)
- `boats/` — buoyant boats and the deck-proxy trick for walking on moving decks
- `player/` — first-person controller, survival rules, loadout math
- `world/` — island generator and the world scene
- `ui/` — menu and HUD
- `tests/` — headless logic tests
