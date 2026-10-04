extends SceneTree

## Fireball / projectile tests, run in the opening level: real-time hits (-1 HP), fireballs
## freezing during a Stagger Break and moving only with planned Time, undo moving them back,
## planned attacks cutting them, planned hits not ending the combo, FINISH applying the
## results, and real-time sword swings cutting them.
##
## Run: run_tests.bat fireball

const Fireball = preload("res://scenes/enemies/fireball.gd")
const Bat = preload("res://scenes/enemies/bat.gd")
const Mole = preload("res://scenes/enemies/mole.gd")
var fails := 0

func _initialize() -> void:
	_run.call_deferred()

func check(label: String, ok: bool, info = "") -> void:
	print(("PASS " if ok else "FAIL ") + label + "  " + str(info))
	if not ok:
		fails += 1

func spawn(scene: Node, pos: Vector2, vel: Vector2) -> Node2D:
	var f := Fireball.new()
	f.velocity = vel
	scene.add_child(f)
	f.global_position = pos
	return f

func _run() -> void:
	var scene: Node = load("res://scenes/opening/opening.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var player = scene.get_node("Player")
	var combat = scene.get_node("CombatManager")
	# Only the first mole; no bats (nobody else spits fireballs).
	var mole
	for n in scene.get_node("World").get_children():
		if n is Bat:
			n.free()
		elif n is Mole and not n.boss and mole == null:
			mole = n
		elif n is Mole and not n.boss:
			n.free()
	for i in 10:
		await physics_frame
	mole.set_physics_process(false)
	player.global_position = mole.global_position + Vector2(-40, 0)
	for i in 10:
		await physics_frame

	# --- Real time: fireball hits the player.
	var c: Vector2 = player.get_node("player_collision").global_position
	spawn(scene, c + Vector2(60, 0), Vector2(-100, 0))
	for i in 60:
		await physics_frame
	check("real-time hit -1 HP", player.hp == 9, player.hp)
	player.hp = 10
	for i in 70:
		await physics_frame
	player.global_position = mole.global_position + Vector2(-40, 0)
	player.velocity = Vector2.ZERO
	player.face(true)
	for i in 20:
		await physics_frame

	# --- Stagger break with fireballs in flight.
	c = player.get_node("player_collision").global_position
	var a := spawn(scene, c + Vector2(-150, 0), Vector2(100, 0)) # Behind, coming in: hits in ~1.5s.
	var b := spawn(scene, c + Vector2(0, -200), Vector2(100, 0)) # High up, flying away.
	var cut := spawn(scene, c + Vector2(30, -5), Vector2(0, -1)) # Right in front: Horizontal Slash cuts it.
	await physics_frame
	var a0 := a.global_position
	var cut0 := cut.global_position
	combat.start_stagger_break(mole)
	for i in 10:
		await physics_frame
	check("frozen while planning", a.global_position == a0, a.global_position)
	await create_timer(3.5).timeout # intro
	check("still frozen after intro", a.global_position == a0, a.global_position)

	combat._commit_move("wait")
	await physics_frame
	check("wait moves fireball ~30px", absf(a.global_position.x - a0.x - 30.0) < 3.0, a.global_position - a0)
	combat._undo()
	await physics_frame
	check("undo moves it back", a.global_position.distance_to(a0) < 0.01, a.global_position)

	combat._commit_move("horizontal_slash")
	await physics_frame
	var plan = combat._timeline[-1].plan
	var fizzled := false
	for f in plan.events:
		for e in plan.events[f]:
			if e[0] == "projectile_end" and e[1] == combat._projectiles.find(cut):
				fizzled = true
	check("planned slash cuts fireball", fizzled and not cut.visible, [fizzled, cut.visible])
	combat._undo()
	await physics_frame
	check("undo restores cut fireball", cut.visible and cut.global_position.distance_to(cut0) < 0.01)
	combat._commit_move("horizontal_slash")

	var hit := false
	for i in 6:
		combat._commit_move("wait")
		for f in combat._timeline[-1].plan.events:
			for e in combat._timeline[-1].plan.events[f]:
				if e[0] == "player_hit":
					hit = true
	check("planned hit recorded", hit)
	check("hit step labelled interrupted", combat._timeline.filter(func(step): return step.plan.interrupted).size() == 1
		and combat._timeline_buttons.keys().any(func(button): return button.text.ends_with("(Interrupted - Hit)")))
	check("combo still planning", combat.time_stopped and combat._timeline.size() == 7, combat._timeline.size())
	check("hp unchanged while planning", player.hp == 10, player.hp)

	combat._finish()
	var t := 0
	while combat.time_stopped and t < 1200:
		await physics_frame
		t += 1
	await physics_frame
	check("combo finished", not combat.time_stopped, t)
	check("hp 9 after combo hit", player.hp == 9, player.hp)
	check("cut fireball freed", not is_instance_valid(cut))
	check("hit fireball freed", not is_instance_valid(a))
	if is_instance_valid(b):
		var bp := b.global_position
		await physics_frame
		await physics_frame
		check("survivor flies on in real time", b.global_position != bp, b.global_position - bp)

	# --- Real-time sword cut.
	for i in 80:
		await physics_frame
	player.hp = 10
	c = player.get_node("player_collision").global_position
	var f := spawn(scene, c + Vector2(28 * (1 if player.facing_right else -1), -4), Vector2(0, -2))
	f.velocity = Vector2(0, -1)
	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	for i in 20:
		await physics_frame
	check("real-time sword cuts fireball", not is_instance_valid(f) and player.hp == 10, player.hp)
	print("
%d failed" % fails)
	quit(1 if fails > 0 else 0)
