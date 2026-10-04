# SwordSaint

A side-scrolling 2D action game. Real-time Metroidvania combat (Hollow Knight-style) is broken up by a
time-stopped **combo planning** phase, where the player builds a physics-driven combo out of attacks
and sees a preview of it before it plays out.

## Project layout
- Engine: **Godot 4.3** (GL Compatibility renderer), GDScript.
- Godot project root: `test/` (`test/project.godot`, main scene `res://scenes/title/title_screen.tscn`:
  the title screen, whose menu leads to Play Game = the opening level, Training = the slime test area).
  Its title theme is synthesized by `test/scenes/audio/music.gd` (on a thread; a few seconds).
  Launch: `run.bat` / Ctrl+Shift+B runs the main scene (the title screen); `run_test_area.bat` /
  Ctrl+Alt+B (VS Code task "Run Test Area") runs the old slime test area `res://scenes/2D Game.tscn`.
- Characters (`test/scenes/characters/`): `characters.gd` holds the roster and the pick
  (`Characters.selected`, a static var; set on the character select screen, `character_select.tscn`,
  which Play Game / Training lead through; `-- character=dogood` on the command line for direct
  launches). `player.gd` reads it: its `sprites` (PlayerSprites or `dogood_sprites.gd`, same API:
  frames(), anchor(), cape_visible(), ORIGIN_OFFSET), `intro_animation`, cape `style`, and Dogood's
  slower real-time attacks (DOGOOD_ATTACKS: Flash Chop / Big Boot / Headbutt with startup, active
  hitbox, recovery). The CombatManager's `MOVES` is SAINT_MOVES or DOGOOD_MOVES; Dogood's are
  data-driven "wrestle" moves (`_plan_wrestle`: catch window, hold path, impact, release), the
  kite (`_plan_kite_flight`, `_step_kite`, `kite.gd`: an enemy thrown into it is struck by lightning)
  and the "Why do you fight!?" stance of finishers. Portraits: `portraits.gd`.
  Ilyra (`elf`, `elf_sprites.gd`): her poses get baked secondary motion (damped springs in
  `_secondary`: bust, hat tip, hair, skirt, orb). Her ELF_MOVES are staff strikes (wrestle-style)
  and spells: planned objects in `_plan_spells` that age only while Time passes (`_step_spells`;
  drawn by `combat/spell.gd`, ghosts too). Spell hits are swept (the enemy's path since the last
  frame), can root the enemy (`_plan_pin`, which `_drift` respects), and are listed in the
  timeline ("+ Fireball!") via `ComboPlan.detonations`. Spells end with the Stagger Break.
- `test/scenes/opening/`: the opening level, built in code by `opening.gd` (terrain from a height map
  using level_1's tileset, enemies, summit-trigger cutscene, boss bar), with `storm.gd` (sky, rain that
  freezes while `time_stopped`, lightning, thunder), `village_backdrop.gd` and `dialogue_box.gd`.
- Enemies for the opening (`test/scenes/enemies/`): `enemy_base.gd` (shared: hurtbox, stagger meter,
  `take_damage`, `die`), `mole.gd` (melee swipe, plus an earthquake slam at range that raises three
  `earth_spike.gd` spikes stepping toward where the player stood; `boss = true` makes the Burrow King,
  with fireball volleys), `bat.gd` (hovers, spits homing `fireball.gd` projectiles), sprites drawn in
  `enemy_sprites.gd`. `comboable` (enemy_base) = has a yellow stagger meter and can be Stagger Broken;
  non-comboable enemies (the bat) show a red HP bar instead and are just worn down in real time.
  The player has 10 HP (`take_hit`: reel, sound, -1 HP, 1s invulnerability).
- Enemy projectiles (group `enemy_projectiles`; the interface is documented at the top of `fireball.gd`:
  `state()`/`apply_state()`, `plan_advance()`, `plan_hits_player()`, `cuttable`, `ghost_texture()`...)
  are part of combo planning: each planned step simulates them while its Time passes, attacks cut the
  cuttable ones, the ghosts draw them, and the real nodes are shown at the timeline's end (so undo moves
  them back). A planned hit on the player cuts that move short (`_interrupt`: he's knocked back and
  reels for the rest of its Time, the combo goes on) and the timeline shows "(Interrupted - Hit)".
- Buffs: `player.buffs` (name -> seconds left, ticking in real time only), defined in `combat_manager.gd`
  `BUFFS` and shown as green squares beside the HUD (hover for the name). Storm (from the Iai attack
  Usurp the Heavens) adds `storm_lightning.gd` crackle to sword swings; combo plans record whether it's
  active (`ComboPlan.storm`, the 4th arg of "sword" events) so ghosts and FINISH match.
