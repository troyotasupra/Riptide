# Riptide handoff (2026-09-18)

This is for a fresh Claude session picking up Riptide. Read it first, then:
- the memory files `riptide-project`, `riptide-quality-bar` and `riptide-desktop-shortcut`
- the plan file: `C:\Users\troyo\.claude\plans\i-want-you-to-cheerful-nygaard.md`. The top section, "2026-09-19 iron it all out quality pass", is the active plan and was approved by Troy.

## Who and what
- **Troy** (they/them) is the designer and playtester. Claude builds the whole game.
- **The game:** Riptide, a co-op modern-pirate survival game.
  - Godot **4.7.2**, GDScript, host-authoritative ENet co-op, first person.
  - Everything is authored as text.
- **Paths:**
  - Repo: `C:\src\riptide`
  - Godot: `C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe`, plus `_console.exe` for tests
- **Troy's standard:** "half-assed" is the recurring complaint. Before calling anything done:
  - inspect it **up close, in first person, from both sides**
  - finish the feature fully (wired, compiled, tested)
  - never judge from a far-off screenshot

## Troy's rules
- **Desktop shortcut:** `C:\Users\troyo\Desktop\Riptide.lnk` runs the **current source** (`--path C:\src\riptide -- --dev`). Every iteration must compile and pass tests, because Troy launches straight from it.
- **Downloads:** ask before downloading anything, listing each file, its source and its size.
  - Assets must be **CC0**, and chosen as the well-liked ones (by downloads and ratings).
  - Credit every asset in `assets/CREDITS.md`.
- **His computer:** never take over his mouse or keyboard. Test windows use `--no-focus --mute`.
- **Test isolation:**
  - Test runs use `--profile=test_a` (or `testhost`) and ports 24600 and up.
  - Delete the scenario save before each scenario: `%APPDATA%\Godot\app_userdata\Riptide\saves\scenario_test.save`.
  - Never touch his real save.
- **Commits:** commit per finished chunk, ending the message with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. There's no GitHub remote; `gh` isn't logged in.
- **Art direction (decided 2026-09-18):** stylized low-poly, from the Quaternius CC0 packs.
  - Terrain keeps the photo textures for now, possibly toned to fit.
  - Troy liked faceted, polygonal fire pieces: big shards mixed with a *few* small chips. Too many chips looked silly.

## Running and testing
```bash
# unit tests (115 passing)
"/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/run_tests.gd
# after adding a new class_name or new assets, rescan first
"/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
# scenarios (print [scenario] PASS/FAIL, then quit)
... --path . --no-focus --mute -- --host --profile=testhost --spawn=shack --scenario=camp --dev --port=24616
... --path . --no-focus --mute -- --host --scenario=guns --dev --profile=test_a --port=24610   # also: walk, starter, outdoors, sharks, gear. EVERY scenario needs --host (the menu never auto-hosts), and add --audio-driver Dummy before --
# screenshots: saved on a delay; --shot-delay=30 for slow views
... --path . --no-focus --mute -- --scenario=look --face=<face> --dev --profile=test_a --port=24617 --shot=<abs path>.png
```
- **Look faces:**
  - `shore`, `spring`, `waterfall`, `shackdoor`, `cooking`, `storm`, `fishing`
  - `gun` (held, first person), `scope`, `guns` or `guns:<id>` (side-on rack)
  - `castaway`, `tentcamp`, `wildfire`
- **Shell gotchas:**
  - Bash heredocs that contain quotes break. Write Python edit scripts to the scratchpad with the Write tool, using `C:/...` paths.
  - Explicit types avoid GDScript "Cannot infer type" errors.

## State at handoff
**Last commit:** `4dace67`, containing:
- the CC0 photo textures and the terrain splat shader
- the fire system
- staged tents and campfires
- dismantling (hold Z)
- guns firing on left click
- the footlocker moved to the foot of the bunk

