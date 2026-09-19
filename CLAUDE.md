# Riptide — working agreement

Read this before touching the repo. It covers how two people (and their agents)
build this game at the same time without breaking each other's work.

Riptide is a 1–6 player co-op survival game: **Godot 4.7, GDScript, first person,
host-authoritative ENet networking.** Everything — models, characters, sound — is
authored in code or is CC0. `README.md` is the player-facing guide.
`HANDOFF.md` is the running log of what was just built and what is next.

## Who is working here

| | Troy (`troyotasupra`) | Josh (`JoshuaGessner`) |
| --- | --- | --- |
| Role | Repo owner, designer, playtester | Developer |
| Machine | Windows, `C:\src\riptide` | macOS, `~/dev/riptide` |
| Godot | `C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe` (+ `_console.exe`) | `/Applications/Godot_v4.7.2.app/Contents/MacOS/Godot` |

**Neither side can see the other's working tree.** Assume the other developer is
editing the same files right now. Everything below follows from that.

**Both machines run Godot 4.7.2-stable.** Patch versions must match: a different
build reimports assets differently, and the result looks like someone else's
commit broke your machine. Check `--version` on both before debugging any import
or `.uid` disagreement. `tools/dev.sh` warns when it finds the wrong version, and
nobody upgrades Godot without telling the other developer first.

---

## Non-negotiables

1. **Never rewrite published history.** No `rebase`, `amend` or `push --force`
   on anything that has reached `origin/main`. `--force-with-lease` is allowed
   only on your own branch that nobody else has pulled.
2. **Never commit `.godot/`.** It is generated, machine-specific and huge.
3. **Every `.gd` file has a sibling `.uid`.** Add, move, rename and delete them
   together, in the same commit. A missing or duplicated `.uid` breaks the other
   machine's import, not yours.
4. **Tests pass before every commit.** All of them, not the ones you touched.
5. **Never take over the user's mouse, keyboard or audio.** Test windows always
   run `--no-focus` with `--audio-driver Dummy`.
6. **Ask before downloading anything.** List each file, its source and its size.
   Assets must be **CC0** and credited in `assets/CREDITS.md`.
7. **Ask before adding a binary over ~1 MB.** The repo is already ~105 MB with no
   Git LFS; every megabyte is cloned by everyone forever.

---

## Landing work

Both developers work on **short-lived branches off `main` and merge by pull
request.** `main` stays green and deployable — Troy launches the game straight
from source, so a broken `main` breaks their playtest.

```bash
# start
git fetch origin
git switch -c josh/oars-as-key origin/main     # <name>/<what-it-does>

# ... work, commit in small pieces ...

# before pushing, always
git fetch origin
git rebase origin/main          # your branch only — never rebase main itself
<run the tests>                 # a clean rebase can still break the build
git push                        # push.autoSetupRemote is configured
gh pr create --fill
```

- **Branch names are prefixed with who owns them:** `josh/…`, `troy/…`. It makes
  an abandoned branch obvious and stops two people claiming one name.
- **Keep branches short.** A branch alive for days is a conflict generator. Land
  a finished chunk, then start the next branch.
- **Say so before a wide refactor.** Anything that renames a `class_name`, moves
  a file, or reformats many files will conflict with whatever the other side has
  open. Agree on it first, land it alone, and land it fast.
- **Do not merge your own PR without the other developer seeing it**, unless they
  have said to go ahead.

### Resolving conflicts

- Never resolve by taking one side wholesale (`--ours` / `--theirs`) in a file
  that both sides genuinely changed. Work out what each change was *for* and keep
  both intents.
- `merge.conflictStyle` is set to `zdiff3`, so the conflict shows the common
  ancestor. Use it — it tells you what each side actually changed.
- **Run the full test suite after every conflict resolution.** A textually clean
  merge of two correct changes is often a broken program.
- If a conflict is beyond you, stop and ask. Do not guess at the other
  developer's intent.

### Files that conflict constantly

Touch these with care; append rather than reorder.

- `project.godot` — the `[autoload]` list. Add at the end.
- `data/*_table.gd` — items, recipes, structures, weapons. Add entries at the end
  of the relevant block.
- `tests/run_tests.gd` — the `SUITES` array. Append.
- `assets/CREDITS.md` — append.
- `HANDOFF.md` — **append a new dated section at the bottom. Never rewrite or
  reformat sections you did not write.** If it conflicts, keep both sides.
- **Never reformat a file you are not otherwise changing.**

---

## Commits

- One finished, coherent chunk per commit. Not one per file, not one per day.
- The subject line says what the player or the code now *does*, in plain English
  and present tense — match the existing log, which reads like release notes.
- Never commit generated output, local saves, screenshots, logs or editor config.
- Review `git status` and `git diff --staged` before every commit. If something
  is in there you did not mean to add, it does not get committed.
- End every commit message with the co-author trailer:

  ```text
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  ```

---

## What goes in git

**In:** `.gd` sources **and their `.uid`**, `.gdshader`, `.tscn`, `.tres`,
`project.godot`, `export_presets.cfg`, asset source files with their `.import`
sidecars, docs, `tools/`.