- Attack hit checks: reaches are tuned on the slime; bigger enemies get hit that much further out
  (`_enemy_grow`). Each swing stays active for `ACTIVE_FRAMES` after it starts, catching an enemy that
  drifts into reach late (`_late_contact`).
- Gameplay tests live in `gameplay_tests/` (`combo_tests.gd`, `fireball_tests.gd`; run with
  `gameplay_tests/run_tests.bat [combo|fireball]`). They are slow: only run them when the user asks.
- `test/scenes/player.gd` handles player movement, jump/double jump, teleport-down, charge, and attack selection.
- `test/scenes/attacks/` holds attack scenes and `attack_scripts/` (including `AttackLibrary.gd`).
- Sword slash visuals (`sword_horizontal`, `sword_launch`, `sword_horizontal_finish`, `sword_downward`) are
  curved arcs generated in code by `test/scenes/attacks/slash_sprite.gd` (edit the `ARCS` table there).
- `test/scenes/enemies/` holds enemies (slime) and the hurtbox script. Enemies are in the `enemies` group
  and have `HP`, a `stagger_meter`, and `apply_stagger(amount)`.
- `test/scenes/combat/combat_manager.gd` (the `%CombatManager` node in `2D Game.tscn`) owns Time/Energy,
  the HUD, the Stagger Break menu, and the combo moves (`MOVES`). `time_stopped` freezes the player and
  enemies. Momentum: each move "drives" some bodies; bodies it doesn't drive drift on their momentum
  (gravity + horizontal drag) while its Time passes (see `_driven_bodies`). Combo knockback numbers are
  hand-derived from the drift physics; the tuning comment above `MOVES` explains them.
  Moves are *planned* synchronously into a frame-by-frame `ComboPlan` (`_plan_move`), which
  `ghost_preview.gd` loops as the grey preview and `_play_plan` replays on the real bodies, so the
  preview always matches. New moves must be written as `_plan_*` functions (record with `_step()`,
  effects as plan events), never as coroutines that move bodies directly.
  Picking a move only appends it to `_timeline` (undo/rewind supported); the real bodies stay at the
  break's start until FINISH (`_finish`) replays the whole timeline. Anything position-dependent while
  planning must be evaluated at the timeline's end via `_at_cursor()`.
  Stances (`"group": "stance"`, e.g. Iai): each timeline step records `stance_after`; while in a stance the
  menu only offers moves whose `"stance"` matches, plus Wait and Exit Stance (`_shown_in_stance`).
  A stance attack flagged `"ends_stance"` would drop out of the stance (supported, currently unused). Attacks can hit with a
  box (`"reach"`), or a thin line (`"reach_line"`: angle, from, to, half_width) for the long Iai cuts.
  Moves with `"submenu"` (Grapple) open a submenu of other moves flagged `"in_submenu"`.
  Moves flagged `"directional"` open a Left/Right submenu; the chosen direction is stored on the
  timeline step and passed to `_plan_move(id, direction)`, which turns the player that way first.
- Extra key bindings (WASD menu nav, E = attack/confirm, Q/Backspace = undo) are added at runtime in
  `combat_manager.gd` `_add_extra_keys()`, not in `project.godot`. `stagger_meter.gd` is the yellow bar above each enemy.
- `test/scenes/player_sprites.gd` draws the player character's body frames in code from a simple skeleton
  (hips, spine lean, two-bone IK legs/arms, two-handed sword grip); poses are short dictionaries blended
  between keyframes (see "Generated assets"). Frames are 64x64 at `ORIGIN_OFFSET` (feet on y = 0); the
  collision box is unchanged, so the character is visually much larger than its hitbox and the slimes.
- `test/scenes/player_cloak.gd` is the robe's long tail: a separate sprite drawn just behind the body,
  hanging from a per-frame anchor, shaped by a stylised `momentum` (not physics). Real time: it follows the
  player's velocity and settles when he stands still. During a Stagger Break, `combat_manager.gd`
  `_step_cloak()` plans it per frame (peak-hold: it takes on the player's motion only when that's about
  as strong or heads somewhere new, so attacks/Flips keep the last move's swirl; Wait/TP Down let it
  settle on the ground), records it in the plan, and ghosts/FINISH replay it. Animations in
  `PlayerSprites.SELF_CLOAKED` (the jump flip) draw their own cloak and hide this layer.
- `test/scenes/audio/sfx.gd` synthesizes every sound effect in code.
- `test/scenes/level topology/` holds level pieces (killzone, moving platform, coin).
- `test/broken/` holds broken or experimental scenes. Don't build on them.
- `test/scenes/*.tmp` files are Godot editor temp files. Ignore them.
- Art: Kenney "Pixel Platformer" pack in `test/assets/2D/Pixel Platformer/`.

## Core loop