**Uncommitted, and live in Troy's shortcut build:**
- **`assets/models/`:** 17 approved Quaternius CC0 GLBs, about 9 MB. Sources are listed below; add them to CREDITS.
  - `guns/`: pistol, smg, smg_alt, assault_rifle, shotgun, shotgun_alt, sniper
  - `nature/`: palm_trees (a set of 5), palm_curved, palm, tree_umbrella, tree_leafy, trees (a set of 5), bush_berries, bush, bushes (a set), flower_bushes (a set)
  - They come from static.poly.pizza. The model pages are poly.pizza/m/<id>: Jyn9qex4ba, nsP3JukU73, 7ehatxr7FY, Bgvuu4CUMV, ZmPTnh7njL, DcNE0HVdW8, i65hEldsw6, VYslw9DEi6, nr1B5DbICA, A6cKJYFsIb, 2paAm1ja4w, qZtx0AHhcy, etFGNvsiFv, TSbIxkDtxF, 92EytlU1El, J2h3HrO356, 1X06RgvSr6.
- **`world/model_lib.gd`** (new):
  - `ModelLib.part(path, index, height)`: splits pack files (sets sit about 100–200 m from their origin at 100× scale), bakes the transforms and re-centres each model on the ground.
  - `ModelLib.gun(path, length, muzzle_sign, grip_fraction, anchors)`: lays a gun out the ItemModels way (barrel +Y, sights +Z, grip at the origin) and returns `muzzle`, `rail` and `grip` anchors.
  - It also tunes the packs' materials to a matte finish.
- **`player/item_models.gd`:**
  - `GUN_MODELS` makes `ItemModels.build()` load the GLB guns.
  - Anchors are stored as node metadata, read with `ItemModels.anchor()`.
  - **Not yet checked visually.** The muzzle direction (`1.0` in the table), the grip fractions and the hold pose in `view_model.gd` (tuned for the old models: rotation `(PI-0.3,-0.16,0.06)`) all need checking with `--face=guns` and `--face=gun`. Flip the muzzle sign if the guns point backwards.
  - The files are single meshes: no separate slide or magazine, so animate by moving the whole gun and the hands.

## Progress on 2026-09-18 (later session)
- **Step 0 done:** `--scenario=tour --shot-dir=<abs dir> [--face=<stop prefix>]` (world/scenario_tour.gd), 77 stops.
  Launch test windows with `--audio-driver Dummy` before `--`: Troy asked for no sound at all.
  No-focus windows now ignore gamepads, let clicks through, and never save settings.
- **Step 1 done:** guns in two hands (view_model.gd rig + two-bone arms), ADS on the sights, muzzle-anchored
  flash and tracer, Intervention has a built-in 10x scope; palms, trees and berry bushes from the packs;
  burnt trees stand charred (ResourceField.burnt, saved as `resources_burnt`).
- **Audit findings still open (from the tour), by plan step:**
  - Guns (step 2): no view-model render layer yet (clips into walls); no separate slide/bolt/mag motion; attachments not shown; brass; sounds.
  - Tools in hand: the hand is still one blob under the handle (knife, hatchet); give tools the gun hands' grip.
  - Torch: its flame is a flat orange card; use the fire chips and a light.
  - Fire (step 3): paper-petal flames; a campfire in daylight tints the ground orange far too strongly; the wildfire spreads over a whole hillside in under a minute (check the tuning with Troy).
  - Tent (step 4): no dismantle/sleep prompt appeared standing at the door facing it (tent_prompt); front guy line runs across the doorway; blue groundsheet reads as water.
  - World (step 5): razor-straight sand/grass edges; spring and plunge pools are opaque light-blue sheets; waterfall mist is square blocks; castaway camp is hazy by day.
  - Pickups: the machete pokes straight through its stump; the dropped bag is two lumps with a black slab through them.
  - Shack: the lantern is a plain beige box; the pillow is a box.