**Never:** `.godot/`, `build/`, `.DS_Store`, `*.code-workspace`, `.vscode/`,
`.idea/`, logs, screenshots, save files, anything under a user data directory.

`.gitignore` and `.gitattributes` enforce this. `.gitattributes` also pins every
text file to LF so the Windows and macOS sides never fight over line endings — do
not remove it.

> **`export_presets.cfg` is committed and this repository is public.** Godot
> writes signing and notarization credentials into it when you configure a signed
> export (Android keystore password, Apple app-specific password). Read the diff
> before committing a change to that file. If a credential ever lands in it, it
> must be revoked, not just deleted.

Nothing sensitive is in the history today — checked at setup.

---

## The dev loop

Set `GODOT` once per shell, then the commands are identical on both machines.

```bash
# macOS
export GODOT=/Applications/Godot_v4.7.2.app/Contents/MacOS/Godot
# Windows (headless work uses the _console build)
export GODOT="/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
```

`tools/dev.sh` wraps all of this on macOS and Linux (`tools/dev.sh test`,
`tools/dev.sh import`, `tools/dev.sh scenario starter`). `tools/build.ps1` and
`tools/coop_test.ps1` are the Windows equivalents.

**Import — run this after every pull that adds a `class_name`, an asset or a
`.uid`, and on a fresh clone.** Without it scripts fail to resolve each other and
you get a wall of "Identifier not declared" parse errors that are not real bugs:

```bash
"$GODOT" --headless --path . --import
```

**Unit tests** — pure logic, headless, fast. 120 checks; must be 0 failed:

```bash
"$GODOT" --headless --path . --script res://tests/run_tests.gd
```

**Scenarios** — scripted in-world checks that print `[scenario] PASS/FAIL` and
quit. Every scenario needs `--host`; the menu never auto-hosts.

```bash
"$GODOT" --path . --no-focus --audio-driver Dummy -- \
  --host --profile=test_a --port=24610 --seed=4242 --scenario=starter
```

Scenarios: `starter`, `camp`, `client`, `outdoors`, `sharks`, `guns`, `walk`,
`gear`, `tour`. Screenshots use `--scenario=look --face=<face> --shot=<abs>.png`
or `--scenario=tour --shot-dir=<abs dir>`.

- **Test runs must never touch a real save.** Always pass `--profile=test_a` (or
  `testhost`) and a port in your own range — **Troy uses 24600+, Josh uses
  24700+.** Scenario saves live in the Godot user data directory, never the repo.
- Some scenarios depend on the generated world. If one fails, re-run it with
  `--seed=4242` before believing it: that seed is the known-good baseline.

---

## Code standards

Match the surrounding code. It is consistent — follow it rather than your defaults.

- **Tabs** for indentation. Two blank lines between top-level functions.
- **Typed GDScript throughout.** `:=` where the type is obvious, an explicit
  `: Type` where it is not — GDScript's "Cannot infer type" errors are a compile
  failure, not a warning.
- `class_name X` then `extends Y`, then a `##` doc comment explaining what the
  file is *for*, in plain English.
- `##` doc comments on constants, exported vars and public functions. Comments
  explain intent and the non-obvious; they do not restate the code.
- Section banners inside long files: `# --- shooting ------------------`.
- `snake_case` functions and variables, `_leading_underscore` for private,
  `SCREAMING_SNAKE` for constants, `PascalCase` for `class_name`.

### Networking — the host decides everything

- Clients **request**, the host **validates and broadcasts**. Never trust a value
  that came from a client; re-derive or bounds-check it on the host.
- Requests: `@rpc("any_peer", "call_local", "reliable")`, validated host-side.
- Broadcasts: `@rpc("authority", "call_remote", …)`, `unreliable_ordered` for
  continuous state (positions, poses), `reliable` for events that must land.
- Broadcast through `Net.send_to_ready(node, method, args)`, which deliberately
  does not call locally.
- Anything that must survive a rejoin has to be in the save *and* in the
  host's sync-to-new-peer path. Test both.

### Testability

Keep pure logic in the `*_math.gd` and `data/*_table.gd` files so it can be tested
headless without a scene tree — that is why `waves.gd`, `weapon_math.gd`,
`row_math.gd`, `shark_math.gd` and friends exist. New behaviour that can be
expressed as a function should be, and should get a test in `tests/`.

---

## Definition of done

Troy's standing complaint is work that is "half-assed". Before calling anything
done:

- It **compiles**, the **full unit suite passes**, and the **relevant scenarios
  pass** — on a random seed, not only on `4242`.
- The feature is **fully wired**: reachable in game, synced to clients, saved and
  reloaded, and shown in the UI where it should be.
- You have **looked at it up close, in first person, from both sides**. A
  faraway screenshot is not evidence. If it is a visual change, take the
  screenshot and actually look at it.
- New behaviour has a **test**.
- `HANDOFF.md` gets an appended note on what landed and what is still open.

If you cannot finish something, say exactly what is unfinished. Do not report it
as done.