### 1. Real-time phase (Metroidvania combat)
- Moment-to-moment combat feels like Hollow Knight: tight movement and melee, with enemies fighting back in real time.
- Each enemy has a **stagger meter**. The player's real-time attacks drain it.
- The player can spend **Energy** during real-time combat on:
  - mobility (dashes, extra jumps, teleports)
  - healing
  - damage mitigation (blocks, shields, i-frames)
  - empowered attacks that deal extra stagger damage
- When an enemy's stagger meter hits zero, the game enters a **Stagger Break** (working name).

### 2. Stagger Break (combo planning phase)
- Time stops.
- The player builds a combo by picking attacks from scrolling menus or as **attack cards** (UI not decided yet).
- Each attack has physics properties, for example:
  - knockback in various directions (launch, spike, push away, pull in)
  - pinning the enemy to the floor or a wall
  - moving the player to a different spot (teleports, dashes, repositioning)
- Each attack costs some **Time** (the combo-phase budget) and some **Energy** (shared with the real-time phase).
- **Predictive ghosts:** animated grey stand-ins for the player and the enemy show exactly where each
  planned attack moves the enemy and where the player ends up (like *Your Only Move Is HUSTLE*). The
  preview must be deterministic: what's shown is what happens.
- The player confirms the finished combo.

### 3. Execution
- The player character performs the planned combo with flashy presentation (camera, VFX, hitstop, sound).
- Real-time combat resumes from the end state of the combo (enemy position, velocity, pinned or airborne state).

## Design pillars
1. **The combo planning phase is the hook.** It should feel stylish and cool, and it should reward creativity and experimentation.
2. **Player expression over a single right answer.** Valid strategies, left to the player's style, include:
   - knocking enemies into environmental hazards
   - setting enemies up to expose weak points
   - setting up the next stagger break, e.g. spiking the enemy into the floor just as combo Time runs out
     so they're open to free real-time hits afterward
3. **Energy is a shared, contested resource.** Spending Energy to make real-time fights easier means
   having less for big combos. That tension is intentional, so keep it in place.
4. **The preview is a promise.** Combo-phase physics has to be deterministic and simulatable ahead of
   time, so the ghost preview matches execution exactly.

## Technical implications (guidance for implementation)
- Attacks should be **data-driven** (Resources or dictionaries): damage, stagger damage, knockback
  vector, pin/launch flags, player displacement, Time cost, Energy cost, animation. One definition
  should drive real-time use, the ghost preview, and combo execution.
- The combo simulation needs a deterministic step function that can run on cloned or ghost state
  without affecting the live scene (fixed timestep, no frame-rate-dependent randomness).
- The Stagger Break freezes the world with the CombatManager's `time_stopped` flag (player and enemy
  scripts skip their own physics), not Godot's tree pause, so planning and ghosts can keep simulating.
- Enemies need a common interface: stagger meter, hurtbox, a response to knockback/pin, weak-point exposure.
- Environment hazards (killzones, spikes, walls) must take part in both the preview simulation and the real one.

## Generated assets (and baking them later)
While the art and audio are still changing often, they're generated in code rather than stored as files:
- Player character: `test/scenes/player_sprites.gd` (poses as numbers, colours as constants) and its
  cloak, `test/scenes/player_cloak.gd` (cloak shapes are generated on demand, ~6 ms each, then cached).
- Sword slash arcs: `test/scenes/attacks/slash_sprite.gd` (the `ARCS` table).
- Sound effects: `test/scenes/audio/sfx.gd`.

Each is built **once at startup** into ordinary textures and audio streams, then cached, so there's no
per-frame cost: at runtime they behave exactly like PNG sprites and WAV files. Measured startup cost:
player 86 body frames ≈ 620 ms, slash arcs ≈ 160 ms, sounds ≈ 160 ms. The generated art replaces placeholder
frames at runtime (e.g. `player.tscn` still holds the old knight frames), so the Godot editor doesn't
show it.

**Deferred: baking.** Once a character's art is close to final (or if startup time grows as more art is
generated), "bake" it: a script (e.g. `bake_art.bat` next to `run.bat`) runs the generators once and
saves the frames as real PNG sprite sheets in `test/assets/`, and the game loads those files instead of
generating. That gives zero startup cost, art visible in the editor, and PNGs that can be hand-edited in
an art tool. Caveats:
- New PNGs must be imported once (open the editor, or run Godot with `--headless --editor --quit`)
  before the game can load them.
- Re-baking overwrites the PNGs, so hand edits are lost unless baking stops for that asset.

## Open questions (not decided yet; don't assume an answer)
- **Progression model:** RPG/Metroidvania progression (unlocking more Health, Energy, Time, and new attacks)
  or **roguelike** (picking rewards between increasingly hard fights, building a kit)? Keep systems flexible
  enough to support either.
- Combo selection UI: scrolling menus or attack cards?
- Final name for "Stagger Break."
- Whether Time and Energy are fully separate or partly convertible.