## 2026-09-19 session: Troy's list (top of the plan file)
- Done and committed:
  - fire: flowing sheets, slow unbroken front
  - waterfall: faceted flowing water
  - controls: F interact, Q/E lean, Z/X scope power
  - tents: sleepable, castaway tent moved back from its fire
  - Stairs helper: a ramp under the treads, used at the shack door and the dock
  - dock widened to 2.6 m
  - shack door that bolts from inside (R)
- Not yet verified: the walk scenario on several random seeds (it passed on seed 4242). Run it first.
- Still to do, in order:
  - raft ropes wrapped round the logs
  - oars as boat parts, which act as the key
  - real CC0 gun sounds (ask Troy first) with directional and occluded audio
  - motor quest: cave behind the plunge pool, thief (dagger) and hunter (bow), fuel tanks at the far-side shipwreck, towing the raft

## 2026-09-19 (later): Troy's second list (the plan file's top section), progress
- Done:
  - walking lurch fixed (step-up only re-applies the blocked part of the move)
  - the john boat moored on the dock's cove side (old saves are moved)
  - castaway campfire on the ground, the giant smoke column gone
  - the castaway's key, journal and page in a "Castaway's pack" bag by the tent
  - canteens hold 4 drinks; hunger and thirst drain about half as fast
  - the lighter lights while held, forever; torches burn 30 min
  - gear swaps into the slot the new piece came from
  - whole bags picked up with R (the weight counts) and set down again
  - compost bin (spoiled food turns to soil)
  - smoother rocks, and no boulder pile on the summit
  - real shack windows that open
  - melee swings with a wind-up and a cut, alternating forehand and backhand
  - knife, machete, fishing rod redrawn; new dagger, bow, arrows, outboard
  - THE CAVE behind the waterfall (world/poi/cave_build.gd; the CampIsland cave_* carve), with the dead thief and hunter and the motor, dagger, bow and arrows
  - waterfall rocks at the lip; all fresh water the same colour
  - the chart (M, ui/map_panel.gd): fills in as you explore; full in dev mode
- Still to do from that list:
  - guns with more detail
  - the bow in hand needs a proper draw animation (it uses the gun rig)
  - fitting the outboard to the john boat, plus the fuel-tank shipwreck
- Flaky scenarios, depending on the random world:
  - walk: "let go and you come back up". The dive sometimes doesn't surface in 12 s; this may be a real bug.
  - camp: "pitched a tent frame"
  - guns: "but it gets there" (a 200 m shot)
  - All three pass with --seed=4242.

## 2026-09-19 (third session): the rest of both lists
- Done:
  - swimming no longer gets ducked by the swell (UNDER_MARGIN, tighter float)
  - scenarios no longer fail on luck; 186 checks pass on random worlds
  - boats: oars as the key (fitted in the oarlocks); outboard + fuel + helm (W/S/A/D); tow line; raft cargo
  - the freighter aground on a sandbar in the far reef (world/poi/freighter_wreck.gd), with 5 fuel drums and a gangway
  - raft lashings wrap round the logs (MeshKit.lash)
  - the bow: hip carry, draw to the jaw, arrow flight that sticks
  - guns: blued steel, polymer, walnut, lens; a muzzle crown, receiver stamps, a brass bead
- Left:
  - gun sounds are now synthesised (autoload/gun_audio.gd) with distance delay, occlusion, room/cave reverb and outdoor echoes (Sound.play_shot); if Troy still wants recorded ones, ask before downloading
  - the freighter salvage and the third island (later)

## Next steps (the approved plan, in order)
0. **Build `--scenario=tour`.** It visits many stops in one run and saves each to `--shot-dir`. Stops:
   - each gun in hand: hip, aimed, reloading
   - the tent at each stage: front, back, inside
   - the campfire
   - the castaway camp by day and by night
   - wildfire at 2 m, 15 m and 60 m
   - terrain edges, the pools, the shack, pickups and tools
   - Review every image and list what's wrong.
