extends Node

## Owns the Time and Energy resources, the resource HUD, and the Stagger Break
## (combo planning) phase. During a Stagger Break the world is frozen and the player
## plans a combo one move at a time. Planned moves go on a timeline that grey ghosts
## loop, while gold ghosts loop the highlighted menu option from the end of the
## timeline at the same time. Planned moves can be undone or rewound. FINISH has the real player and enemy perform the whole plan,
## then real time resumes. See "Planning" below.
##
## Momentum: each body (player and enemy) carries a velocity. Every move *drives*
## some bodies: attacks drive the player (who hangs in place) and, if they connect,
## the enemy, whose momentum becomes the attack's "momentum". Jump, TP Down and
## Grapple - Fly Towards drive only the player; Wait drives nobody. While a move's
## Time passes (TIME_UNIT seconds per point of Time), every body it doesn't drive
## drifts on its momentum, under gravity and horizontal drag. So momentum plays out
## exactly when Time passes without the enemy being given new momentum.

const MAX_TIME := 15
const MAX_ENERGY := 10
const ENERGY_REGEN_PER_SECOND := 1.0
const MOVE_DURATION := 0.3
const TP_DOWN_RANGE := 197.0 # Matches the player's TPFloorDetect ray.

const TIME_UNIT := MOVE_DURATION # Seconds of drift per point of Time a move costs.
const CLOAK_MOVING_SPEED := 20.0 # px/s; below this the player counts as still, for the cloak.
const COMBO_GRAVITY := 450.0 # px/s^2 applied to drifting bodies.
const HORIZONTAL_DRAG := 4.0 # Drifting bodies lose horizontal speed by e^(-drag * seconds).

const DASH_DISTANCE := 94.0 # Twice a real-time basic swing's reach (its hitbox ends 47px ahead).
const RUNNING_SLASH_DISTANCE := DASH_DISTANCE * 0.75
const DIVE_ANGLE_FROM_VERTICAL := 60.0 # 0 = straight down, 90 = level; toward the facing.
const DIVE_SPEED := 420.0 # px/s
const DIVE_MAX_SECONDS := 1.5 # Gives up if there's no floor below.

const GRAPPLE_RANGE := 160.0 # Max distance from the player's hand to the enemy's center.
const GRAPPLE_HOLD_DISTANCE := 24.0 # Center-to-center spacing a grapple leaves them at.
const GRAPPLE_TRAVEL := 0.15 # Seconds for the hook to fly out (and back, on a miss).
const GRAPPLE_SNAP := 0.15 # Seconds for the rope to spring taut after the hook lands.
const GRAPPLE_SAG := 14.0 # How slack the rope looks while the hook is flying.

# A swing can still connect for this many frames after it starts: an enemy drifting
# into reach just after it is caught then (and held for the rest of the move).
const ACTIVE_FRAMES := 3
# Reach boxes and lines were tuned on the slime, whose center-to-edge is this; bigger
# enemies are hit that much further out (see _enemy_grow()).
const REFERENCE_HALF_SIZE := Vector2(7.875, 6.25)
# A planned move that the player is hit during is cut short there; he's knocked back
# (px/s, away from what hit him) and reels for the rest of the move's Time.
const PLAYER_KNOCKBACK := Vector2(110, -120)

# Buffs the player can have (player.buffs), shown as green squares beside the HUD.
const BUFFS := {
	"storm": {"label": "Storm", "seconds": 30.0}, # From Usurp the Heavens: lightning on his swings.
}
const BUFF_COLOR := Color(0.22, 0.62, 0.28)
const BUFF_BORDER := Color(0.1, 0.36, 0.14)
const BUFF_SIZE := 30.0
# Usurp the Heavens: where his raised sword's tip is (from his center, +x = facing).
const USURP_SWORD_TIP := Vector2(2, -40)

const Sfx = preload("res://scenes/audio/sfx.gd")
const Fireball = preload("res://scenes/enemies/fireball.gd")
const HP_COLOR := Color(0.9, 0.22, 0.22)
const GrappleRope := preload("res://scenes/combat/grapple_rope.gd")
const BreakEffects := preload("res://scenes/combat/break_effects.gd")
const GhostPreview := preload("res://scenes/combat/ghost_preview.gd")
const Kite := preload("res://scenes/combat/kite.gd")
const Spell := preload("res://scenes/combat/spell.gd")
const Characters := preload("res://scenes/characters/characters.gd")
const FONT := preload("res://assets/2D/brackeys_platformer_assets/fonts/PixelOperator8.ttf")
const TIME_COLOR := Color(0.25, 0.55, 1.0)
const ENERGY_COLOR := Color(1.0, 0.85, 0.1)
const HEADER_COLOR := Color(0.65, 0.65, 0.65)
const BAR_SIZE := Vector2(200, 12)
const UI_LAYER := 2 # Above BreakEffects' blue filter.
const FINISH_SPEED := 1.5 # Time scale the planned combo is performed at.
const IAI_ENTER_SECONDS := 0.8 # Length of the "iai_enter" animation (16 frames at 20 fps).
const INTRO_TIMEOUT := 3.0 # Failsafe: show the menu after this long even if the intro hasn't finished.
const CANDIDATE_TINT := Color(1.0, 0.8, 0.25) # Ghost tint for the highlighted, not-yet-planned move.

# Combo moves. Displacements are in pixels, with +x pointing the way the player faces.
# A sword attack connects when the enemy's center is inside its reach rect, measured
# from the player's center (again with +x = facing). A grapple connects when the enemy
# is within GRAPPLE_RANGE in any direction.
#
# Tuning (all assumes COMBO_GRAVITY 450, HORIZONTAL_DRAG 4, TIME_UNIT 0.3; if you change
# those, re-derive these numbers). One Time unit of drift (18 physics steps) moves a body
# with momentum (30, -40) by (5.07, 9.375) and one with (60, 0) by (10.14, 21.375).
#
# Launching Slash knocks the enemy to (10.93, -45.375), a bit higher than a Jump, with
# momentum (30, -40). During a follow-up Jump it rises a little more, then falls back to
# exactly JUMP_DISPLACEMENT, so the Jump puts the player back where they started
# relative to the enemy. Horizontal Slash pushes 5.86px with momentum (60, 0), so with a
# Jump's worth of drift it also ends exactly one Jump (16px) further ahead, now 21.4px
# lower. So Launching Slash > Jump > Horizontal Slash > Jump > Downward Slash > TP Down
# leaves the enemy ~54px below the player for Downward Slash, and connects from roughly
# 16-60px away, which covers the real-time swings' reach.
#
# Pinpoint Strike's hitbox is a thin horizontal band at the exact height the enemy ends
# up after Launching Slash > Jump > Horizontal Slash > Horizontal Slash: a ground-level
# enemy starts 2.25px below the player's center, the Launch and Jump cancel out, and
# each Horizontal Slash lifts it 6px (back-to-back hits leave no time to drift), leaving
# it 9.75px above. The band allows 4px of leeway either way. It's wide (26-78px ahead)
# because how far ahead the enemy ends up depends on how far away the combo started.
const PINPOINT_HEIGHT := -9.75
const PINPOINT_LEEWAY := 4.0
const JUMP_DISPLACEMENT := Vector2(16, -36)
# The pose each stance holds between moves.
const STANCE_POSES := {"iai": &"iai_hold", "why": &"why_hold"}
# Dogood's kite: an enemy whose center comes within KITE_RADIUS (plus however much
# bigger than the slime it is) of the flying kite is struck by lightning.
const KITE_RADIUS := 20.0
const KITE_DAMAGE := 3
const KITE_RISE := 0.45 # Seconds for the kite to climb to its spot.
const KITE_BLAST := Vector2(0, 420) # The lightning slams the struck enemy down (px/s).

# Ilyra's spells (see _step_spells). Distances in px, times in seconds of combo Time
# (TIME_UNIT per point of Time); spells only age while Time passes.
const FIREBALL_SPEED := 105.0
const FIREBALL_TURN := 2.6 # rad/s of homing to start with (it tightens with age).
const FIREBALL_RADIUS := 9.0
const FIREBALL_LIFE := 4.5
const FIREBALL_DAMAGE := 4
const FIREBALL_BLAST := Vector2(70, -320) # x away from the fireball.
const CLOUD_OFFSET := Vector2(120, -110) # From her center, +x = facing.
const CLOUD_DELAY := 4 * TIME_UNIT
const CLOUD_STRIKE := 0.15 # The bolt lasts this long.
const CLOUD_HALF_WIDTH := 16.0
const CLOUD_DAMAGE := 5
const CLOUD_SLAM := Vector2(0, 420)
const SNARE_AHEAD := 72.0
const SNARE_ARM := 0.25
const SNARE_SIZE := Vector2(20, 30) # Half-width, height above the ground.
const SNARE_DAMAGE := 3
const SNARE_ROOT := 2 * TIME_UNIT
const WELL_OFFSET := Vector2(64, -60)
const WELL_WAKE := 2 * TIME_UNIT
const WELL_PULL := 3 * TIME_UNIT
const WELL_RANGE := 170.0
const WELL_ACCEL := 1100.0
const WELL_RADIUS := 36.0
const WELL_DAMAGE := 3
const WELL_HOLD := 0.2
const BLINK_DISTANCE := 80.0

