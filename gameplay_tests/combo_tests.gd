extends SceneTree

## Combo regression tests, run in the slime test area (2D Game.tscn), against the
## slime and against a mole put in its place.
##
## Each case staggers the enemy at a starting offset, plans a sequence on the timeline
## (with optional undo / rewind), checks whether each attack lands against what's
## expected (an attack "HIT"s if its plan deals any damage, so hits caught on a late
## active frame count), then FINISHes and checks the real bodies end exactly where the
## plan said (and that planning never moved them). Every case runs facing right and left.
##
## Run: run_tests.bat combo   Options (in any order): a case-name prefix ("Iai"), and
## enemy=slime or enemy=mole to test just one.

const SCENE := "res://scenes/2D Game.tscn"
const Mole = preload("res://scenes/enemies/mole.gd")
const ENEMIES := ["slime", "mole"]
const SLIME_HALF_WIDTH := 7.875
const FLAT_GROUND := Vector2(-300, -40) # Away from the spawn wall, so runs and dashes have room.

## name: shown in the report.
## dx: enemy's starting distance in front of the player (one trial per value), as the
##   distance between their centers for the slime; bigger enemies start further away
##   by how much wider they are, so the gap between the bodies is the same.
## above: instead of dx, the enemy's center this far straight above the player's.
## at: where the player starts (null = the scene's spawn point).
## steps: move ids ("dash:L" = with a direction), "undo", or "rewindN" (rewind to step N).
## expect: one entry per attack, in order: "HIT", "MISS", "X" (unavailable), or "*" (either).
##   Fewer entries than attacks = the rest aren't checked. Empty = only the plan/finish checks.
## mole_expect: replaces expect against the mole, where a combo works differently.
const CASES := [
	# --- The original combos ---
	{"name": "Pinpoint combo", "dx": [18.0, 45.0],
		"steps": ["launching_slash", "jump", "horizontal_slash", "horizontal_slash", "pinpoint_strike"],
		"expect": ["HIT", "HIT", "HIT", "HIT"]},
	{"name": "Pinpoint misses after one Horizontal", "dx": [18.0, 45.0],
		"steps": ["launching_slash", "jump", "horizontal_slash", "pinpoint_strike"],
		"expect": ["HIT", "HIT", "MISS"]},
	{"name": "Old combo", "dx": [18.0, 45.0],
		"steps": ["launching_slash", "jump", "horizontal_slash", "jump", "downward_slash", "tp_down"],
		"expect": ["HIT", "HIT", "HIT"]},
	{"name": "Undo then old combo", "dx": [18.0, 45.0],
		"steps": ["launching_slash", "jump", "horizontal_slash", "horizontal_slash", "undo", "undo",
			"horizontal_slash", "jump", "downward_slash", "tp_down"],
		"expect": ["HIT", "HIT", "HIT", "HIT", "HIT"]},
	{"name": "Rewind then Pinpoint combo", "dx": [18.0, 45.0],
		"steps": ["launching_slash", "jump", "wait", "wait", "jump", "rewind2",
			"horizontal_slash", "horizontal_slash", "pinpoint_strike"],
		"expect": ["HIT", "HIT", "HIT", "HIT"]},
	{"name": "Tri-Strike combo", "dx": [18.0, 30.0, 40.0],
		"steps": ["tri_strike", "jump", "jump", "downward_slash"],
		"expect": ["HIT", "HIT"]},
	{"name": "Tri-Strike then Pinpoint misses", "dx": [18.0, 30.0, 40.0],
		"steps": ["tri_strike", "pinpoint_strike"],
		"expect": ["HIT", "MISS"]},
	{"name": "Launching Slash into Tri-Strike", "dx": [18.0, 25.0],
		"steps": ["launching_slash", "tri_strike"],
		"expect": ["HIT", "HIT"]},
	# --- Gather Clouds ---
	{"name": "Gather Clouds from a Jump", "dx": [18.0, 30.0, 45.0],
		"steps": ["jump", "gather_clouds"],
		"expect": ["HIT"]},
	{"name": "Launch, Jump, Gather Clouds", "dx": [18.0, 45.0],
		"steps": ["launching_slash", "jump", "gather_clouds"],
		"expect": ["HIT", "HIT"]},
	# --- Movement (only checks that FINISH matches the plan) ---
	{"name": "Dive", "dx": [18.0, 45.0], "steps": ["jump", "dive"], "expect": []},
	{"name": "Dive from ground", "dx": [18.0, 45.0], "steps": ["dive"], "expect": []},
	{"name": "Back jump + dive", "dx": [18.0, 45.0], "steps": ["flip", "jump", "dive"], "expect": []},
	{"name": "Dash", "dx": [18.0, 45.0], "steps": ["dash"], "expect": []},
	{"name": "Dash back and forward", "dx": [18.0, 45.0], "steps": ["dash:L", "dash:R"], "expect": []},
	{"name": "Air dash", "dx": [18.0, 45.0], "steps": ["jump", "dash"], "expect": []},
	{"name": "Running Slash", "dx": [18.0, 60.0, 110.0], "steps": ["running_slash"], "expect": ["*"]},
	{"name": "Running Slash from behind", "dx": [18.0, 45.0],
		"steps": ["launching_slash", "flip", "running_slash"], "expect": ["HIT", "*"]},
	{"name": "Running Slash in the air", "dx": [18.0, 45.0],
		"steps": ["jump", "running_slash"], "expect": ["X"]},
	# --- Iai ---
	{"name": "Iai: Scale the Summit x3, not x4", "dx": [18.0, 20.0, 23.0], "at": FLAT_GROUND,
		"steps": ["launching_slash", "iai", "scale_the_summit", "scale_the_summit", "scale_the_summit", "scale_the_summit"],
		"expect": ["HIT", "HIT", "HIT", "HIT", "MISS"]},
	{"name": "Iai: Scale x3, Exit, Flip, Dash", "dx": [18.0], "at": FLAT_GROUND,
		"steps": ["launching_slash", "iai", "scale_the_summit", "scale_the_summit", "scale_the_summit", "exit_stance", "flip", "dash"],
		"expect": ["HIT", "HIT", "HIT", "HIT"]},
	{"name": "Iai: Sever, Exit, Dash, Flip, Launch", "dx": [18.0, 24.0, 30.0], "at": FLAT_GROUND,
		"steps": ["iai", "sever_the_roots", "exit_stance", "dash", "flip", "launching_slash"],
		"expect": ["HIT", "HIT"]},
	{"name": "Iai: Imbibe, Wait chain", "above": 35.0, "at": FLAT_GROUND,
		"steps": ["iai", "imbibe_the_sky", "wait", "imbibe_the_sky", "wait", "imbibe_the_sky"],
		"expect": ["HIT", "HIT", "HIT"]},
	{"name": "Iai: Running Slash, Flip, ..., Scale", "dx": [18.0, 25.0, 35.0, 45.0, 50.0], "at": FLAT_GROUND,
		"steps": ["running_slash", "flip", "running_slash", "flip", "launching_slash", "iai", "scale_the_summit"],
		"expect": []},
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var prefix := ""
	var enemies := ENEMIES
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("enemy="):
			enemies = [arg.trim_prefix("enemy=")]
		else:
			prefix = arg
	for enemy_kind in enemies:
		for case in CASES:
			if not case.name.begins_with(prefix):
				continue
			var offsets: Array = [null] if case.has("above") else case.dx
			for dx in offsets:
				for right in [true, false]:
					var label: String = "[%s] %s%s %s" % [enemy_kind, case.name, "" if dx == null else " dx=%d" % dx, "R" if right else "L"]
					var result: Dictionary = await _trial(case, enemy_kind, dx, right)
					if result.ok:
						_passed += 1
					else:
						_failed += 1
					print("%s  %s: %s" % ["PASS" if result.ok else "FAIL", label, result.log])
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _trial(case: Dictionary, enemy_kind: String, dx, right: bool) -> Dictionary:
	var scene: Node = load(SCENE).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 30:
		await physics_frame
	var combat = scene.get_node("CombatManager")
	var player = scene.get_node("Player")
	var enemy = scene.get_node("Level 1/enemy_slime_guy_chara3")
	var at = case.get("at")
	var extra_gap := 0.0
	if enemy_kind == "mole":
		var mole := Mole.new()
		mole.active = false # Stands still.
		scene.get_node("Level 1").add_child(mole)
		enemy.free()
		enemy = mole
		extra_gap = mole.enemy_collision.shape.size.x / 2.0 - SLIME_HALF_WIDTH
		if at == null:
			at = FLAT_GROUND # Room for its size, away from the spawn wall.
	if at != null:
		player.global_position = at
		for i in 40:
			await physics_frame
	var side := 1.0 if right else -1.0
	if case.has("above"):
		# Enemy center exactly `above` px over the player's center.
		if enemy_kind == "slime":
			enemy.global_position = Vector2(player.global_position.x, player.global_position.y - 14.5 - case.above)
		else:
			var center: Vector2 = player.get_node("player_collision").global_position - Vector2(0, case.above)
			enemy.global_position = center - enemy.enemy_collision.position
		player.face(right)
	else:
		enemy.global_position = player.global_position + Vector2((dx + extra_gap) * side, -40)
		for i in 60:
			await physics_frame
	for i in 3:
		enemy.apply_stagger(10)
	while combat._busy: # The intro plays first when he's on the ground.
		await process_frame

	var ok := true
	var log := ""
	var results: Array = []
	var start := [player.global_position, enemy.global_position]
	for step in case.steps:
		if step == "undo":
			combat._undo()
			log += "undo "
			continue
		if step.begins_with("rewind"):
			combat._rewind_to(int(step.trim_prefix("rewind")))
			log += "%s " % step
			continue
		var id: String = step.split(":")[0]
		var dir := 0
		if step.ends_with(":L"): dir = -1
		if step.ends_with(":R"): dir = 1
		var move: Dictionary = combat.MOVES[id]
		var reason: String = combat._at_cursor(combat._unavailable_reason.bind(id))
		var tag := ""
		if reason != "":
			tag = "X"
		else:
			combat._commit_move(id, dir)
			if move.group == "attack":
				var plan = combat._timeline[-1].plan
				var hits := _hits_in(plan)
				var landed := hits > 0
				if move.has("grapple"): # Grapples deal no damage.
					landed = plan.events.values().any(func(events: Array) -> bool: return events.has(["sound", "hit"]))
				tag = "HIT" if landed else "MISS"
				if hits > 1:
					tag += " x%d" % hits
		if tag != "":
			results.append(tag.split(" ")[0])
		log += "%s%s " % [step, "" if tag == "" else "[%s]" % tag]
		if [player.global_position, enemy.global_position] != start:
			log += "!!REAL BODIES MOVED WHILE PLANNING!! "
			ok = false

	var expect: Array = case.get("mole_expect", case.expect) if enemy_kind == "mole" else case.expect
	for i in mini(expect.size(), results.size()):
		if expect[i] != "*" and expect[i] != results[i]:
			log += "<attack %d: expected %s> " % [i + 1, expect[i]]
			ok = false
	if results.size() < expect.size():
		log += "<expected %d attacks, got %d> " % [expect.size(), results.size()]
		ok = false

	var expected: Dictionary = combat._cursor_state()
	await combat._finish()
	if not (expected.player.is_equal_approx(player.global_position) and expected.enemy.is_equal_approx(enemy.global_position)):
		log += "<FINISH doesn't match the plan> "
		ok = false
	for i in 4:
		await physics_frame
	if combat.time_stopped:
		log += "<real time didn't resume> "
		ok = false
	scene.queue_free()
	await process_frame
	await process_frame # Deletion is flushed after process_frame fires.
	return {"ok": ok, "log": log}


## How many hits a planned step deals.
func _hits_in(plan) -> int:
	var hits := 0
	for frame in plan.events:
		for event in plan.events[frame]:
			if event[0] == "damage":
				hits += 1
	return hits