1. **Wire in the models:**
   - Guns: verify orientation, scale and grip. Fix the view-model pose so the right hand is on the grip, with a left hand on the handguard for long guns. When aimed, the sights should sit at screen centre.
   - Muzzle flash and tracers come from the `muzzle` anchor (`CombatService._report_shot` currently uses eye + look·0.45).
   - Trees, palms and bushes go into `world/props.gd` (`_palm`, `_tree`, `_bush`), keeping the harvest structure: coconuts as harvest parts, the stump when felled, colliders. Burnt trees get a charred look.
2. **Finish the guns:**
   - View model on its own render layer and camera (a SubViewport with a fixed FOV, so it doesn't clip into walls)
   - draw, recoil, and a staged reload/jam animation from whole-gun motion
   - fitted attachments visible at the rail and muzzle anchors
   - inventory right-click to fit or remove attachments (the host side exists: `CombatService.request_fit`)
   - ejected brass
   - gun sounds: Freesound CC0 was down, so ask again; shots still use the placeholder "tree_fall" thud
3. **Fire:**
   - Chunkier, faceted flame pieces; they look like paper petals up close.
   - Flame height by fuel, a glowing ember bed, and a tall column on burning trees.
   - The stove shows flames when lit.
   - Code: `world/fire/` holds `fire_grid.gd` (pure sim), `fire_service.gd` (host plus sync), `wildfire_fx.gd` (one particle system for every burning cell), `fire_fx.gd` (campfire and pit), and `fire_chips.gd` / `fire_chip.gdshader` (shared flame pieces).
4. **Tent and dismantling:**
   - Check that you can walk into the tent.
   - Show the hold-Z progress ring.
   - Let a beached raft be dismantled.
   - Add "Break down" for crafted hand items in the inventory.
5. **World polish:**
   - softer grass/sand blends
   - grass tufts (MultiMesh)
   - real water shading on the spring and plunge pools (currently opaque light blue)
   - the terrain toned toward the stylized look if it clashes with the models
6. **Loose ends:**
   - The camp scenario's "take one item off the fire" check is flaky (cook timing).
   - Delete the unused `assets/textures/painted_metal_004`.
   - Update the README (hold Z, lighting fires with a torch, the dev fire buttons).

## Key code map
- **Networking:**
  - Host-authoritative RPCs use `@rpc("any_peer","call_local","reliable")` and are validated on the host.
  - Broadcasts go through `Net.send_to_ready(node, method, args)`, which doesn't call locally.
- **World:** `world/world.gd` (generation, save/load, sync to new peers).
- **Camp** (`world/camp_systems.gd`), which owns:
  - structures, stations and containers
  - the seeded castaway tent (`CASTAWAY_TENT`)
  - `request_dismantle_start/request_dismantle`, `damage_structure`, `set_structure_burning`
- **Structure data:** `data/structure_table.gd` holds stages, HP, `cost` and `refund` (75% dismantled, 25% collapsed).
- **Structure visuals:** `world/structure_node.gd` (the staged tent and campfire).
- **Materials:** `world/materials.gd` (`textured`, `detail`, and gun materials).
- **Terrain:** `world/terrain/terrain.gdshader` plus `terrain_layers.gd` (per-vertex layer weights in UV/UV2, tint in COLOR, `burn_mask`).
- **Guns:**
  - `player/gun.gd` (client input, recoil, aiming)
  - `world/combat_service.gd` (host bullets)
  - `data/weapon_table.gd`, `data/attachment_table.gd`
  - `items/ballistics.gd`, `items/weapon_math.gd`
- **Dev tools:** `ui/dev_panel.gd` (F1 in `--dev`), dispatched by `world/dev_tools.gd`. Includes gun kit, attachments, and start/put out fire.
- **Tests:** `tests/*.gd`, registered in `tests/run_tests.gd`. Scenario scripts: `world/scenario_driver.gd`.