# The Sword Saint's moves. (Dogood's are DOGOOD_MOVES, Ilyra's ELF_MOVES; MOVES is
# whichever is playing.)
const SAINT_MOVES := {
	"launching_slash": {
		"name": "Launching Slash", "group": "attack", "time": 2, "energy": 1,
		"damage": 1, # HP, per hit.
		"pose": &"uppercut", # Body pose, from player_sprites.gd.
		"knockback": Vector2(10.932, -45.375),
		"momentum": Vector2(30, -40),
		"reach": Rect2(-10, -40, 80, 64), # Reaches a little above head height too.
		"sword_scene": preload("res://scenes/attacks/sword_launch.tscn"),
		"animation": &"attack_launch",
	},
	"horizontal_slash": {
		"name": "Horizontal Slash", "group": "attack", "time": 1, "energy": 1,
		"damage": 1, # HP, per hit.
		"pose": &"slash", # Body pose, from player_sprites.gd.
		"knockback": Vector2(5.863, -6),
		"momentum": Vector2(60, 0),
		# Reaches far enough that a second Horizontal Slash still lands after the first.
		"reach": Rect2(-10, -30, 88, 60),
		"sword_scene": preload("res://scenes/attacks/sword_horizontal.tscn"),
		"animation": &"attack",
	},
	# Runs forward while swinging from low in front, up and round behind. Hits the
	# first time the enemy enters either hitbox (both measured from the moving
	# player, see _running_slash_contact), and knocks it weakly back toward where the
	# run started, and a little up.
	"running_slash": {
		"name": "Running Slash", "group": "attack", "time": 1, "energy": 1, "grounded_only": true,
		"damage": 1, # HP, per hit.
		"pose": &"running_slash", # Body pose, from player_sprites.gd.
		"running": true,
		"duration": 0.4, # Twice Launching Slash's swing.
		"reaches": [
			Rect2(-10, -30, 74, 60), # In front: Horizontal Slash's, a bit shorter.
			Rect2(-44, -56, 44, 36), # Above and behind.
		],
		"knockback": Vector2(12, -14), # x is toward the run's starting point.
		"momentum": Vector2(25, -50),
		"sword_scene": preload("res://scenes/attacks/sword_running_slash.tscn"),
		"animation": &"attack",
	},
	"downward_slash": {
		"name": "Downward Slash", "group": "attack", "time": 2, "energy": 1, "airborne_only": true,
		"damage": 2, # HP, per hit.
		"pose": &"chop", # Body pose, from player_sprites.gd.
		"knockback": Vector2(4, 400), # Stops at the floor.
		"momentum": Vector2(0, 200),
		# The arc (slash_sprite.gd's "downward") sweeps a 58px blade from 35 degrees above
		# ahead to 70 degrees below, covering 0-58px ahead and 33px up to 54px down; this
		# is that, grown by the slime's half-size (and trimmed just in front of him).
		"reach": Rect2(6, -39, 66, 99),
		"sword_scene": preload("res://scenes/attacks/sword_downward.tscn"),
		"animation": &"attack",
		"hit_sound": "heavy_hit",
	},
	# Tuning: knocks the enemy (26, -38) with momentum (60, -150). Two Jumps' worth of
	# drift (36 steps) carries it a further (13.2, -6.75), leaving it ~30px below and
	# 25-51px ahead of the player, inside Downward Slash's reach, so Tri-Strike > Jump >
	# Jump > Downward Slash connects from anywhere Tri-Strike reaches (up to 44px).
	# Straight after Tri-Strike the enemy is ~36px above the player's center, well above
	# Pinpoint Strike's band.
	"tri_strike": {
		"name": "Tri-Strike", "group": "attack", "time": 2, "energy": 2,
		"damage": 1, # HP, per hit (each of the three swings).
		"pose": &"tri", # Body pose, from player_sprites.gd.
		"swings": 3, "swing_interval": 0.1, # The knockback lands with the third swing.
		"knockback": Vector2(26, -38),
		"momentum": Vector2(60, -150),
		# Shorter than the other attacks, but reaching up to where Launching Slash leaves
		# an enemy that was standing up close (~45px above his center), so Launching
		# Slash > Tri-Strike connects.
		"reach": Rect2(-10, -52, 64, 76),
		"sword_scene": preload("res://scenes/attacks/sword_tri_strike.tscn"),
		"animation": &"attack",
	},
	# Gather Clouds: drops through the air with two chops that carry the enemy down
	# with him, then a rising cut that throws it up and away. The hits come
	# swing_interval apart while he falls at fall_speed; from a Jump's height he lands
	# partway through, and the rest of the hits still come.
	"gather_clouds": {
		"name": "Gather Clouds", "group": "attack", "time": 2, "energy": 2, "airborne_only": true,
		"damage": 1, # HP, per hit (each of the three).
		"pose": &"chop", "final_pose": &"uppercut", # Body poses, from player_sprites.gd.
		"gather": true, "swing_interval": 0.15, "fall_speed": 160.0,
		"reach": Rect2(-8, -40, 66, 84),
		"knockback": Vector2(30, -42), # The final cut.
		"momentum": Vector2(80, -170),
		"sword_scene": preload("res://scenes/attacks/sword_gather_clouds.tscn"),
		"animation": &"attack",
	},
	"pinpoint_strike": {
		"name": "Pinpoint Strike", "group": "attack", "time": 3, "energy": 3,
		"damage": 3, # HP, per hit.
		"pose": &"thrust", # Body pose, from player_sprites.gd.
		"pinpoint": true,
		# For bigger enemies the band moves up (their centers sit higher off the ground)
		# rather than widening, so the combo stays exactly as precise.
		"precise": true,
		"knockback": Vector2(140, -4),
		"knockback_duration": 0.45,
		"momentum": Vector2(150, 0),
		"reach": Rect2(26, PINPOINT_HEIGHT - PINPOINT_LEEWAY, 52, PINPOINT_LEEWAY * 2.0),
		"hit_sound": "heavy_slash",
	},
	# --- The Iai stance's attacks. Iai turns him away from the enemy, so they cut
	# behind him; they hit along thin lines ("reach_line", see _connects) or a strip.
	#
	# Scale the Summit: a long, narrow cut up and behind, within 11px of the blade's
	# line (the enemy's half-width plus the blade), from 10 to 100px out. Tuning: after
	# Running Slash > Flip > Running Slash > Flip > Launching Slash > Iai, the enemy sits
	# 62px above and 34-61px behind him (for starting distances of 18-45px); a line at
	# -127.5 degrees passes within 11px of all of those. Each hit knocks the enemy 20px
	# further out along the cut, with momentum the same way (up and away): after
	# Launching Slash > Iai the enemy is ~50px along the line, so a second and third
	# Scale still land (at ~70 and ~90px) but a fourth (~110px) is past the blade.
	"scale_the_summit": {
		"name": "Scale the Summit", "group": "attack", "time": 1, "energy": 0, "stance": "iai",
		"damage": 1, # HP, per hit.
		"pose": &"scale_the_summit", # Body pose, from player_sprites.gd.
		"reach_line": {"angle": -127.5, "from": 10.0, "to": 100.0, "half_width": 11.0},
		"knockback": Vector2(-12.18, -15.87), # 20px further along the cut.
		"momentum": Vector2(-91.3, -119.0), # 150 px/s along the cut.
		"particles": Color(0.72, 0.72, 0.75), # Grey, falling from the blade.
		"sword_scene": preload("res://scenes/attacks/sword_scale_the_summit.tscn"),
		"animation": &"attack",
		"hit_sound": "heavy_slash",
	},
	# Imbibe the Sky: straight up, a tall line 14px either side, launching high. An
	# enemy directly above stays directly above, so Imbibe > Wait > Imbibe > Wait >
	# Imbibe keeps connecting: each launch (with the Wait) carries it about 57px
	# higher, and the line reaches 180px, so the chain works whenever the first hit
	# lands up to ~66px above him.
	"imbibe_the_sky": {
		"name": "Imbibe the Sky", "group": "attack", "time": 1, "energy": 0, "stance": "iai",
		"damage": 1, # HP, per hit.
		"pose": &"imbibe",
		"reach_line": {"angle": -90.0, "from": 10.0, "to": 180.0, "half_width": 14.0},
		"knockback": Vector2(0, -30),
		"momentum": Vector2(0, -160),
		"particles": Color(0.55, 0.82, 1.0), # Sky blue, falling from the blade.
		"sword_scene": preload("res://scenes/attacks/sword_imbibe_the_sky.tscn"),
		"animation": &"attack",
		"hit_sound": "heavy_slash",
	},
	# Sever the Roots: a huge horizontal cut behind him (and a little in front) that
	# hurls the enemy up and over his head, far out to his front. Tuning: at point
	# blank (the enemy ~18px behind him after Iai), it lands ~42px in front and drifts
	# ~17px further during a Dash, so Iai > Sever > Exit Stance > Dash > Flip leaves it
	# ~35px in front and ~27px up, inside Launching Slash's reach.
	"sever_the_roots": {
		"name": "Sever the Roots", "group": "attack", "time": 0, "energy": 2, "stance": "iai",
		"damage": 2, # HP, per hit.
		"pose": &"sever",
		"reach": Rect2(-200, -24, 220, 48),
		"knockback": Vector2(60, -45),
		"momentum": Vector2(100, -20),
		"particles": Color(0.45, 0.9, 0.35), # Green, falling from the blade.
		"particle_line": {"angle": 180.0, "from": 6.0, "to": 200.0},
		"sword_scene": preload("res://scenes/attacks/sword_sever_the_roots.tscn"),
		"animation": &"attack",
		"hit_sound": "heavy_slash",
	},
	# Usurp the Heavens: he lifts his sword straight up and a sparkle appears high above
	# him. If it touches the enemy, lightning strikes down out of the sky, through the
	# enemy and into his sword (harmlessly), and he gains the Storm buff. Tuning: after
	# Gather Clouds > Running Slash > Flip > Iai > Scale x3 > Exit Stance > Flip > Dash >
	# Iai > Imbibe x3, the enemy is ~175px straight above him (1-20px ahead), still
	# rising; the sparkle sits there, and the hitbox around it allows ~25px either way.
	"usurp_the_heavens": {
		"name": "Usurp the Heavens", "group": "attack", "time": 2, "energy": 3, "stance": "iai",
		"damage": 5, # HP.
		"pose": &"usurp", # Body pose, from player_sprites.gd.
		"usurp": true,
		"sparkle": Vector2(0, -175), # From his center.
		"reach": Rect2(-26, -200, 52, 50), # Around the sparkle.
		"raise": 0.15, # Seconds lifting the sword before the sparkle appears.
		"knockback": Vector2(0, 10), # Struck down a little.
		"momentum": Vector2(0, 40),
		"buff": "storm",
		"hit_sound": "lightning",
	},
	"grapple_pull_in": {
		"name": "Grapple - Pull In", "short_name": "Pull In", "in_submenu": true,
		"group": "attack", "time": 1, "energy": 1,
		"pose": &"throw", # Body pose, from player_sprites.gd.
		"grapple": "pull_in", # Reels the enemy in to just in front of the player.
		"momentum": Vector2.ZERO, # The rope stops it dead.
	},
	"grapple_fly_towards": {
		"name": "Grapple - Fly Towards", "short_name": "Fly Towards", "in_submenu": true,
		"group": "attack", "time": 1, "energy": 1,
		"pose": &"throw", # Body pose, from player_sprites.gd.
		"grapple": "fly_towards", # Reels the player in to just in front of the enemy.
	},
	# "directional" moves open a Left / Right submenu; the player turns to face the
	# chosen direction before moving.
	"jump": {"name": "Jump", "group": "action", "time": 1, "energy": 0},
	"dash": {"name": "Dash", "group": "action", "time": 1, "energy": 0},
	"tp_down": {"name": "TP Down", "group": "action", "time": 1, "energy": 1, "airborne_only": true},
	"dive": {"name": "Dive", "group": "action", "time": 1, "energy": 0, "airborne_only": true},
	# Opens a submenu of the grapple attacks (listed above with "in_submenu").
	"grapple": {"name": "Grapple", "group": "action", "time": 1, "energy": 1,
		"submenu": ["grapple_pull_in", "grapple_fly_towards"]},
	"wait": {"name": "Wait", "group": "action", "time": 1, "energy": 0},
	# Stances: entering one swaps the menu to that stance's attacks (moves with a
	# matching "stance"), plus Wait and Exit Stance, until the player exits.
	"exit_stance": {"name": "Exit Stance", "group": "action", "time": 0, "energy": 0},
	"iai": {"name": "Iai", "group": "stance", "time": 1, "energy": 2, "grounded_only": true,
		"enters_stance": "iai", "flip_facing": true, "pose": &"iai_enter",
		"hint": "Enter the Iai stance"},
	# Turns the player around. Two in a row cancel each other out (see _commit_move).
	# "standalone": shown as its own button beside the menu rather than in the list.
	"flip": {"name": "Flip", "group": "action", "time": 0, "energy": 0, "standalone": true},
}

# Dogood the wrestler's moves. Short-ranged and expensive (3-4 hits make a combo),
# but forgiving: most grab the enemy and carry it along a fixed path relative to
# him, so what happens next doesn't depend on exactly where it was.
#
# "wrestle" moves (see _plan_wrestle) take `duration` seconds:
#   contact: [from, to] seconds in which the reach box can catch the enemy (plus
#     ACTIVE_FRAMES); until then it drifts.
#   player: [[t, offset]...] where his center moves to, from where he started.
#   hold: [[t, offset]...] where the caught enemy's center is carried, from his
#     current center (it eases in from wherever it was caught).
#   impact: when the hit lands (damage, impact_sound, dust if set); at the catch if earlier.
#   release: when it's let go, with the move's momentum (at least a frame after the
#     catch); never, for moves that keep hold of it.
# Offsets have +x the way he faces.
#
# Tuning: Kite Experiment leaves the kite (-40, -66) from his center. A German Suplex
# slams the enemy down behind him and it bounces up through that spot (peaking ~75px
# up), so Kite > Collar Grab > German Suplex calls the lightning down, which blasts
# the enemy back down to the ground behind him: Flip, and it's in reach again. The
# finishers reach high (up to ~70px above him) to catch enemies still in the air.
# Typical combos (all within 15 Time / 10 Energy):
#   Collar-and-Elbow > Knife-Edge Chop > Flying DDT > Why do you fight!? > For Liberty!
#   Kite > Collar-and-Elbow > German Suplex (lightning) > Flip > Why do you fight!? > a finisher
#   Collar-and-Elbow > Knife-Edge Chop > Dropkick
const DOGOOD_MOVES := {
	"collar_grab": {
		"name": "Collar-and-Elbow", "group": "attack", "time": 2, "energy": 1, "damage": 1,
		"pose": &"grab", "reach": Rect2(-6, -42, 52, 68),
		"wrestle": {"duration": 0.4, "contact": [0.06, 0.2], "player": [[0.0, Vector2.ZERO], [0.15, Vector2(6, 0)]],
			"hold": [[0.0, Vector2(20, -4)]], "impact": 0.0, "impact_sound": "hit"},
		"momentum": Vector2.ZERO,
		"hint": "Grab and hold the enemy in front of him",
	},
	"knife_chop": {
		"name": "Knife-Edge Chop", "group": "attack", "time": 2, "energy": 2, "damage": 2,
		"pose": &"chop", "reach": Rect2(-6, -42, 52, 66),
		"wrestle": {"duration": 0.4, "contact": [0.12, 0.2], "player": [[0.0, Vector2.ZERO], [0.16, Vector2(4, 0)]],
			"hold": [[0.0, Vector2(18, -6)]], "impact": 0.0, "impact_sound": "heavy_hit", "release": 0.0, "flash": true},
		"momentum": Vector2(100, -170), # Pops it up and away a little.
		"hint": "A chest-slapping chop that pops the enemy up",
	},
	"german_suplex": {
		"name": "German Suplex", "group": "attack", "time": 4, "energy": 3, "damage": 3,
		"pose": &"suplex", "reach": Rect2(-6, -42, 50, 68),
		"wrestle": {"duration": 1.0, "contact": [0.0, 0.1],
			"hold": [[0.0, Vector2(16, -2)], [0.25, Vector2(10, -26)], [0.4, Vector2(-4, -38)], [0.52, Vector2(-22, -22)], [0.58, Vector2(-26, 14)]],
			"impact": 0.56, "impact_sound": "slam", "dust": true, "release": 0.6},
		"momentum": Vector2(-60, -270), # Bounces up behind him.
		"hint": "Arch over backward, spiking the enemy behind him",
	},
	"flying_ddt": {
		"name": "Flying DDT", "group": "attack", "time": 3, "energy": 2, "damage": 3,
		"pose": &"ddt", "reach": Rect2(-4, -66, 60, 88),
		"wrestle": {"duration": 0.8, "contact": [0.08, 0.35],
			"player": [[0.0, Vector2.ZERO], [0.3, Vector2(16, -30)], [0.4, Vector2(20, -32)], [0.62, Vector2(22, 40)]],
			"hold": [[0.0, Vector2(14, -8)], [0.4, Vector2(12, -8)], [0.6, Vector2(16, 30)]],
			"impact": 0.58, "impact_sound": "slam", "dust": true, "release": 0.62},
		"momentum": Vector2(40, -240), # Bounces up off the floor.
		"hint": "Leap, hook the head and drive it into the floor",
	},
	"dropkick": {
		"name": "Dropkick", "group": "attack", "time": 3, "energy": 2, "damage": 2,
		"pose": &"dropkick", "reach": Rect2(2, -50, 64, 68),
		"wrestle": {"duration": 0.8, "contact": [0.12, 0.3],
			"player": [[0.0, Vector2.ZERO], [0.15, Vector2(6, -16)], [0.3, Vector2(14, -20)], [0.55, Vector2(10, 40)]],
			"hold": [[0.0, Vector2(26, -14)]], "impact": 0.0, "impact_sound": "heavy_hit", "release": 0.0},
		"momentum": Vector2(300, -140), # Sent flying.
		"hint": "Both boots to the chest: sends the enemy flying",
	},
	"kite_experiment": {
		"name": "Kite Experiment", "group": "attack", "time": 2, "energy": 1,
		"pose": &"kite", "kite": Vector2(-40, -66),
		"hint": "Fly a kite into the storm. Throw an enemy into it!",
	},
	# "Why do you fight!?": a stance of finishers that each end it, launching the enemy
	# far away in a different direction.
	"for_liberty": {
		"name": "For Liberty!", "group": "attack", "time": 2, "energy": 3, "damage": 4, "stance": "why", "ends_stance": true,
		"pose": &"liberty", "reach": Rect2(-6, -74, 60, 102), "shout": "FOR LIBERTY!",
		"wrestle": {"duration": 0.7, "contact": [0.1, 0.35],
			"player": [[0.0, Vector2.ZERO], [0.25, Vector2(4, -22)], [0.45, Vector2(4, -24)], [0.7, Vector2(4, 12)]],
			"hold": [[0.0, Vector2(16, -12)]], "impact": 0.0, "impact_sound": "heavy_slash", "release": 0.0},
		"momentum": Vector2(50, -580), # Straight up, high.
		"hint": "A leaping lariat that sends the enemy skyward",
	},
	"for_my_countrymen": {
		"name": "For my Countrymen!", "group": "attack", "time": 2, "energy": 3, "damage": 4, "stance": "why", "ends_stance": true,
		"pose": &"countrymen", "reach": Rect2(-6, -72, 62, 98), "shout": "FOR MY COUNTRYMEN!",
		"wrestle": {"duration": 0.5, "contact": [0.0, 0.3], "player": [[0.0, Vector2.ZERO], [0.3, Vector2(48, 0)], [0.5, Vector2(52, 0)]],
			"hold": [[0.0, Vector2(22, -6)]], "impact": 0.0, "impact_sound": "heavy_slash", "release": 0.0},
		"momentum": Vector2(560, -120), # Far across the ground.
		"hint": "A charging lariat that hurls the enemy far ahead",
	},
	"for_the_future": {
		"name": "For the Future!", "group": "attack", "time": 2, "energy": 3, "damage": 4, "stance": "why", "ends_stance": true,
		"pose": &"future", "reach": Rect2(-6, -72, 60, 98), "shout": "FOR THE FUTURE!",
		"wrestle": {"duration": 0.8, "contact": [0.0, 0.12],
			"hold": [[0.0, Vector2(16, -4)], [0.25, Vector2(6, -24)], [0.4, Vector2(-8, -36)]],
			"impact": 0.4, "impact_sound": "heavy_slash", "release": 0.42},
		"momentum": Vector2(-420, -380), # Far up and behind him.
		"hint": "Hurl the enemy far over his head behind him",
	},
	"jump": {"name": "Jump", "group": "action", "time": 1, "energy": 0},
	"dash": {"name": "Dash", "group": "action", "time": 1, "energy": 0},
	"wait": {"name": "Wait", "group": "action", "time": 1, "energy": 0},
	"exit_stance": {"name": "Exit Stance", "group": "action", "time": 0, "energy": 0},
	"why_fight": {"name": "Why do you fight!?", "group": "stance", "time": 1, "energy": 1,
		"enters_stance": "why", "pose": &"why_enter", "enter_seconds": 0.7, "enter_sound": "heavy_hit",
		"shout": "WHY DO YOU FIGHT!?", "hint": "Take a stand. Its finishers end the combo"},
	"flip": {"name": "Flip", "group": "action", "time": 0, "energy": 0, "standalone": true},
}

# Ilyra the elven arch-mage's moves: cheap staff strikes to put the enemy where she
# wants it, and expensive spells that take a while to land but hit hard and set up
# what comes next (see _step_spells and the SPELL constants above). Spells cost 1
# Time to cast and then stay on the field, acting as later moves pass Time:
#   Homing Fireball: flies out and homes in; whatever its path crosses (even between
#     frames) sets it off, blasting the enemy up and away.
#   Stormcloud: a cloud far ahead and above her; 4 Time later it fires a lightning
#     column straight down, slamming anything under it into the ground.
#   Verdant Snare: a rune on the ground ahead; the enemy passing over it is rooted.
#   Gravity Well: a vortex up ahead; after 2 Time it drags the enemy in for 3, then
#     implodes, leaving it hanging at its center.
# Typical: Stormcloud > Staff Jab > Home Run Swing (the enemy flies out under the
# cloud) > Wait > the bolt; or Gravity Well > Home Run Swing > Wait ... > Fireball.
const ELF_MOVES := {
	"staff_jab": {
		"name": "Staff Jab", "group": "attack", "time": 1, "energy": 0, "damage": 1,
		"pose": &"jab", "reach": Rect2(-4, -36, 50, 56),
		"wrestle": {"duration": 0.33, "contact": [0.06, 0.14], "hold": [[0.0, Vector2(18, -4)]],
			"impact": 0.0, "impact_sound": "hit", "release": 0.0, "flash": true},
		"momentum": Vector2(50, -30),
		"hint": "A quick poke: little knockback",
	},
	"home_run": {
		"name": "Home Run Swing", "group": "attack", "time": 2, "energy": 1, "damage": 2,
		"pose": &"homerun", "reach": Rect2(-8, -46, 60, 70),
		"wrestle": {"duration": 0.58, "contact": [0.17, 0.27], "hold": [[0.0, Vector2(22, -6)]],
			"impact": 0.0, "impact_sound": "heavy_hit", "release": 0.0, "flash": true},
		"momentum": Vector2(430, -90), # Out of the park.
		"hint": "A full swing: sends the enemy far across",
	},
	"meteor_staff": {
		"name": "Meteor Staff", "group": "attack", "time": 2, "energy": 1, "damage": 2, "airborne_only": true,
		"pose": &"meteor", "reach": Rect2(-6, -30, 54, 76),
		"wrestle": {"duration": 0.6, "contact": [0.2, 0.4], "player": [[0.0, Vector2.ZERO], [0.25, Vector2(4, -10)], [0.5, Vector2(8, 40)]],
			"hold": [[0.0, Vector2(14, 12)]], "impact": 0.0, "impact_sound": "heavy_hit", "release": 0.0, "dust": true},
		"momentum": Vector2(40, 420), # Spiked into the ground.
		"hint": "Somersault and slam the staff down",
	},
	"fireball": {"name": "Homing Fireball", "group": "spell", "time": 1, "energy": 4, "pose": &"cast_fireball",
		"spell": "fireball", "cast_at": 0.3, "duration": 0.6, "hint": "Slow, homing, and it hits hard"},
	"stormcloud": {"name": "Stormcloud", "group": "spell", "time": 1, "energy": 4, "pose": &"cast_cloud",
		"spell": "cloud", "cast_at": 0.35, "duration": 0.7, "hint": "4 Time later, lightning strikes below it"},
	"verdant_snare": {"name": "Verdant Snare", "group": "spell", "time": 1, "energy": 3, "pose": &"cast_snare",
		"spell": "snare", "cast_at": 0.3, "duration": 0.6, "hint": "A rune that roots whatever crosses it"},
	"gravity_well": {"name": "Gravity Well", "group": "spell", "time": 1, "energy": 3, "pose": &"cast_well",
		"spell": "well", "cast_at": 0.3, "duration": 0.7, "hint": "Wakes after 2 Time, pulls, then implodes"},
	"jump": {"name": "Jump", "group": "action", "time": 1, "energy": 0},
	"blink": {"name": "Blink", "group": "action", "time": 1, "energy": 1, "hint": "Teleport a short way forward"},
	"wait": {"name": "Wait", "group": "action", "time": 1, "energy": 0, "hint": "Let Time pass for your spells"},
	"flip": {"name": "Flip", "group": "action", "time": 0, "energy": 0, "standalone": true},
}

const CHARACTER_MOVES := {"saint": SAINT_MOVES, "dogood": DOGOOD_MOVES, "elf": ELF_MOVES}

## The moves of whoever's playing (see Characters.selected).
var MOVES: Dictionary = CHARACTER_MOVES.get(Characters.selected, SAINT_MOVES)

var time := 0
var energy := float(MAX_ENERGY)
var time_stopped := false

var _enemy # The staggered enemy (CharacterBody2D with a stagger_meter).
var _busy := false
var _ending := false
var _frozen_animators := []
var _effects: Node
var _momentum := {} # body -> Vector2 velocity (px/s) during a Stagger Break
var _timeline_ghost: Node2D # Loops the planned timeline, in grey.
var _candidate_ghost: Node2D # Loops the highlighted move from the timeline's end, in gold.
## The combo planned so far this Stagger Break, in order. Each step is
## {id, plan: ComboPlan, time_before, energy_before}; each plan starts where the
## previous one ends. The real bodies stay at the break's starting state until FINISH.
var _timeline: Array[Dictionary] = []
var _timeline_version := 0 # Bumped whenever _timeline changes.
var _previewed_version := -1 # The _timeline_version the grey ghosts are looping.

var _hp_label: Label
var _hp_fill: ColorRect
var _time_label: Label
var _time_fill: ColorRect
var _energy_label: Label
var _energy_fill: ColorRect
var _buff_row: HBoxContainer # Green squares beside the HUD, one per active buff.
var _buff_widgets := {} # buff name -> {"box": Control, "timer": ColorRect}
var _theme: Theme
var _menu: PanelContainer
var _move_buttons := {} # move id -> Button
var _button_ids := {} # Button -> move id
var _undo_button: Button
var _finish_button: Button
var _hint_label: Label
var _last_focused: Button
var _timeline_panel: PanelContainer
var _timeline_box: VBoxContainer
var _timeline_buttons := {} # Button -> timeline step index
var _flip_button: Button
var _menu_scroll: ScrollContainer
var _menu_list: VBoxContainer
var _submenu: PanelContainer # Left / Right choice for directional moves.
var _submenu_buttons := {} # Button -> {id, direction} it commits
var _submenu_box: VBoxContainer
var _group_headers := {} # menu group -> its header Label
var _submenu_move := "" # The move the submenu is open for; "" when closed.
var _quiet_focus := false # Set while the code moves focus, so no cursor sound plays.
var _dragging_camera := false

@onready var player = %Player


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 16
	_build_hud(theme)
	_build_menu(theme)
	_build_timeline_panel(theme)
	_update_hud()
	_effects = BreakEffects.new()
	add_child(_effects)
	_timeline_ghost = GhostPreview.new()
	add_child(_timeline_ghost)
	_candidate_ghost = GhostPreview.new()
	add_child(_candidate_ghost)
	_candidate_ghost.z_index += 1 # In front of the timeline ghosts.
	_add_extra_keys()


func _process(delta: float) -> void:
	if not time_stopped:
		energy = minf(energy + ENERGY_REGEN_PER_SECOND * delta, MAX_ENERGY)
	_update_hud()


func _exit_tree() -> void:
	Engine.time_scale = 1.0 # In case the scene is reset mid-combo.


func _unhandled_input(event: InputEvent) -> void:
	if not time_stopped or _busy:
		return
	if event.is_action_pressed("ui_cancel"):
		if _submenu_move != "":
			_close_submenu()
		else:
			_undo()
		get_viewport().set_input_as_handled()
	# F: Flip, from anywhere in the planning menu.
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		if _flip_button.visible and not _flip_button.disabled:
			_close_submenu(false)
			_on_move_pressed("flip")
		get_viewport().set_input_as_handled()
	# Clicking and dragging on the map (anywhere the UI doesn't catch) pans the camera.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_camera = event.pressed
	elif event is InputEventMouseMotion and _dragging_camera:
		var camera := get_viewport().get_camera_2d()
		if camera:
			camera.offset -= event.relative / camera.zoom


# --- Stagger Break ---------------------------------------------------------

func start_stagger_break(enemy: CharacterBody2D) -> void:
	if time_stopped:
		return
	time_stopped = true
	_enemy = enemy
	time = MAX_TIME
	enemy.velocity = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.face(enemy.global_position.x >= player.global_position.x)
	# Combo moves shouldn't be blocked by the two bodies bumping into each other.
	player.add_collision_exception_with(enemy)
	enemy.add_collision_exception_with(player)
	_momentum = {player: Vector2.ZERO, enemy: Vector2.ZERO}
	_set_world_frozen(true)
	_projectiles = get_tree().get_nodes_in_group("enemy_projectiles")
	_projectile_start = _projectiles.map(func(node) -> Dictionary: return node.state())
	_effects.play_break(enemy.get_node("enemy_collision").global_position)
	_timeline.clear()
	_timeline_version += 1
	_rebuild_timeline_list()
	_last_focused = null
	_dragging_camera = false
	if not player.is_airborne():
		await _play_intro()
		if not time_stopped:
			return
	_menu.show()
	_fit_menu_height()
	_timeline_panel.show()
	_refresh_menu()


## On the ground, a Stagger Break opens with him turning away with a flourish of
## his cape, then sitting cross-legged, arms folded, eyes closed: planning the combo.
## The menu (and ghost previews) wait for it, or for INTRO_TIMEOUT as a failsafe.
func _play_intro() -> void:
	_busy = true
	player.charging_player_sprite.visible = false
	player.player_sprite.visible = true
	player.player_sprite.play(player.intro_animation)
	var done := [false]
	var finish := func() -> void: done[0] = true
	player.player_sprite.animation_finished.connect(finish, CONNECT_ONE_SHOT)
	get_tree().create_timer(INTRO_TIMEOUT).timeout.connect(finish)
	while not done[0] and time_stopped:
		await get_tree().process_frame
	if player.player_sprite.animation_finished.is_connected(finish):
		player.player_sprite.animation_finished.disconnect(finish)
	_busy = false


func end_stagger_break() -> void:
	if not time_stopped or _busy or _ending:
		return
	_ending = true
	time = 0
	_menu.hide()
	_submenu.hide()
	_submenu_move = ""
	_timeline_panel.hide()
	_stop_ghosts()
	_timeline.clear()
	_recenter_camera()
	# Wait out the frame that confirmed FINISH, so its key press (Space is also
	# "jump") doesn't leak into real-time play.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(_enemy):
		# Enemies beaten during the combo go down once time starts again.
		if _enemy.get("hp") != null and _enemy.hp <= 0 and _enemy.has_method("die"):
			_enemy.die()
	if is_instance_valid(_enemy):
		_enemy.stagger_meter.reset()
		_enemy.velocity = Vector2.ZERO
		player.remove_collision_exception_with(_enemy)
		_enemy.remove_collision_exception_with(player)
	player.velocity = Vector2.ZERO
	_momentum.clear()
	for node in _spell_nodes: # Spells only last the Stagger Break.
		if is_instance_valid(node):
			var fade: Tween = node.create_tween()
			fade.tween_property(node, "modulate:a", 0.0, 0.5)
			fade.tween_callback(node.queue_free)
	_spell_nodes.clear()
	if _kite_node and is_instance_valid(_kite_node):
		var kite := _kite_node
		_kite_node = null
		var away := kite.create_tween()
		away.tween_property(kite, "global_position", kite.global_position + Vector2(-120, -160), 1.2)
		away.parallel().tween_property(kite, "modulate:a", 0.0, 1.2)
		away.tween_callback(kite.queue_free)
	_set_world_frozen(false)
	_effects.set_filter_active(false)
	_enemy = null
	time_stopped = false
	_ending = false


func _on_move_pressed(id: String) -> void:
	if _busy or _at_cursor(_unavailable_reason.bind(id)) != "":
		return
	if _cancels_last_step(id):
		_undo() # Plays the cancel sound.
		return
	Sfx.play(self, "menu_confirm")
	if MOVES[id].get("directional", false) or MOVES[id].has("submenu"):
		_open_submenu(id)
	else:
		_commit_move(id)


## Adds a move to the end of the planned timeline. Nothing real happens until FINISH.
## `direction` (-1 left, 1 right) is for directional moves; 0 keeps the current facing.
func _commit_move(id: String, direction := 0) -> void:
	if _busy or _at_cursor(_unavailable_reason.bind(id)) != "":
		return
	if _cancels_last_step(id):
		_undo()
		return
	var move: Dictionary = MOVES[id]
	if move.has("submenu"):
		return # Not a move itself; its submenu entries are.
	var stance := _stance_after(id, _cursor_stance())
	_timeline.append({"id": id, "direction": direction, "plan": _plan_move(id, direction),
		"time_before": time, "energy_before": energy, "stance_after": stance})
	_timeline_version += 1
	time -= move.time
	energy -= move.energy
	_rebuild_timeline_list()
	_refresh_menu()


## The stance the player is in at the end of the planned timeline ("" for none).
func _cursor_stance() -> String:
	return "" if _timeline.is_empty() else _timeline[-1].stance_after


func _stance_after(id: String, before: String) -> String:
	if id == "exit_stance" or MOVES[id].get("ends_stance", false):
		return ""
	return MOVES[id].get("enters_stance", before)


## Whether a move is offered at all in `stance` ("" for none): in a stance, only its
## own attacks, Wait and Exit Stance; out of one, everything but those.
func _shown_in_stance(id: String, stance: String) -> bool:
	var move: Dictionary = MOVES[id]
	if stance == "":
		return not move.has("stance") and id != "exit_stance"
	return move.get("stance", "") == stance or id == "wait" or id == "exit_stance"


## A Flip straight after a Flip just undoes the first one.
func _cancels_last_step(id: String) -> bool:
	return id == "flip" and not _timeline.is_empty() and _timeline[-1].id == "flip"


func _undo() -> void:
	if not _timeline.is_empty():
		_rewind_to(_timeline.size() - 1)


func _on_timeline_step_pressed(index: int) -> void:
	_rewind_to(index)


## Removes timeline step `index` and everything after it, refunding their costs.
func _rewind_to(index: int) -> void:
	if _busy or index < 0 or index >= _timeline.size():
		return
	Sfx.play(self, "menu_cancel")
	_close_submenu(false)
	time = _timeline[index].time_before
	energy = _timeline[index].energy_before
	_timeline.resize(index)
	_timeline_version += 1
	_rebuild_timeline_list()
	_refresh_menu()


## Commits the plan: the real player and enemy perform the whole timeline at normal
## speed, then the Stagger Break ends.
func _finish() -> void:
	if _busy or not time_stopped:
		return
	_busy = true
	Sfx.play(self, "menu_confirm")
	_menu.hide()
	_submenu.hide()
	_submenu_move = ""
	_timeline_panel.hide()
	_stop_ghosts()
	_recenter_camera()
	if not _timeline.is_empty():
		# The plan is played FINISH_SPEED frames per tick; the engine's time scale
		# speeds up animations, particles and tweens to match.
		Engine.time_scale = FINISH_SPEED
		_effects.set_speed_lines_active(true)
		await _play_plan(_combined_plan(_timeline_plans()), FINISH_SPEED)
		_effects.set_speed_lines_active(false)
		Engine.time_scale = 1.0
	_busy = false
	end_stagger_break()


func _timeline_plans() -> Array:
	return _timeline.map(func(step: Dictionary) -> ComboPlan: return step.plan)


## Joins plans end to end into one (each already starts where the previous ends).
func _combined_plan(plans: Array) -> ComboPlan:
	var combined := ComboPlan.new()
	for plan in plans:
		var offset := combined.frames.size()
		for index in plan.events:
			combined.events[offset + index] = combined.events.get(offset + index, []) + plan.events[index]
		combined.frames.append_array(plan.frames)
		combined.momentum = plan.momentum
		combined.facing_right = plan.facing_right
		combined.projectiles = plan.projectiles
		combined.kite = plan.kite
		combined.spells = plan.spells
	return combined


# --- Timeline cursor -----------------------------------------------------------
# While planning, the real bodies stay at the break's starting state. Anything that
# depends on where the bodies are (planning the next move, whether a move is usable,
# reach hints) is evaluated at the end of the planned timeline instead, by briefly
# moving the bodies there with _at_cursor() and back again.

func _capture_state() -> Dictionary:
	return {"player": player.global_position, "enemy": _enemy.global_position,
		"facing_right": player.facing_right, "momentum": _momentum.duplicate(),
		"cloak": player.cloak.momentum, "projectiles": _copy_states(_projectile_start), "kite": {},
		"spells": [], "pin": 0}


func _apply_state(state: Dictionary) -> void:
	player.global_position = state.player
	_enemy.global_position = state.enemy
	player.face(state.facing_right)
	_momentum = state.momentum.duplicate()
	player.cloak.momentum = state.cloak


## The state at the end of the planned timeline.
func _cursor_state() -> Dictionary:
	if _timeline.is_empty():
		return _capture_state()
	var plan: ComboPlan = _timeline[-1].plan
	return {"player": plan.frames[-1].player, "enemy": plan.frames[-1].enemy,
		"facing_right": plan.facing_right, "momentum": plan.momentum, "cloak": plan.frames[-1].cloak,
		"projectiles": _copy_states(plan.projectiles), "kite": plan.kite.duplicate(),
		"spells": _copy_states(plan.spells), "pin": plan.pin}


## Calls `fn` with the bodies moved to the end of the timeline, then puts them back.
func _at_cursor(fn: Callable) -> Variant:
	var real := _capture_state()
	_apply_state(_cursor_state())
	var result = fn.call()
	_apply_state(real)
	return result


# --- Planning ----------------------------------------------------------------
# A move is worked out ahead of time, one physics frame at a time, into a ComboPlan:
# where the player and enemy are on every frame, the rope's shape, and timed events
# (sounds, sword swings, sparkles...). The ghost preview loops the plan; confirming
# the move plays the same plan on the real bodies. Planning moves the real bodies
# through the level (so collisions are exact) and puts them back before returning.

## A move worked out frame by frame. See the comment above.
func _copy_states(states: Array) -> Array:
	return states.map(func(state: Dictionary) -> Dictionary: return state.duplicate())


class ComboPlan:
	var frames: Array[Dictionary] = [] # {player, enemy, cloak (momentum): Vector2, rope: {from, to, sag} or {}}
	var events := {} # frame index -> Array of [kind, args...], fired before that frame shows
	var momentum := {} # body -> momentum after the move
	var projectiles := [] # Projectile states after the move
	var facing_right := true
	var interrupted := false # The player was hit during the move, cutting it short.
	var storm := false # The player has the Storm buff by the end of the move.
	var kite := {} # Dogood's kite after the move: {pos, alive, ready}, or {} if none.
	var spells := [] # Ilyra's spells after the move (see _step_spells).
	var pin := 0 # Frames the enemy stays rooted after the move.
	var detonations: Array[String] = [] # Spells (and the kite) that hit during it, for the timeline.

	func add_event(event: Array) -> void:
		if not events.has(frames.size()):
			events[frames.size()] = []
		events[frames.size()].append(event)


var _plan: ComboPlan # The plan being built, during _plan_move().
var _plan_cloak := Vector2.ZERO # The cloak's momentum while planning (see _step()).
var _plan_last_player := Vector2.ZERO
var _plan_cloak_settles := false
var _plan_stance := "" # The stance the move being planned leaves the player in.
# Enemy projectiles (fireballs) during a Stagger Break. They stay where they were
# when time stopped, but each planned step simulates them (see _step_projectiles), so
# each timeline step records where they are; the real nodes are shown at the end of
# the timeline. States are {pos, vel, age, alive}, one per node in _projectiles.
var _projectiles: Array = []
var _projectile_start: Array = []
var _plan_projectiles: Array = []
var _plan_projectile_steps := 0 # Frames of the move during which time passes.
var _plan_invulnerable := 0 # Frames left of the player's post-hit invulnerability.
var _plan_hit_frame := -1 # Frame the player was first hit on during this move (-1: not hit).
var _plan_storm := false # Whether the player has the Storm buff (so swings crackle).
var _plan_kite := {} # Dogood's kite while planning: {pos, alive, ready}, or {}.
var _plan_spells: Array = [] # Ilyra's spells while planning: {kind, pos, age, alive, ...}
var _plan_spell_steps := 0 # Frames of the move during which spells age (its Time).
var _plan_pin := 0 # Frames the enemy is rooted (it doesn't drift).
var _plan_prev_enemy := Vector2.ZERO # The enemy's center at the last recorded frame.
var _spell_nodes: Array = [] # Shows the spells, by index.
var _kite_node: Node2D # Shows the kite (at the timeline's end while planning).
var _plan_hit_from := Vector2.ZERO
var _plan_drift := {} # body -> drift steps left while planning
var _rope := {} # Rope state while planning; empty when there's no rope.


## Plans `id` starting from the end of the timeline. A `direction` (-1 left, 1 right)
## turns the player that way first; 0 keeps the current facing.
func _plan_move(id: String, direction := 0) -> ComboPlan:
	var move: Dictionary = MOVES[id]
	var real := _capture_state()
	var cursor := _cursor_state()
	_apply_state(cursor)
	_plan = ComboPlan.new()
	_plan_projectiles = cursor.projectiles
	_plan_kite = cursor.kite.duplicate()
	_plan_spells = _copy_states(cursor.spells)
	_plan_pin = cursor.pin
	_plan_spell_steps = _frames(move.time * TIME_UNIT)
	_plan_prev_enemy = _enemy_center()
	_plan_projectile_steps = _frames(move.time * TIME_UNIT)
	_plan_invulnerable = 0
	_plan_hit_frame = -1
	_plan_storm = player.has_buff("storm") if _timeline.is_empty() else _timeline[-1].plan.storm
	if direction != 0:
		player.face(direction > 0)
		_plan.add_event(["face", direction > 0])
	_rope = {}
	_plan_drift.clear()
	_plan_cloak = player.cloak.momentum
	_plan_last_player = player.global_position
	_plan_cloak_settles = id == "wait" or id == "tp_down"
	var started_airborne: bool = player.is_airborne()
	_plan_stance = _cursor_stance()
	var start_pose := _rest_pose()
	_plan_stance = _stance_after(id, _plan_stance)
	if move.get("flip_facing", false):
		player.face(not player.facing_right)
		_plan.add_event(["face", player.facing_right])
	if id == "wait" and started_airborne:
		_plan.add_event(["player_anim", &"fall"])

	# Bodies this move doesn't drive drift on their momentum while its Time passes.
	var driven := _driven_bodies(id, move)
	for body in [player, _enemy]:
		if body not in driven:
			_plan_drift[body] = _frames(move.time * TIME_UNIT)
	if _enemy in driven:
		_momentum[_enemy] = _facing_vector(move.momentum)

	match id:
		"jump":
			_plan_jump()
		"tp_down":
			_plan_tp_down()
		"dive":
			_plan_dive()
		"dash":
			_plan_dash()
		"blink":
			_plan_blink()
		"iai", "why_fight":
			_plan_enter_stance(move)
		"exit_stance":
			_plan.add_event(["player_anim", &"idle"])
			_plan_hold(_frames(0.15))
		"flip":
			_plan_flip()
		"wait":
			pass
		_:
			if move.has("spell"):
				_plan_cast(move)
			elif move.has("wrestle"):
				_plan_wrestle(move)
			elif move.has("kite"):
				_plan_kite_flight(move)
			elif move.has("grapple"):
				_plan_grapple(move)
			elif move.has("gather"):
				_plan_gather_clouds(move)
			elif move.has("usurp"):
				_plan_usurp(move)
			elif move.has("pinpoint"):
				_plan_pinpoint_strike(move)
			elif move.has("running"):
				_plan_running_slash(move)
			else:
				_plan_attack(move)
	while _plan_drift.values().any(func(steps: int) -> bool: return steps > 0):
		_step()
	var interrupted := _plan_hit_frame >= 0
	if interrupted:
		_interrupt(move)
	if started_airborne and not player.is_airborne():
		_plan.add_event(["player_anim", &"land"])
	# Every step starts in a definite pose (so nothing carries over from the Stagger
	# Break intro, where he's sitting down), unless the move sets its own right away.
	var opening: Array = _plan.events.get(0, [])
	if not opening.any(func(event: Array) -> bool: return event[0] == "player_anim"):
		_plan.events[0] = [["player_anim", start_pose]] + opening

	var plan := _plan
	plan.momentum = _momentum.duplicate()
	plan.projectiles = _copy_states(_plan_projectiles)
	plan.facing_right = player.facing_right
	plan.interrupted = interrupted
	plan.storm = _plan_storm
	plan.kite = _plan_kite.duplicate()
	plan.spells = _copy_states(_plan_spells)
	plan.pin = _plan_pin
	_apply_state(real)
	_plan = null
	return plan


## Ends one frame of the plan: drifting bodies take a step, then everything is recorded.
func _step() -> void:
	for body in _plan_drift:
		if _plan_drift[body] > 0:
			_plan_drift[body] -= 1
			_drift(body, 1.0 / Engine.physics_ticks_per_second)
	var rope := {}
	if not _rope.is_empty():
		var hand := _hand_position()
		var to: Vector2
		match _rope.mode:
			"travel": to = _rope.start.lerp(_enemy_center() if _rope.hit else _rope.miss_aim, _rope.t)
			"retract": to = _rope.miss_aim.lerp(hand, _rope.t)
			"attached": to = _enemy_center()
		rope = {"from": hand, "to": to, "sag": _rope.sag}
	_step_cloak()
	_step_projectiles()
	_step_kite()
	_step_spells()
	_plan.frames.append({"player": player.global_position, "enemy": _enemy.global_position,
		"cloak": _plan_cloak, "rope": rope, "enemy_vel": _momentum.get(_enemy, Vector2.ZERO),
		"projectiles": _copy_states(_plan_projectiles), "kite": _plan_kite.duplicate(),
		"spells": _copy_states(_plan_spells), "pin": _plan_pin})


## One frame of the enemy projectiles (fireballs, earth spikes...), while the move's
## Time is passing: each advances by its own rules (plan_advance, as in real time),
## goes out when it's done or (fireballs) on terrain, and may hit the player. A hit is
## recorded (a reel and -1 HP when it plays out) and cuts the move short (_interrupt).
func _step_projectiles() -> void:
	_plan_invulnerable = maxi(_plan_invulnerable - 1, 0)
	if _plan_projectile_steps <= 0:
		return
	_plan_projectile_steps -= 1
	var delta := 1.0 / Engine.physics_ticks_per_second
	var body := _player_rect()
	for i in _plan_projectiles.size():
		var state: Dictionary = _plan_projectiles[i]
		if not state.alive or not is_instance_valid(_projectiles[i]):
			continue
		var node = _projectiles[i]
		var ending: String = node.plan_advance(state, body, delta)
		if ending != "" or (node.ends_on_terrain and _solid_at(state.pos)):
			_kill_projectile(i)
		elif _plan_invulnerable == 0 and node.plan_hits_player(state, body):
			if node.ends_on_terrain: # Fireballs go out on whatever they hit.
				_kill_projectile(i)
			_plan_invulnerable = _frames(player.INVULNERABLE_SECONDS)
			_plan.add_event(["player_anim", &"reel"])
			_plan.add_event(["player_hit"])
			if _plan_hit_frame < 0:
				_plan_hit_frame = _plan.frames.size()
				_plan_hit_from = state.pos


func _kill_projectile(index: int) -> void:
	_plan_projectiles[index].alive = false
	_plan.add_event(["projectile_end", index, _plan_projectiles[index].duplicate()])


## Whether level geometry (not a character) is at `point`.
func _solid_at(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	for hit in player.get_world_2d().direct_space_state.intersect_point(query, 8):
		var collider: Object = hit.collider
		if collider != player and not (collider is Node and collider.is_in_group("enemies")):
			return true
	return false


## The player's attacks cut projectiles inside their hitbox (those that can be cut).
func _cut_projectiles(move: Dictionary) -> void:
	for i in _plan_projectiles.size():
		if _plan_projectiles[i].alive and is_instance_valid(_projectiles[i]) and _projectiles[i].cuttable \
				and _hits_point(move, _plan_projectiles[i].pos):
			_kill_projectile(i)


## The player's collision box, in world space.
func _player_rect() -> Rect2:
	var collision: CollisionShape2D = player.get_node("player_collision")
	var extents: Vector2 = collision.shape.get_rect().size * collision.global_scale.abs()
	return Rect2(collision.global_position - extents / 2.0, extents)


## Cuts the move being planned short at the frame the player was hit: everything
## after it is dropped, and for the rest of the move's Time he's knocked back and
## reels while everything else carries on (the enemy on the momentum it had then).
func _interrupt(move: Dictionary) -> void:
	var k := _plan_hit_frame
	var frame: Dictionary = _plan.frames[k]
	_plan.frames.resize(k + 1)
	for index in _plan.events.keys():
		if index > k:
			_plan.events.erase(index)
	player.global_position = frame.player
	_enemy.global_position = frame.enemy
	_plan_cloak = frame.cloak
	_plan_last_player = frame.player
	_plan_projectiles = _copy_states(frame.projectiles)
	_plan_kite = frame.kite.duplicate()
	_plan_spells = _copy_states(frame.spells)
	_plan_pin = frame.pin
	_plan_prev_enemy = _enemy_center()
	_rope = {}
	var away := signf(_player_center().x - _plan_hit_from.x)
	if away == 0.0:
		away = -_facing()
	_momentum[player] = Vector2(PLAYER_KNOCKBACK.x * away, PLAYER_KNOCKBACK.y)
	_momentum[_enemy] = frame.enemy_vel
	var remaining := maxi(_frames(move.time * TIME_UNIT) - (k + 1), 0)
	_plan_drift.clear()
	_plan_drift[player] = remaining
	_plan_drift[_enemy] = remaining
	_plan_projectile_steps = remaining
	_plan_spell_steps = remaining
	_plan_invulnerable = maxi(_frames(player.INVULNERABLE_SECONDS) - 1, 0)
	_plan_hit_frame = -1
	for i in remaining:
		_step()
	_plan_hit_frame = -1


## The cloak's stylised momentum, one frame on: it takes on the player's motion
## when that's about as strong as the cloak's (or heads somewhere clearly
## different), and otherwise holds, so a move winding down, or an attack that doesn't
## move him, keeps the swirl of whatever moved him last. Only Wait and TP Down let it
## settle, once he's on the ground.
func _step_cloak() -> void:
	var velocity: Vector2 = (player.global_position - _plan_last_player) * Engine.physics_ticks_per_second
	_plan_last_player = player.global_position
	var speed := velocity.length()
	var new_direction := _plan_cloak.length() < 1.0 or velocity.normalized().dot(_plan_cloak.normalized()) < 0.5
	if speed > CLOAK_MOVING_SPEED and (speed >= _plan_cloak.length() * 0.9 or new_direction):
		_plan_cloak = _plan_cloak.lerp(velocity, 0.5)
	elif _plan_cloak_settles and not player.is_airborne():
		_plan_cloak *= exp(-player.cloak.SETTLE_RATE / Engine.physics_ticks_per_second)
	_plan_cloak = _plan_cloak.limit_length(player.cloak.MAX_MOMENTUM)


func _frames(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


## Which bodies a move moves (or holds) itself; everyone else drifts on momentum.
func _driven_bodies(id: String, move: Dictionary) -> Array:
	if id == "wait":
		return []
	if move.group in ["action", "stance", "spell"] or move.get("grapple", "") == "fly_towards":
		return [player]
	if move.has("wrestle") or move.has("kite") or move.has("spell"): # They catch the enemy themselves (or never do).
		return [player]
	# Attacks: the player hangs in place, and the enemy is driven only by a hit.
	return [player, _enemy] if _connects(move) else [player]


## One physics step of free flight: gravity, horizontal drag, and sliding along (and
## losing speed into) anything solid, so landing on the floor stops a fall.
func _drift(body: CharacterBody2D, delta: float) -> void:
	if body == _enemy and _plan_pin > 0: # Rooted (Verdant Snare) or held (Gravity Well).
		_momentum[body] = Vector2.ZERO
		return
	var velocity: Vector2 = _momentum.get(body, Vector2.ZERO)
	velocity.y += COMBO_GRAVITY * delta
	velocity.x *= exp(-HORIZONTAL_DRAG * delta)
	var collision := body.move_and_collide(velocity * delta)
	if collision:
		var normal := collision.get_normal()
		velocity = velocity.slide(normal)
		body.move_and_collide(collision.get_remainder().slide(normal))
	_momentum[body] = velocity


## Moves a body by `displacement` over `frame_count` frames with an ease-out, sliding
## along anything solid it runs into.
func _plan_sweep(body: CharacterBody2D, displacement: Vector2, frame_count: int) -> void:
	var moved := Vector2.ZERO
	for i in range(1, frame_count + 1):
		var t := float(i) / frame_count
		var offset := displacement * (1.0 - pow(1.0 - t, 3.0))
		var collision := body.move_and_collide(offset - moved)
		if collision:
			body.move_and_collide(collision.get_remainder().slide(collision.get_normal()))
		moved = offset
		_step()


func _plan_hold(frame_count: int) -> void:
	for i in frame_count:
		_step()


## A sword attack; moves with several `swings` hit (and make sounds) on each one, and
## the knockback lands with the last. Each swing is active for ACTIVE_FRAMES frames
## after it starts, so an enemy drifting into reach then is still caught.
func _plan_attack(move: Dictionary) -> void:
	var hit := _connects(move)
	_cut_projectiles(move)
	_plan.add_event(["player_anim", move.pose])
	_plan.add_event(["sword", move.sword_scene, move.animation, _plan_storm])
	if move.has("particles"):
		# Particles fall from along the blade's cut (its reach line, or particle_line).
		var line: Dictionary = move.get("particle_line", move.get("reach_line", {}))
		var dir := _facing_vector(Vector2.from_angle(deg_to_rad(line.angle)))
		_plan.add_event(["blade_particles", move.particles,
			_player_center() + dir * line.from, _player_center() + dir * line.to])
	var swings: int = move.get("swings", 1)
	var waited := 0 # Frames the last swing spent waiting for a late catch.
	for i in swings:
		_plan.add_event(["sound", "swing"])
		if hit:
			_land_hit(move)
		if i < swings - 1:
			for f in _frames(move.swing_interval):
				_step()
				if not hit and f < ACTIVE_FRAMES:
					hit = _late_contact(move)
		else:
			while not hit and waited < ACTIVE_FRAMES:
				_step()
				waited += 1
				hit = _late_contact(move)
	if hit:
		_plan_sweep(_enemy, _facing_vector(move.knockback), _frames(MOVE_DURATION))
	else:
		_plan_hold(_frames(MOVE_DURATION) - waited)
	_plan.add_event(["player_anim", _rest_pose()])


func _land_hit(move: Dictionary) -> void:
	_plan.add_event(["sound", move.get("hit_sound", "hit")])
	_plan.add_event(["damage", move.get("damage", 1)])


## One of a swing's later active frames: also cuts projectiles, and if the enemy has
## only now come into reach, catches it (it stops drifting and takes the attack's
## momentum, as if hit from the start) and, if `land`, lands the hit. Returns whether
## it caught it.
func _late_contact(move: Dictionary, land := true) -> bool:
	_cut_projectiles(move)
	if not _connects(move):
		return false
	_plan_drift[_enemy] = 0
	_momentum[_enemy] = _facing_vector(move.momentum)
	if land:
		_land_hit(move)
	return true


## Usurp the Heavens (see MOVES): lifts the sword, the sparkle appears, and if it
## touches the enemy (at any point while the sword goes up, or ACTIVE_FRAMES after),
## lightning strikes through the enemy into the sword.
func _plan_usurp(move: Dictionary) -> void:
	var hit := _connects(move)
	_plan.add_event(["player_anim", move.pose])
	_plan.add_event(["sound", "tp"])
	var raise := _frames(move.raise)
	for f in raise + ACTIVE_FRAMES:
		if f == raise:
			_plan.add_event(["sound", "ding"])
			_plan.add_event(["sparkle", _player_center() + _facing_vector(move.sparkle), 9.0, 0.5])
		_step()
		if not hit:
			hit = _late_contact(move, false)
		elif f >= raise:
			break
	if hit:
		var tip := _player_center() + _facing_vector(USURP_SWORD_TIP)
		var top := Vector2(_enemy_center().x, minf(_enemy_center().y, tip.y) - 260.0)
		_plan.add_event(["lightning", top, _enemy_center(), tip])
		_plan.add_event(["sound", move.hit_sound])
		_plan.add_event(["damage", move.damage])
		_plan.add_event(["buff", move.buff])
		_plan_storm = true
		_plan_sweep(_enemy, _facing_vector(move.knockback), _frames(MOVE_DURATION))
	else:
		_plan_hold(_frames(MOVE_DURATION))
	_plan.add_event(["player_anim", _rest_pose()])


## A wrestling move (see DOGOOD_MOVES): he moves along his path; within the contact
## window the enemy can be caught, and from then it's carried along the hold path
## (relative to him) until the impact and release; caught or not, everything else
## carries on as usual (an uncaught enemy just drifts).
func _plan_wrestle(move: Dictionary) -> void:
	var w: Dictionary = move.wrestle
	var total := _frames(w.duration)
	var contact_from := _frames(w.contact[0])
	var contact_to := _frames(w.contact[1]) + ACTIVE_FRAMES
	var budget := _frames(move.time * TIME_UNIT)
	var start := _player_center()
	var caught_at := -1
	var impacted := false
	var released := false
	_plan.add_event(["player_anim", move.pose])
	_plan.add_event(["sound", "swing"])
	if move.has("shout"):
		_plan.add_event(["shout", move.shout])
	for f in total:
		var t := float(f) / Engine.physics_ticks_per_second
		var t_next := float(f + 1) / Engine.physics_ticks_per_second
		if w.has("player"):
			_move_sliding(player, start + _facing_vector(_path(w.player, t_next)) - _player_center())
		if caught_at < 0 and f >= contact_from and f <= contact_to:
			_cut_projectiles(move)
			if _connects(move):
				caught_at = f
				_plan_pin = 0
				_plan_drift[_enemy] = 0
				_momentum[_enemy] = Vector2.ZERO
		if caught_at >= 0 and not released:
			# Ease from where it was caught onto the hold path over a few frames.
			var want := _player_center() + _facing_vector(_path(w.hold, t_next))
			var ease := clampf((f - caught_at + 1) / 4.0, 0.0, 1.0)
			_move_sliding(_enemy, _enemy_center().lerp(want, ease) - _enemy_center())
			if not impacted and t >= w.get("impact", 0.0):
				impacted = true
				_plan.add_event(["sound", w.get("impact_sound", "hit")])
				_plan.add_event(["damage", move.get("damage", 1)])
				if w.get("flash", false):
					_plan.add_event(["sparkle", _enemy_center(), 8.0, 0.2])
				if w.get("dust", false):
					_plan.add_event(["dust", _enemy_center() + Vector2(0, 6)])
			if w.has("release") and t >= w.release and f > caught_at:
				released = true
				_momentum[_enemy] = _facing_vector(move.momentum)
				_plan_drift[_enemy] = maxi(budget - f - 1, 0)
		_step()
	if caught_at >= 0 and not released:
		_momentum[_enemy] = _facing_vector(move.get("momentum", Vector2.ZERO))
	_momentum[player] = Vector2.ZERO


## The point `t` seconds along a path of [[time, offset]...], eased between keys.
func _path(keys: Array, t: float) -> Vector2:
	if t <= keys[0][0]:
		return keys[0][1]
	for i in keys.size() - 1:
		if t <= keys[i + 1][0]:
			var span: float = keys[i + 1][0] - keys[i][0]
			var u := smoothstep(0.0, 1.0, (t - keys[i][0]) / span)
			return (keys[i][1] as Vector2).lerp(keys[i + 1][1], u)
	return keys[-1][1]


## Kite Experiment: he heaves the kite up from his hand to its spot in the sky (move.kite,
## from his center), where it stays for the rest of the Stagger Break.
func _plan_kite_flight(move: Dictionary) -> void:
	_plan.add_event(["player_anim", move.pose])
	_plan.add_event(["sound", "swing"])
	var from := _player_center() + _facing_vector(Vector2(4, -14))
	var to := _player_center() + _facing_vector(move.kite)
	_plan_kite = {"pos": from, "alive": true, "ready": false}
	var rise := _frames(KITE_RISE)
	for f in rise:
		var u := 1.0 - pow(1.0 - float(f + 1) / rise, 2.0)
		_plan_kite.pos = from.lerp(to, u) + Vector2(0, -18.0 * sin(PI * u)) # A looping climb.
		_step()
	_plan_kite.ready = true
	_plan_hold(_frames(0.15))
	_momentum[player] = Vector2.ZERO


## The kite's lightning: an enemy that reaches the flying kite is struck.
func _step_kite() -> void:
	if _plan_kite.is_empty() or not _plan_kite.alive or not _plan_kite.ready:
		return
	var grow := _enemy_grow()
	if _enemy_center().distance_to(_plan_kite.pos) > KITE_RADIUS + maxf(grow.x, grow.y):
		return
	_plan_kite.alive = false
	_momentum[_enemy] = KITE_BLAST
	_plan.add_event(["lightning", _plan_kite.pos + Vector2(0, -260), _plan_kite.pos, _enemy_center()])
	_plan.add_event(["sound", "lightning"])
	_plan.add_event(["damage", KITE_DAMAGE])
	_plan.add_event(["kite_burn", _plan_kite.pos])
	_plan.detonations.append("Kite Lightning")


## Casting one of Ilyra's spells: her cast animation, and at cast_at the spell
## appears (where depends on the spell) and starts acting as Time passes.
func _plan_cast(move: Dictionary) -> void:
	_plan.add_event(["player_anim", move.pose])
	_plan.add_event(["sound", "tp"])
	var cast_frame := _frames(move.cast_at)
	for f in _frames(move.duration):
		if f == cast_frame:
			var spell := _new_spell(move.spell)
			_plan_spells.append(spell)
			_plan.add_event(["sound", "ding"])
			_plan.add_event(["sparkle", spell.pos, 8.0, 0.4])
		_step()
	_momentum[player] = Vector2.ZERO


func _new_spell(kind: String) -> Dictionary:
	var center := _player_center()
	match kind:
		"fireball":
			return {"kind": kind, "pos": center + _facing_vector(Vector2(22, -10)), "vel": _facing_vector(Vector2(FIREBALL_SPEED, 0)),
				"age": 0.0, "alive": true}
		"cloud":
			return {"kind": kind, "pos": center + _facing_vector(CLOUD_OFFSET), "age": 0.0, "delay": CLOUD_DELAY, "alive": true}
		"snare":
			var ground := _ground_below(center + _facing_vector(Vector2(SNARE_AHEAD, -20)))
			return {"kind": kind, "pos": ground, "age": 0.0, "armed": false, "alive": true}
		_:
			return {"kind": kind, "pos": center + _facing_vector(WELL_OFFSET), "age": 0.0, "wake": WELL_WAKE, "alive": true}


## The floor below `point` (or `point` itself if there's none within reach).
func _ground_below(point: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(point, point + Vector2(0, 400), 1,
		[player.get_rid(), _enemy.get_rid()])
	var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else point


## One frame of Ilyra's spells, while Time passes. Each checks the enemy's path
## since the last frame (not just where it is), so nothing slips through a spell
## between frames.
func _step_spells() -> void:
	var now := _enemy_center()
	if _plan_pin > 0:
		_plan_pin -= 1
	if _plan_spell_steps <= 0 or _plan_spells.is_empty():
		_plan_prev_enemy = now
		return
	_plan_spell_steps -= 1
	var delta := 1.0 / Engine.physics_ticks_per_second
	var grow := _enemy_grow()
	var reach := maxf(grow.x, grow.y)
	for spell in _plan_spells:
		if not spell.alive:
			continue
		spell.age += delta
		match spell.kind:
			"fireball":
				var from: Vector2 = spell.pos
				var vel: Vector2 = spell.vel
				# Homing that tightens as it flies, so it can't circle forever.
				var rate: float = FIREBALL_TURN * (1.0 + spell.age * 2.0)
				var turn := clampf(angle_difference(vel.angle(), (now - from).angle()), -rate * delta, rate * delta)
				vel = vel.rotated(turn).normalized() * FIREBALL_SPEED
				spell.vel = vel
				spell.pos = from + vel * delta
				# Swept: the enemy's path relative to the fireball this frame.
				if _segment_near(_plan_prev_enemy - from, now - spell.pos, FIREBALL_RADIUS + reach):
					_detonate(spell, "Fireball", FIREBALL_DAMAGE)
					var away := signf(now.x - spell.pos.x)
					_momentum[_enemy] = Vector2(FIREBALL_BLAST.x * (away if away != 0.0 else _facing()), FIREBALL_BLAST.y)
					_plan_pin = 0
				elif spell.age > FIREBALL_LIFE:
					spell.alive = false
					_plan.add_event(["spell_burst", "fizzle", spell.pos])
			"cloud":
				if spell.age >= spell.delay:
					var ground := _ground_below(spell.pos + Vector2(0, 8))
					if not spell.get("struck", false):
						spell.struck = true
						_plan.add_event(["spell_burst", "cloud", spell.pos + Vector2(0, 6), ground])
					var column: bool = absf(now.x - spell.pos.x) <= CLOUD_HALF_WIDTH + grow.x and now.y >= spell.pos.y and now.y <= ground.y + 4.0
					var crossed: bool = _segment_crosses_column(_plan_prev_enemy, now, spell.pos.x, CLOUD_HALF_WIDTH + grow.x) and now.y >= spell.pos.y
					if column or crossed:
						spell.alive = false
						_plan.detonations.append("Stormcloud")
						_plan.add_event(["sound", "heavy_hit"])
						_plan.add_event(["damage", CLOUD_DAMAGE])
						_momentum[_enemy] = CLOUD_SLAM
						_plan_pin = 0
					elif spell.age >= spell.delay + CLOUD_STRIKE:
						spell.alive = false
			"snare":
				spell.armed = spell.age >= SNARE_ARM
				if spell.armed:
					var zone := Rect2(spell.pos.x - SNARE_SIZE.x - grow.x, spell.pos.y - SNARE_SIZE.y - grow.y, (SNARE_SIZE.x + grow.x) * 2.0, SNARE_SIZE.y + grow.y + 4.0)
					if _segment_hits_rect(_plan_prev_enemy, now, zone):
						_detonate(spell, "Verdant Snare", SNARE_DAMAGE)
						_momentum[_enemy] = Vector2.ZERO
						_plan_pin = _frames(SNARE_ROOT)
			"well":
				if spell.age >= spell.wake and spell.age < spell.wake + WELL_PULL:
					var to: Vector2 = spell.pos - now
					if to.length() < WELL_RANGE:
						var pull: Vector2 = _momentum.get(_enemy, Vector2.ZERO) * 0.9 + to.normalized() * WELL_ACCEL * delta + Vector2(0, -COMBO_GRAVITY * delta)
						_momentum[_enemy] = pull.limit_length(320.0)
				elif spell.age >= spell.wake + WELL_PULL:
					spell.alive = false
					_plan.add_event(["spell_burst", "well", spell.pos])
					if now.distance_to(spell.pos) <= WELL_RADIUS + reach:
						_plan.detonations.append("Gravity Well")
						_plan.add_event(["damage", WELL_DAMAGE])
						_momentum[_enemy] = Vector2.ZERO
						_plan_pin = _frames(WELL_HOLD)
	_plan_prev_enemy = now


func _detonate(spell: Dictionary, name: String, damage: int) -> void:
	spell.alive = false
	_plan.detonations.append(name)
	_plan.add_event(["spell_burst", spell.kind, _enemy_center()])
	_plan.add_event(["damage", damage])


## Whether a segment from `a` to `b` passes within `radius` of the origin.
func _segment_near(a: Vector2, b: Vector2, radius: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(Vector2.ZERO, a, b).length() <= radius


func _segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


func _segment_crosses_column(a: Vector2, b: Vector2, x: float, half_width: float) -> bool:
	return minf(a.x, b.x) <= x + half_width and maxf(a.x, b.x) >= x - half_width


## Blink: she crouches, vanishes in a burst of sparks and reappears BLINK_DISTANCE
## ahead (stopping at walls).
func _plan_blink() -> void:
	_plan.add_event(["player_anim", &"dash"])
	_plan_hold(_frames(0.08))
	_plan.add_event(["sparkle_burst", _player_center()])
	_plan.add_event(["sound", "tp"])
	_move_sliding(player, Vector2(BLINK_DISTANCE * _facing(), 0))
	_step()
	_plan.add_event(["sparkle_burst", _player_center()])
	_plan_hold(_frames(0.22))
	_momentum[player] = Vector2.ZERO
	_plan.add_event(["player_anim", _rest_pose()])


## Shows Ilyra's spells for planned spell states (by index).
func _show_spells(states: Array) -> void:
	for i in states.size():
		if i >= _spell_nodes.size() or not is_instance_valid(_spell_nodes[i]):
			var node := Spell.new()
			get_tree().current_scene.add_child(node)
			if i >= _spell_nodes.size():
				_spell_nodes.append(node)
			else:
				_spell_nodes[i] = node
		_spell_nodes[i].show_state(states[i])
	for i in range(states.size(), _spell_nodes.size()):
		if is_instance_valid(_spell_nodes[i]):
			_spell_nodes[i].hide()


## Shows the kite (or not) for a planned kite state.
func _show_kite(kite: Dictionary) -> void:
	if kite.is_empty() or not kite.alive:
		if _kite_node:
			_kite_node.hide()
		return
	if _kite_node == null or not is_instance_valid(_kite_node):
		_kite_node = Kite.new()
		get_tree().current_scene.add_child(_kite_node)
	_kite_node.show()
	_kite_node.global_position = kite.pos
	_kite_node.hand = _player_center() + _facing_vector(Vector2(4, -16))


## Moves a body by `motion`, sliding along anything solid.
func _move_sliding(body: CharacterBody2D, motion: Vector2) -> void:
	var collision := body.move_and_collide(motion)
	if collision:
		body.move_and_collide(collision.get_remainder().slide(collision.get_normal()))


## Gather Clouds (see MOVES): three hits swing_interval apart, each active for
## ACTIVE_FRAMES, while he falls (stopping at the floor). Once caught, the enemy is
## carried down at the same speed until the third hit throws it up and away.
func _plan_gather_clouds(move: Dictionary) -> void:
	var caught := _connects(move)
	var interval := _frames(move.swing_interval)
	var hit_frames := [0, interval, interval * 2]
	var landed := [false, false, false]
	var fall := Vector2(0, move.fall_speed / Engine.physics_ticks_per_second)
	var knock := _facing_vector(move.knockback)
	var knocked := Vector2.ZERO
	var knock_frames := _frames(MOVE_DURATION)
	var knock_frame := -1 # Frames into the final knockback; -1 before it.
	var total: int = hit_frames[2] + knock_frames
	if caught:
		_momentum[_enemy] = Vector2(0, move.fall_speed)
	_plan.add_event(["sword", move.sword_scene, move.animation, _plan_storm])
	var f := 0
	while f < total or (knock_frame >= 0 and knock_frame < knock_frames):
		for h in 3:
			if f == hit_frames[h]:
				_plan.add_event(["player_anim", move.final_pose if h == 2 else move.pose])
				_plan.add_event(["sound", "swing"])
			if landed[h] or f < hit_frames[h] or f > hit_frames[h] + ACTIVE_FRAMES:
				continue
			_cut_projectiles(move)
			if not caught and _connects(move):
				caught = true
				_plan_drift[_enemy] = 0
				_momentum[_enemy] = Vector2(0, move.fall_speed)
			if caught:
				landed[h] = true
				_land_hit(move)
				if h == 2:
					knock_frame = 0
					_momentum[_enemy] = _facing_vector(move.momentum)
		var was_airborne: bool = player.is_airborne()
		_move_sliding(player, fall)
		if was_airborne and not player.is_airborne():
			_plan.add_event(["sound", "heavy_hit"])
		if caught and knock_frame < 0:
			_move_sliding(_enemy, fall)
		elif knock_frame >= 0 and knock_frame < knock_frames:
			knock_frame += 1
			var target := knock * (1.0 - pow(1.0 - float(knock_frame) / knock_frames, 3.0))
			_move_sliding(_enemy, target - knocked)
			knocked = target
		_step()
		f += 1
	_momentum[player] = Vector2(0, move.fall_speed) if player.is_airborne() else Vector2.ZERO
	_plan.add_event(["player_anim", _rest_pose()])


## The player's offset (from where the run starts) after `frame` of `frame_count`
## frames of Running Slash's run, eased out like a sweep.
func _run_offset(frame: int, frame_count: int) -> Vector2:
	var t := float(frame) / frame_count
	return Vector2(RUNNING_SLASH_DISTANCE * _facing(), 0) * (1.0 - pow(1.0 - t, 3.0))


## Moves the player one frame along the run (sliding along walls), given where it
## was meant to be the frame before.
func _run_step(frame: int, frame_count: int) -> void:
	var delta := _run_offset(frame, frame_count) - _run_offset(frame - 1, frame_count)
	var collision: KinematicCollision2D = player.move_and_collide(delta)
	if collision:
		player.move_and_collide(collision.get_remainder().slide(collision.get_normal()))


## The frame (1-based) on which Running Slash first catches the enemy, or -1 if it
## never does. Dry-runs the player along the run, then puts it back. The enemy is
## stationary until hit, so planning the move reproduces this exactly.
func _running_slash_contact(move: Dictionary) -> int:
	var start: Vector2 = player.global_position
	var frame_count := _frames(move.duration)
	var contact := -1
	for frame in range(1, frame_count + 1):
		_run_step(frame, frame_count)
		if _hits_point(move, _enemy_center(), _enemy_grow()):
			contact = frame
			break
	player.global_position = start
	return contact


func _plan_running_slash(move: Dictionary) -> void:
	var contact := _running_slash_contact(move)
	var start_x := _player_center().x
	_plan.add_event(["player_anim", move.pose])
	_plan.add_event(["sword", move.sword_scene, move.animation, _plan_storm])
	_plan.add_event(["sound", "swing"])
	var run_frames := _frames(move.duration)
	var knock_frames := _frames(MOVE_DURATION)
	var knock := Vector2.ZERO
	var knocked := Vector2.ZERO
	var knock_frame := -1 # Frames into the knockback; -1 before the hit.
	var frame := 1
	while frame <= run_frames or (knock_frame >= 0 and knock_frame < knock_frames):
		if frame <= run_frames:
			_run_step(frame, run_frames)
		_cut_projectiles(move)
		if frame == contact:
			_plan.add_event(["sound", "hit"])
			_plan.add_event(["damage", move.get("damage", 1)])
			var away := signf(start_x - _enemy_center().x) # Toward the run's start.
			if away == 0.0:
				away = -_facing()
			knock = Vector2(move.knockback.x * away, move.knockback.y)
			_momentum[_enemy] = Vector2(move.momentum.x * away, move.momentum.y)
			knock_frame = 0
		if knock_frame >= 0 and knock_frame < knock_frames:
			knock_frame += 1
			var target := knock * (1.0 - pow(1.0 - float(knock_frame) / knock_frames, 3.0))
			var collision: KinematicCollision2D = _enemy.move_and_collide(target - knocked)
			if collision:
				_enemy.move_and_collide(collision.get_remainder().slide(collision.get_normal()))
			knocked = target
		_step()
		frame += 1
	_momentum[player] = Vector2.ZERO
	_plan.add_event(["player_anim", _rest_pose()])


## A ding and a silver sparkle at the hitbox; if the enemy is there, a burst of
## silver sparkles and a heavy horizontal knockback.
func _plan_pinpoint_strike(move: Dictionary) -> void:
	var hit := _connects(move)
	_plan.add_event(["player_anim", move.pose])
	_plan.add_event(["sound", "ding"])
	_plan.add_event(["sparkle", _pinpoint_spot(move.reach)])
	_cut_projectiles(move)
	for f in _frames(0.1):
		_step()
		if not hit and f < ACTIVE_FRAMES:
			hit = _late_contact(move, false)
	if hit:
		_plan.add_event(["sound", move.hit_sound])
		_plan.add_event(["damage", move.get("damage", 1)])
		_plan.add_event(["sparkle_burst", _enemy_center()])
		_plan_sweep(_enemy, _facing_vector(move.knockback), _frames(move.knockback_duration))
	else:
		_plan_hold(_frames(MOVE_DURATION))
	_plan.add_event(["player_anim", _rest_pose()])


## The point on Pinpoint Strike's hitbox band closest to the enemy, so the sparkle
## shows exactly where the strike lands (or would have).
func _pinpoint_spot(reach: Rect2) -> Vector2:
	var ahead := (_enemy_center().x - _player_center().x) * _facing()
	ahead = clampf(ahead, reach.position.x, reach.end.x)
	return _player_center() + Vector2(ahead * _facing(), reach.get_center().y)


## Throws the hook at the enemy on a slack, sagging line. On a hit the rope springs
## taut and reels one body toward the other; on a miss the hook flies out to max range
## in front of the player and comes back.
func _plan_grapple(move: Dictionary) -> void:
	var hit := _connects(move)
	if hit:
		player.face(_enemy_center().x >= _player_center().x)
		_plan.add_event(["face", player.facing_right])
	_plan.add_event(["player_anim", move.pose])
	_plan.add_event(["sound", "swing"])
	# On a hit the hook homes in on the enemy, which may be drifting.
	_rope = {"mode": "travel", "start": _hand_position(), "hit": hit, "t": 0.0, "sag": GRAPPLE_SAG,
		"miss_aim": _hand_position() + Vector2(GRAPPLE_RANGE * _facing(), 0)}
	var travel := _frames(GRAPPLE_TRAVEL)
	for i in range(1, travel + 1):
		_rope.t = float(i) / travel
		_rope.sag = GRAPPLE_SAG * (1.0 - 0.4 * _rope.t)
		_step()

	if not hit:
		_rope.mode = "retract"
		for i in range(1, travel + 1):
			_rope.t = float(i) / travel
			_rope.sag = GRAPPLE_SAG * 0.6 * (1.0 - _rope.t)
			_step()
		_rope = {}
		_plan.add_event(["player_anim", _rest_pose()])
		return

	_plan.add_event(["sound", "hit"])
	_rope.mode = "attached"
	# Spring taut: the slack overshoots past straight and settles in a damped wobble.
	var snap := _frames(GRAPPLE_SNAP)
	for i in range(1, snap + 1):
		var t := float(i) / snap
		_rope.sag = GRAPPLE_SAG * 0.6 * exp(-5.0 * t) * cos(2.5 * TAU * t)
		_step()
	_rope.sag = 0.0

	var hold := Vector2(GRAPPLE_HOLD_DISTANCE * _facing(), 0)
	if move.grapple == "pull_in":
		_plan_sweep(_enemy, _player_center() + hold - _enemy_center(), _frames(MOVE_DURATION))
	else:
		# Let the enemy finish drifting so the player lands next to where it ends up.
		while _plan_drift.get(_enemy, 0) > 0:
			_step()
		_plan_sweep(player, _enemy_center() - hold - _player_center(), _frames(MOVE_DURATION))
		_momentum[player] = Vector2.ZERO
	_rope = {}
	_plan.add_event(["player_anim", _rest_pose()])


func _plan_jump() -> void:
	_plan.add_event(["player_anim", &"jump"])
	_plan_sweep(player, _facing_vector(JUMP_DISPLACEMENT), _frames(MOVE_DURATION))
	_momentum[player] = Vector2.ZERO # Hangs at the top of the jump.
	_plan.add_event(["player_anim", &"fall"])


## Turns the player around. It takes no Time, but is recorded as a single frame so
## the step has an end state like every other.
func _plan_flip() -> void:
	player.face(not player.facing_right)
	_plan.add_event(["face", player.facing_right])
	_step()


## Slides DASH_DISTANCE forward along the ground (stopping at walls).
func _plan_dash() -> void:
	_plan.add_event(["player_anim", &"dash"])
	_plan.add_event(["sound", "swing"])
	_plan_sweep(player, Vector2(DASH_DISTANCE * _facing(), 0), _frames(MOVE_DURATION))
	_momentum[player] = Vector2.ZERO
	_plan.add_event(["player_anim", _rest_pose()])


## Drops into a stance: its entry animation, given time to finish.
func _plan_enter_stance(move: Dictionary) -> void:
	_plan.add_event(["player_anim", move.pose])
	_plan.add_event(["sound", move.get("enter_sound", "tp")])
	if move.has("shout"):
		_plan.add_event(["shout", move.shout])
	_plan_hold(_frames(move.get("enter_seconds", IAI_ENTER_SECONDS)))
	_momentum[player] = Vector2.ZERO


## The pose to settle into after a move: holding a stance, hanging in the air, or
## standing.
func _rest_pose() -> StringName:
	if STANCE_POSES.has(_plan_stance):
		return STANCE_POSES[_plan_stance]
	return &"fall" if player.is_airborne() else &"idle"


## Shoots diagonally down-forward at DIVE_ANGLE_FROM_VERTICAL until the player lands, sliding down
## any wall in the way.
func _plan_dive() -> void:
	_plan.add_event(["player_anim", &"dive"])
	_plan.add_event(["sound", "swing"])
	var angle := deg_to_rad(DIVE_ANGLE_FROM_VERTICAL)
	var step := Vector2(sin(angle) * _facing(), cos(angle)) * DIVE_SPEED / Engine.physics_ticks_per_second
	for i in _frames(DIVE_MAX_SECONDS):
		var collision: KinematicCollision2D = player.move_and_collide(step)
		if collision and collision.get_normal().y < -0.7: # Landed.
			_step()
			break
		if collision:
			player.move_and_collide(collision.get_remainder().slide(collision.get_normal()))
		_step()
	_momentum[player] = Vector2.ZERO
	_plan.add_event(["player_anim", &"land"])


func _plan_tp_down() -> void:
	player.move_and_collide(Vector2(0, TP_DOWN_RANGE))
	_momentum[player] = Vector2.ZERO
	_plan.add_event(["tp_effect"])
	_plan.add_event(["player_anim", &"land"])
	_plan_hold(_frames(MOVE_DURATION))


# --- Playback ----------------------------------------------------------------

## Plays a plan on the real bodies, `speed` recorded frames per physics tick
## (blending between frames when that lands between two), then adopts its resulting
## momentum. Every event fires, even on frames that are skipped over.
func _play_plan(plan: ComboPlan, speed := 1.0) -> void:
	var rope: Node2D = null
	var count := plan.frames.size()
	var cursor := 0.0
	var fired := -1 # Last frame index whose events have fired.
	while true:
		var index := mini(floori(cursor), count)
		while fired < index:
			fired += 1
			for event in plan.events.get(fired, []):
				_play_event(event)
		if index == count:
			break
		var frame: Dictionary = plan.frames[index]
		var next: Dictionary = plan.frames[mini(index + 1, count - 1)]
		var blend := cursor - index
		player.global_position = frame.player.lerp(next.player, blend)
		_enemy.global_position = frame.enemy.lerp(next.enemy, blend)
		player.cloak.momentum = frame.cloak.lerp(next.cloak, blend)
		_show_projectile_frame(frame.projectiles, next.projectiles, blend)
		_show_kite(frame.get("kite", {}))
		_show_spells(frame.get("spells", []))
		if frame.rope.is_empty():
			if rope:
				rope.queue_free()
				rope = null
		else:
			if rope == null:
				rope = GrappleRope.new()
				get_tree().current_scene.add_child(rope)
			rope.from = frame.rope.from
			rope.to = frame.rope.to
			rope.sag = frame.rope.sag
		await get_tree().physics_frame
		cursor += speed
	if rope:
		rope.queue_free()
	if count > 0:
		player.global_position = plan.frames[-1].player
		_enemy.global_position = plan.frames[-1].enemy
	_momentum = plan.momentum
	player.face(plan.facing_right)
	# The fireballs carry on in real time from where the combo left them.
	if not plan.projectiles.is_empty():
		_show_projectiles(plan.projectiles)
		for i in _projectiles.size():
			if is_instance_valid(_projectiles[i]) and not plan.projectiles[i].alive:
				_projectiles[i].queue_free()


## Puts the real projectile nodes where `states` has them (hidden if gone).
func _show_projectiles(states: Array) -> void:
	for i in _projectiles.size():
		if is_instance_valid(_projectiles[i]) and i < states.size():
			_projectiles[i].apply_state(states[i])


## Puts the real projectile nodes part way (`blend`) between two recorded frames,
## with their dust, sounds and so on, as the combo plays out.
func _show_projectile_frame(states: Array, next_states: Array, blend: float) -> void:
	for i in _projectiles.size():
		if not is_instance_valid(_projectiles[i]) or i >= states.size():
			continue
		var state: Dictionary = states[i].duplicate()
		if state.alive and next_states[i].alive:
			state.pos = state.pos.lerp(next_states[i].pos, blend)
		_projectiles[i].apply_state(state, true)


func _play_event(event: Array) -> void:
	match event[0]:
		"sound": Sfx.play(self, event[1])
		"sword": player.play_combo_sword(event[1], event[2], event.size() > 3 and event[3])
		"player_anim": player.player_sprite.play(event[1])
		"face": player.face(event[1])
		"tp_effect": player.play_tp_down_effect()
		"sparkle":
			if event.size() > 2:
				_effects.spawn_sparkle(event[1], event[2], event[3])
			else:
				_effects.spawn_sparkle(event[1])
		"lightning": _effects.spawn_lightning(PackedVector2Array(event.slice(1)))
		"buff": player.add_buff(event[1], BUFFS[event[1]].seconds)
		"shout": _effects.spawn_shout(event[1], _player_center() + Vector2(0, -44))
		"dust": _effects.spawn_dust(event[1])
		"spell_burst": _effects.spawn_spell_burst(event[1], event[2], event[3] if event.size() > 3 else Vector2.ZERO)
		"kite_burn":
			_effects.spawn_sparkle_burst(event[1])
			_show_kite({})
		"sparkle_burst": _effects.spawn_sparkle_burst(event[1])
		"blade_particles": _effects.spawn_blade_particles(event[1], event[2], event[3])
		"damage":
			if _enemy.has_method("take_damage"):
				_enemy.take_damage(event[1])
		"player_hit": player.combo_hit()
		"projectile_end":
			if is_instance_valid(_projectiles[event[1]]):
				_projectiles[event[1]].end_effect(get_tree(), event[2])
				_projectiles[event[1]].visible = false


## Two ghost previews loop side by side: the planned timeline in grey, from the
## break's starting pose, and the highlighted move (if usable) in gold, from the
## timeline's end.
func _preview(id: String, direction := 0) -> void:
	if _busy or not time_stopped:
		_stop_ghosts()
		return
	if id != "" and MOVES[id].has("submenu"):
		# Preview the first entry that can be used.
		var parent := id
		id = ""
		for child in MOVES[parent].submenu:
			if _at_cursor(_unavailable_reason.bind(child)) == "":
				id = child
				break
	# Only restart the grey loop when the plan changes, not on every highlight change.
	if _previewed_version != _timeline_version:
		_previewed_version = _timeline_version
		if _timeline.is_empty():
			_timeline_ghost.stop()
		else:
			_timeline_ghost.projectiles = _projectiles
			_timeline_ghost.play(_combined_plan(_timeline_plans()), player, _enemy)
	if id == "" or _at_cursor(_unavailable_reason.bind(id)) != "":
		_candidate_ghost.stop()
	else:
		var start := _cursor_state()
		start.player_anim = _cursor_player_anim()
		# (start.cloak carries the cloak's momentum at the end of the timeline.)
		_candidate_ghost.projectiles = _projectiles
		_candidate_ghost.play(_plan_move(id, direction), player, _enemy, CANDIDATE_TINT, start)


func _stop_ghosts() -> void:
	_timeline_ghost.stop()
	_candidate_ghost.stop()
	_previewed_version = -1


## The player sprite animation the timeline leaves the player in.
func _cursor_player_anim() -> StringName:
	var anim: StringName = player.player_sprite.animation
	for plan in _timeline_plans():
		for index in plan.events.keys():
			for event in plan.events[index]:
				if event[0] == "player_anim":
					anim = event[1]
	return anim


func _unavailable_reason(id: String) -> String:
	var move: Dictionary = MOVES[id]
	var stance := _cursor_stance()
	if not _shown_in_stance(id, stance):
		return "Not available in a stance" if stance != "" else "Only usable in a stance"
	if move.has("submenu"):
		# Available if any of its entries is; otherwise, why the first one isn't.
		var first := ""
		for child in move.submenu:
			var reason := _unavailable_reason(child)
			if reason == "":
				return ""
			if first == "":
				first = reason
		return first
	if time < move.time:
		return "Not enough Time"
	if energy < move.energy:
		return "Not enough Energy"
	if move.get("airborne_only", false) and not player.is_airborne():
		return "Only usable mid-air"
	if move.get("grounded_only", false) and player.is_airborne():
		return "Only usable on the ground"
	if id == "tp_down":
		if not player.test_move(player.global_transform, Vector2(0, TP_DOWN_RANGE)):
			return "No floor in range"
	return ""


## Whether an attack would hit the staggered enemy from where everyone is now.
func _connects(move: Dictionary) -> bool:
	if move.has("grapple"):
		return _hand_position().distance_to(_enemy_center()) <= GRAPPLE_RANGE
	if move.has("running"):
		return _running_slash_contact(move) >= 0
	return _hits_point(move, _enemy_center(), _enemy_grow())


## Whether `point` is inside an attack's hitbox from where the player is now: its
## reach box, its thin reach_line (along `angle`, +x = facing, from `from` to `to` px
## out, within half_width), or for Running Slash its boxes at this point of the run.
## `grow` widens the hitbox on every side (for enemies bigger than the slime).
func _hits_point(move: Dictionary, point: Vector2, grow := Vector2.ZERO) -> bool:
	var rel := point - _player_center()
	rel.x *= _facing()
	if move.has("reach_line"):
		var line: Dictionary = move.reach_line
		var dir := Vector2.from_angle(deg_to_rad(line.angle))
		var normal := dir.orthogonal()
		var along := rel.dot(dir)
		var along_grow := absf(dir.x) * grow.x + absf(dir.y) * grow.y
		var side_grow := absf(normal.x) * grow.x + absf(normal.y) * grow.y
		return along >= line.from - along_grow and along <= line.to + along_grow \
			and absf(rel.dot(normal)) <= line.half_width + side_grow
	if move.has("reaches"):
		return move.reaches.any(func(reach: Rect2) -> bool:
			return reach.grow_individual(grow.x, grow.y, grow.x, grow.y).has_point(rel))
	if move.has("reach"):
		var reach: Rect2 = move.reach.grow_individual(grow.x, grow.y, grow.x, grow.y)
		if move.get("precise", false):
			reach = move.reach.grow_individual(grow.x, 0.0, grow.x, 0.0)
			reach.position.y -= grow.y
		return reach.has_point(rel)
	return false


## How much further than the slime's (which the reaches are tuned for) the enemy's
## body extends from its center, per side.
func _enemy_grow() -> Vector2:
	var collision: CollisionShape2D = _enemy.get_node("enemy_collision")
	var half: Vector2 = collision.shape.get_rect().size * collision.global_scale.abs() / 2.0
	return Vector2(maxf(half.x - REFERENCE_HALF_SIZE.x, 0.0), maxf(half.y - REFERENCE_HALF_SIZE.y, 0.0))


func _player_center() -> Vector2:
	return player.get_node("player_collision").global_position


func _enemy_center() -> Vector2:
	return _enemy.get_node("enemy_collision").global_position


## Where the grapple rope leaves the player.
func _hand_position() -> Vector2:
	return _player_center() + Vector2(8.0 * _facing(), -2.0)


func _facing() -> float:
	return 1.0 if player.facing_right else -1.0


func _facing_vector(v: Vector2) -> Vector2:
	return Vector2(v.x * _facing(), v.y)


## Pauses the player's and enemies' sprites and level animations (e.g. moving
## platforms) while time is stopped.
func _set_world_frozen(frozen: bool) -> void:
	if not frozen:
		for animator in _frozen_animators:
			if is_instance_valid(animator):
				animator.play()
		_frozen_animators.clear()
		return
	var animators := []
	animators.append_array(player.find_children("*", "AnimatedSprite2D", false, false))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		animators.append_array(enemy.find_children("*", "AnimatedSprite2D", true, false))
	animators.append_array(get_tree().current_scene.find_children("*", "AnimationPlayer", true, false))
	for animator in animators:
		if animator.is_playing():
			animator.pause()
			_frozen_animators.append(animator)


# --- UI --------------------------------------------------------------------

## Extra key bindings, added at runtime: WASD menu navigation, E to swing the
## sword (real time) and to confirm menu options, and Q / Backspace (as well as Esc)
## to undo the last planned step.
func _add_extra_keys() -> void:
	var bindings := [["ui_up", KEY_W], ["ui_left", KEY_A], ["ui_down", KEY_S], ["ui_right", KEY_D],
		["attack", KEY_E], ["ui_accept", KEY_E], ["ui_cancel", KEY_Q], ["ui_cancel", KEY_BACKSPACE]]
	for binding in bindings:
		var event := InputEventKey.new()
		event.physical_keycode = binding[1]
		if not InputMap.action_has_event(binding[0], event):
			InputMap.action_add_event(binding[0], event)


func _build_hud(theme: Theme) -> void:
	var layer := CanvasLayer.new()
	layer.layer = UI_LAYER
	add_child(layer)
	var box := VBoxContainer.new()
	box.theme = theme
	box.position = Vector2(16, 16)
	box.add_theme_constant_override("separation", 4)
	layer.add_child(box)
	_hp_label = _make_label("")
	box.add_child(_hp_label)
	_hp_fill = _make_bar(box, HP_COLOR)
	box.add_child(_make_spacer(6))
	_energy_label = _make_label("")
	box.add_child(_energy_label)
	_energy_fill = _make_bar(box, ENERGY_COLOR)
	box.add_child(_make_spacer(6))
	_time_label = _make_label("")
	box.add_child(_time_label)
	_time_fill = _make_bar(box, TIME_COLOR)
	_theme = theme
	_buff_row = HBoxContainer.new()
	_buff_row.position = Vector2(16 + BAR_SIZE.x + 14, 20)
	_buff_row.add_theme_constant_override("separation", 6)
	layer.add_child(_buff_row)


func _build_menu(theme: Theme) -> void:
	var layer := CanvasLayer.new()
	layer.layer = UI_LAYER
	add_child(layer)
	_menu = PanelContainer.new()
	_menu.theme = theme
	_menu.position = Vector2(16, 112)
	_menu.hide()
	layer.add_child(_menu)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_menu.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	margin.add_child(outer)
	outer.add_child(_make_label("STAGGER BREAK", ENERGY_COLOR))
	# The move lists scroll (following keyboard focus) when the screen is too short;
	# the title, UNDO / FINISH and the hint stay put.
	_menu_scroll = ScrollContainer.new()
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_scroll.follow_focus = true
	outer.add_child(_menu_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_scroll.add_child(box)
	_menu_list = box
	for group in [["attack", "ATTACKS"], ["spell", "SPELLS"], ["stance", "STANCES"], ["action", "ACTIONS"]]:
		box.add_child(_make_spacer(4))
		var header := _make_label(group[1], HEADER_COLOR)
		box.add_child(header)
		_group_headers[group[0]] = header
		for id in MOVES:
			var move: Dictionary = MOVES[id]
			if move.group != group[0] or move.get("standalone", false) or move.get("in_submenu", false):
				continue
			var label := "%s  (%dT %dE)" % [move.name, move.time, move.energy]
			if move.get("directional", false) or move.has("submenu"):
				label += "  >" # Opens a submenu.
			var button := _make_button(label)
			button.pressed.connect(_on_move_pressed.bind(id))
			button.focus_entered.connect(_on_button_focused.bind(button))
			box.add_child(button)
			_move_buttons[id] = button
			_button_ids[button] = id
	box = outer
	box.add_child(HSeparator.new())
	_undo_button = _make_button("UNDO  (Esc / Q)")
	_undo_button.pressed.connect(_undo)
	_undo_button.focus_entered.connect(_on_button_focused.bind(_undo_button))
	box.add_child(_undo_button)
	_finish_button = _make_button("FINISH")
	_finish_button.pressed.connect(_finish)
	_finish_button.focus_entered.connect(_on_button_focused.bind(_finish_button))
	box.add_child(_finish_button)
	_hint_label = _make_label("", HEADER_COLOR)
	box.add_child(_hint_label)
	_build_submenu(theme, layer)
	_build_flip_button(theme, layer)
	get_viewport().size_changed.connect(_fit_menu_height)


## Flip lives outside the menu, as a stone-grey button with yellow text just above
## the menu's top-right corner. It shows and hides along with the menu.
func _build_flip_button(theme: Theme, layer: CanvasLayer) -> void:
	_flip_button = Button.new()
	_flip_button.theme = theme
	_flip_button.text = "Flip (F)"
	_flip_button.custom_minimum_size = Vector2(96, 0)
	_flip_button.mouse_entered.connect(func() -> void:
		if not _flip_button.disabled:
			_flip_button.grab_focus())
	var styles := {
		"normal": [Color(0.42, 0.42, 0.44), Color(0.26, 0.26, 0.28)],
		"hover": [Color(0.5, 0.5, 0.52), Color(0.3, 0.3, 0.32)],
		"pressed": [Color(0.34, 0.34, 0.36), Color(0.22, 0.22, 0.24)],
		"focus": [Color(0.5, 0.5, 0.52), ENERGY_COLOR], # Yellow rim when highlighted.
		"disabled": [Color(0.3, 0.3, 0.32), Color(0.22, 0.22, 0.24)],
	}
	for state in styles:
		var box := StyleBoxFlat.new()
		box.bg_color = styles[state][0]
		box.border_color = styles[state][1]
		box.set_border_width_all(2)
		box.border_width_bottom = 4 # A heavier bottom edge reads as a chunky stone slab.
		box.set_corner_radius_all(3)
		box.set_content_margin_all(6)
		_flip_button.add_theme_stylebox_override(state, box)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		_flip_button.add_theme_color_override(color_name, ENERGY_COLOR)
	_flip_button.add_theme_color_override("font_disabled_color", Color(0.6, 0.55, 0.3))
	_flip_button.pressed.connect(_on_move_pressed.bind("flip"))
	_flip_button.focus_entered.connect(_on_button_focused.bind(_flip_button))
	_flip_button.hide()
	layer.add_child(_flip_button)
	_move_buttons["flip"] = _flip_button
	_button_ids[_flip_button] = "flip"
	_menu.visibility_changed.connect(func() -> void: _flip_button.visible = _menu.visible)


func _place_flip_button() -> void:
	_flip_button.reset_size()
	_flip_button.position = Vector2(_menu.position.x + _menu.size.x - _flip_button.size.x,
		_menu.position.y - _flip_button.size.y - 6.0)


## Sizes the scrolling move list to whatever fits between the menu's top and the
## bottom of the screen.
func _fit_menu_height() -> void:
	var available := get_viewport().get_visible_rect().size.y - _menu.position.y - 16.0
	var list_height := _menu_list.get_combined_minimum_size().y
	var other := _menu.get_combined_minimum_size().y - _menu_scroll.custom_minimum_size.y
	_menu_scroll.custom_minimum_size = Vector2(
		_menu_list.get_combined_minimum_size().x + 14.0, # Room for the scrollbar.
		clampf(available - other, 60.0, list_height))
	_menu.reset_size()
	_place_flip_button()


func _build_submenu(theme: Theme, layer: CanvasLayer) -> void:
	_submenu = PanelContainer.new()
	_submenu.theme = theme
	_submenu.hide()
	layer.add_child(_submenu)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_submenu.add_child(margin)
	_submenu_box = VBoxContainer.new()
	_submenu_box.add_theme_constant_override("separation", 4)
	margin.add_child(_submenu_box)


## Opens a submenu beside `id`'s menu button: its "submenu" entries, or Left / Right
## for a directional move (starting on the way the player faces at the end of the
## timeline).
func _open_submenu(id: String) -> void:
	_submenu_move = id
	for child in _submenu_box.get_children():
		_submenu_box.remove_child(child)
		child.queue_free()
	_submenu_buttons.clear()
	var entries := []
	if MOVES[id].has("submenu"):
		for child_id in MOVES[id].submenu:
			var child: Dictionary = MOVES[child_id]
			entries.append({"label": "%s  (%dT %dE)" % [child.get("short_name", child.name), child.time, child.energy],
				"id": child_id, "direction": 0})
	else:
		entries = [{"label": "<  Left", "id": id, "direction": -1}, {"label": "Right  >", "id": id, "direction": 1}]
	var buttons: Array[Button] = []
	for entry in entries:
		var button := _make_button(entry.label)
		button.pressed.connect(_on_submenu_chosen.bind(entry))
		button.focus_entered.connect(_on_button_focused.bind(button))
		_submenu_box.add_child(button)
		_submenu_buttons[button] = entry
		_set_enabled(button, _at_cursor(_unavailable_reason.bind(entry.id)) == "")
		buttons.append(button)
	# Keep keyboard navigation inside the submenu, cycling through its entries.
	for i in buttons.size():
		var next := buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
		var previous := buttons[i].get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		buttons[i].focus_neighbor_bottom = next
		buttons[i].focus_neighbor_right = next
		buttons[i].focus_neighbor_top = previous
		buttons[i].focus_neighbor_left = previous
	var anchor: Button = _move_buttons[id]
	_submenu.position = Vector2(_menu.position.x + _menu.size.x + 6, anchor.global_position.y - 10)
	_submenu.reset_size()
	_submenu.show()
	var first: Button = null
	var facing_right: bool = _cursor_state().facing_right
	for button in buttons:
		var entry: Dictionary = _submenu_buttons[button]
		if button.disabled:
			continue
		if first == null or (entry.direction != 0 and (entry.direction > 0) == facing_right):
			first = button
	if first:
		_grab_focus_quietly(first)
		_at_cursor(_update_hint.bind(first))
		_preview(_submenu_buttons[first].id, _submenu_buttons[first].direction)


## Closes the submenu without choosing, returning to its move's button.
func _close_submenu(with_sound := true) -> void:
	if _submenu_move == "":
		return
	if with_sound:
		Sfx.play(self, "menu_cancel")
	var id := _submenu_move
	_submenu_move = ""
	_submenu.hide()
	if with_sound:
		_last_focused = _move_buttons[id]
		_refresh_menu()


func _on_submenu_chosen(entry: Dictionary) -> void:
	var id := _submenu_move
	Sfx.play(self, "menu_confirm")
	_close_submenu(false)
	_last_focused = _move_buttons[id]
	_commit_move(entry.id, entry.direction)


## Glides the camera back onto the player after it was dragged around while planning.
func _recenter_camera() -> void:
	_dragging_camera = false
	var camera := get_viewport().get_camera_2d()
	if camera and camera.offset != Vector2.ZERO:
		camera.create_tween().tween_property(camera, "offset", Vector2.ZERO, 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _refresh_menu() -> void:
	if not _busy:
		_show_projectiles(_cursor_state().projectiles) # Where the planned combo leaves them.
		_at_cursor(func() -> void: _show_kite(_cursor_state().kite))
		_show_spells(_cursor_state().spells)
	_at_cursor(_refresh_move_buttons)
	_set_enabled(_undo_button, not _busy and not _timeline.is_empty())
	_set_enabled(_finish_button, not _busy)
	if _busy:
		_stop_ghosts()
		return
	var focus := _last_focused
	if focus == null or not is_instance_valid(focus) or focus.disabled or not focus.visible or _submenu_buttons.has(focus):
		focus = _first_enabled_button()
	_grab_focus_quietly(focus)
	_at_cursor(_update_hint.bind(focus))
	_preview(_button_ids.get(focus, ""))


## Moves keyboard focus without the menu cursor sound (for focus changes the
## player didn't make themselves).
func _grab_focus_quietly(button: Button) -> void:
	_quiet_focus = true
	button.grab_focus()
	_quiet_focus = false


## Shows only the moves on offer in the current stance (and the headers of groups
## that still have any), and enables the ones that can be used right now.
func _refresh_move_buttons() -> void:
	var stance := _cursor_stance()
	var shown_groups := {}
	for id in _move_buttons:
		var button: Button = _move_buttons[id]
		var shown := _shown_in_stance(id, stance)
		button.visible = shown and (_menu.visible or button != _flip_button)
		_set_enabled(button, shown and not _busy and _unavailable_reason(id) == "")
		if shown and not MOVES[id].get("standalone", false):
			shown_groups[MOVES[id].group] = true
	for group in _group_headers:
		_group_headers[group].visible = shown_groups.has(group)


func _on_button_focused(button: Button) -> void:
	if not _quiet_focus:
		Sfx.play(self, "menu_cursor")
	if _submenu_buttons.has(button):
		_at_cursor(_update_hint.bind(button))
		_preview(_submenu_buttons[button].id, _submenu_buttons[button].direction)
		return
	# Moving to anything outside the submenu (e.g. with the mouse) closes it.
	_close_submenu(false)
	_last_focused = button
	_at_cursor(_update_hint.bind(button))
	_preview(_button_ids.get(button, ""))


func _update_hint(button: Button) -> void:
	var id: String = _button_ids.get(button, "")
	if button == _finish_button:
		_hint_label.text = "End the Stagger Break" if _timeline.is_empty() else "Perform the planned combo"
	elif button == _undo_button:
		_hint_label.text = "Remove the last planned step"
	elif _timeline_buttons.has(button):
		_hint_label.text = "Rewind to before this step"
	elif _submenu_buttons.has(button):
		var entry: Dictionary = _submenu_buttons[button]
		if entry.direction != 0:
			_hint_label.text = "%s %s  (Esc / Q: back)" % [MOVES[entry.id].name, "left" if entry.direction < 0 else "right"]
		else:
			_hint_label.text = _move_hint(entry.id)
	elif MOVES[id].get("directional", false) and _unavailable_reason(id) == "":
		_hint_label.text = "Choose a direction"
	elif MOVES[id].has("submenu") and _unavailable_reason(id) == "":
		_hint_label.text = "Choose a %s" % MOVES[id].name.to_lower()
	else:
		_hint_label.text = _move_hint(id)


## Why a move can't be used, whether an attack is in reach, or its own hint.
func _move_hint(id: String) -> String:
	var reason := _unavailable_reason(id)
	if reason != "":
		return reason
	if MOVES[id].group == "attack":
		return "Target in reach" if _connects(MOVES[id]) else "Target out of reach"
	return MOVES[id].get("hint", "")


func _build_timeline_panel(theme: Theme) -> void:
	var layer := CanvasLayer.new()
	layer.layer = UI_LAYER
	add_child(layer)
	_timeline_panel = PanelContainer.new()
	_timeline_panel.theme = theme
	# Top-right corner, growing leftward as entries get wider.
	_timeline_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timeline_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_timeline_panel.offset_right = -16
	_timeline_panel.offset_left = -16
	_timeline_panel.offset_top = 16
	_timeline_panel.hide()
	layer.add_child(_timeline_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_timeline_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	box.add_child(_make_label("COMBO PLAN", ENERGY_COLOR))
	_timeline_box = VBoxContainer.new()
	_timeline_box.add_theme_constant_override("separation", 4)
	box.add_child(_timeline_box)
	box.add_child(_make_label("Pick a step to rewind to it", HEADER_COLOR))


## One button per planned step; pressing one rewinds to just before it.
func _rebuild_timeline_list() -> void:
	for child in _timeline_box.get_children():
		_timeline_box.remove_child(child)
		child.queue_free()
	_timeline_buttons.clear()
	if _timeline.is_empty():
		_timeline_box.add_child(_make_label("(nothing planned)", HEADER_COLOR))
	for i in _timeline.size():
		var step: Dictionary = _timeline[i]
		var label := "%d. %s" % [i + 1, MOVES[step.id].name]
		if step.direction != 0:
			label += " (%s)" % ("Left" if step.direction < 0 else "Right")
		if step.plan.interrupted:
			label += " (Interrupted - Hit)"
		if not step.plan.detonations.is_empty():
			label += " (+ %s!)" % ", ".join(step.plan.detonations)
		var button := _make_button(label)
		button.pressed.connect(_on_timeline_step_pressed.bind(i))
		button.focus_entered.connect(_on_button_focused.bind(button))
		_timeline_box.add_child(button)
		_timeline_buttons[button] = i


func _first_enabled_button() -> Button:
	for id in _move_buttons:
		if not _move_buttons[id].disabled and _move_buttons[id].visible:
			return _move_buttons[id]
	return _finish_button


func _set_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	# Keep keyboard/gamepad navigation from stopping on unusable options.
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _update_hud() -> void:
	_hp_label.text = "HP %d/%d" % [player.hp, player.MAX_HP]
	_hp_fill.size.x = BAR_SIZE.x * player.hp / player.MAX_HP
	_time_label.text = "TIME %d/%d" % [time, MAX_TIME]
	_time_fill.size.x = BAR_SIZE.x * time / MAX_TIME
	_energy_label.text = "ENERGY %d/%d" % [floori(energy), MAX_ENERGY]
	_energy_fill.size.x = BAR_SIZE.x * energy / MAX_ENERGY
	_update_buffs()


## Keeps one green square per active buff, each with a bar along its bottom showing
## the time it has left.
func _update_buffs() -> void:
	for buff in _buff_widgets.keys():
		if not player.has_buff(buff):
			_buff_widgets[buff].box.queue_free()
			_buff_widgets.erase(buff)
	for buff in player.buffs:
		if not _buff_widgets.has(buff):
			_buff_widgets[buff] = _make_buff_box(buff)
		var timer: ColorRect = _buff_widgets[buff].timer
		timer.size.x = (BUFF_SIZE - 6.0) * clampf(player.buffs[buff] / BUFFS[buff].seconds, 0.0, 1.0)


func _make_buff_box(buff: String) -> Dictionary:
	var box := Panel.new()
	box.custom_minimum_size = Vector2(BUFF_SIZE, BUFF_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = BUFF_COLOR
	style.border_color = BUFF_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var icon := TextureRect.new()
	icon.texture = _lightning_icon()
	icon.position = Vector2(5, 3)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var timer := ColorRect.new()
	timer.color = Color(0.8, 1.0, 0.8, 0.85)
	timer.position = Vector2(3, BUFF_SIZE - 5)
	timer.size = Vector2(BUFF_SIZE - 6.0, 2)
	timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(timer)
	# Its name, shown just below while the mouse is over it.
	var tip := PanelContainer.new()
	tip.theme = _theme
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	tip_style.border_color = BUFF_COLOR
	tip_style.set_border_width_all(1)
	tip_style.set_content_margin_all(4)
	tip.add_theme_stylebox_override("panel", tip_style)
	tip.position = Vector2(0, BUFF_SIZE + 4)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _make_label(BUFFS[buff].label)
	tip.add_child(label)
	tip.hide()
	box.add_child(tip)
	box.mouse_entered.connect(tip.show)
	box.mouse_exited.connect(tip.hide)
	_buff_row.add_child(box)
	return {"box": box, "timer": timer}


static var _lightning_icon_texture: Texture2D

## A small pale-yellow lightning bolt with a dark outline (20x22).
static func _lightning_icon() -> Texture2D:
	if _lightning_icon_texture == null:
		var bolt := PackedVector2Array([Vector2(12, 1), Vector2(4, 12), Vector2(9.5, 12), Vector2(6, 21),
			Vector2(16, 8.5), Vector2(10.5, 8.5), Vector2(15, 1)])
		var img := Image.create(20, 22, false, Image.FORMAT_RGBA8)
		for y in 22:
			for x in 20:
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), bolt):
					img.set_pixel(x, y, Color(1.0, 0.95, 0.55) if x < 11 else Color(1.0, 0.85, 0.3))
		var source := img.duplicate()
		for y in 22:
			for x in 20:
				if source.get_pixel(x, y).a > 0.0:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = Vector2i(x, y) + d
					if n.x >= 0 and n.x < 20 and n.y >= 0 and n.y < 22 and source.get_pixel(n.x, n.y).a > 0.0:
						img.set_pixel(x, y, Color(0.12, 0.2, 0.1))
						break
		_lightning_icon_texture = ImageTexture.create_from_image(img)
	return _lightning_icon_texture


func _make_label(text: String, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Hovering highlights the option (and so previews it), same as keyboard focus.
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			button.grab_focus())
	return button


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


## Adds a background + fill bar to `parent` and returns the fill rect.
func _make_bar(parent: Control, color: Color) -> ColorRect:
	var bar := Control.new()
	bar.custom_minimum_size = BAR_SIZE
	parent.add_child(bar)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.6)
	back.size = BAR_SIZE
	bar.add_child(back)
	var fill := ColorRect.new()
	fill.color = color
	fill.size = BAR_SIZE
	bar.add_child(fill)
	return fill
