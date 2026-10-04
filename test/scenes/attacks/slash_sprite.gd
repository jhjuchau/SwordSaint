extends AnimatedSprite2D

## A sword slash drawn as a curved swoosh tracing the blade's arc around the player.
## The frames are generated in code (once per arc, then cached) from the ARCS specs.
##
## The art faces left (the player's attack code sets flip_h when facing right), and is
## laid out so the arc's pivot lands on the player's center: the pivot sits
## `pivot_ahead` px behind this sprite's center, and the sprite is placed in each
## attack scene so its center is that far in front of the player, at chest height.

## Angles are in degrees with 0 = forward, -90 = up, 90 = down; the slash sweeps from
## `from` to `to`. `duration` is how long the animation lasts in total; the swing
## itself takes at most SWEEP_SECONDS (or the spec's own `sweep`), and an empty last
## frame holds for the rest (the real-time attack code waits for the animation to
## finish before the next swing). A spec with `swings` plays several arcs back to back
## (`frames` each), sharing its pivot_ahead.
const ARCS := {
	"horizontal": {"animation": &"attack", "from": -55.0, "to": 45.0, "radius": 30.0,
		"thickness": 7.0, "pivot_ahead": 30.0, "duration": 0.15},
	"launch": {"animation": &"attack_launch", "from": 60.0, "to": -115.0, "radius": 30.0,
		"thickness": 7.0, "pivot_ahead": 30.0, "duration": 0.2},
	"finisher": {"animation": &"attack", "from": -75.0, "to": 60.0, "radius": 40.0,
		"thickness": 10.0, "pivot_ahead": 30.0, "duration": 1.0},
	# A big chop from above ahead down to below ahead (keep it matching Downward
	# Slash's reach in combat_manager.gd).
	"downward": {"animation": &"attack", "from": -35.0, "to": 70.0, "radius": 58.0,
		"thickness": 11.0, "pivot_ahead": 38.0, "duration": 0.6, "sweep": 0.18},
	# The Iai draws: not arcs but long, thin streaks cutting straight out from the
	# player at `angle` (keep them matching their moves' hitboxes in combat_manager.gd).
	"summit": {"animation": &"attack", "streak": true, "angle": -127.5, "from": 6.0, "to": 100.0,
		"thickness": 3.0, "pivot_ahead": 30.0, "duration": 0.45, "sweep": 0.45, "frames": 14},
	"imbibe": {"animation": &"attack", "streak": true, "angle": -90.0, "from": 6.0, "to": 180.0,
		"thickness": 3.0, "pivot_ahead": 30.0, "duration": 0.45, "sweep": 0.45, "frames": 14},
	"sever": {"animation": &"attack", "streak": true, "angle": 180.0, "from": 6.0, "to": 200.0,
		"thickness": 4.0, "pivot_ahead": 30.0, "duration": 0.4, "sweep": 0.4, "frames": 12},
	# Starts low in front, then swings slowly up over the head and round behind.
	"running": {"animation": &"attack", "from": 80.0, "to": -160.0, "radius": 28.0,
		"thickness": 7.0, "pivot_ahead": 30.0, "duration": 0.4, "sweep": 0.4, "frames": 12},
	# Two quick short cuts (down, then a rising backhand), then a narrower, longer cut
	# up and away at 45 degrees.
	"tri_strike": {"animation": &"attack", "pivot_ahead": 30.0, "duration": 0.3, "sweep": 0.3,
		"frames": 5, "swings": [
			{"from": -40.0, "to": 50.0, "radius": 24.0, "thickness": 6.0},
			{"from": 55.0, "to": -35.0, "radius": 22.0, "thickness": 6.0},
			{"from": -10.0, "to": -80.0, "radius": 36.0, "thickness": 7.0},
		]},
	# Gather Clouds: two chops down in front as he drops, then a big rising cut.
	"gather_clouds": {"animation": &"attack", "pivot_ahead": 30.0, "duration": 0.5, "sweep": 0.45,
		"frames": 5, "swings": [
			{"from": -50.0, "to": 75.0, "radius": 34.0, "thickness": 8.0},
			{"from": -45.0, "to": 80.0, "radius": 36.0, "thickness": 8.0},
			{"from": 60.0, "to": -105.0, "radius": 40.0, "thickness": 9.0},
		]},
}
const FRAMES := 7
const SWEEP_SECONDS := 0.2
const CORE_COLOR := Color(1.0, 1.0, 1.0)
const EDGE_COLOR := Color(0.65, 0.88, 1.0)

## Each sword scene's arc and where its sprite sits (see apply_to()).
const SCENE_ARCS := {
	"res://scenes/attacks/sword_horizontal.tscn": ["horizontal", Vector2(-6, 9.5)],
	"res://scenes/attacks/sword_launch.tscn": ["launch", Vector2(-6, 9.5)],
	"res://scenes/attacks/sword_horizontal_finish.tscn": ["finisher", Vector2(-6, 9.5)],
	"res://scenes/attacks/sword_downward.tscn": ["downward", Vector2(-6, -3.5)],
	"res://scenes/attacks/sword_tri_strike.tscn": ["tri_strike", Vector2(-6, 9.5)],
	"res://scenes/attacks/sword_gather_clouds.tscn": ["gather_clouds", Vector2(-6, 9.5)],
	"res://scenes/attacks/sword_running_slash.tscn": ["running", Vector2(-6, 9.5)],
	"res://scenes/attacks/sword_scale_the_summit.tscn": ["summit", Vector2(-6, 9.5)],
	"res://scenes/attacks/sword_imbibe_the_sky.tscn": ["imbibe", Vector2(-6, 9.5)],
	"res://scenes/attacks/sword_sever_the_roots.tscn": ["sever", Vector2(-6, 9.5)],
}

@export var arc := "horizontal"

static var _cache := {}


func _ready() -> void:
	sprite_frames = frames_for(arc)
	animation = ARCS[arc].animation


## Gives a freshly spawned sword scene its generated arc, even if the scene file
## still has an old placeholder sprite (e.g. an open editor saved an old copy over it).
## Does nothing for scenes without an arc.
static func apply_to(sword: Node) -> void:
	var entry = SCENE_ARCS.get(sword.scene_file_path)
	if entry == null:
		return
	var sprite: AnimatedSprite2D = sword.get_node("AnimatedSprite2D")
	sprite.sprite_frames = frames_for(entry[0])
	sprite.animation = ARCS[entry[0]].animation
	sprite.position = entry[1]
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE


static func frames_for(arc_name: String) -> SpriteFrames:
	if not _cache.has(arc_name):
		_cache[arc_name] = _build(ARCS[arc_name])
	return _cache[arc_name]


static func _build(spec: Dictionary) -> SpriteFrames:
	var sweep := minf(spec.duration, spec.get("sweep", SWEEP_SECONDS))
	var per_swing: int = spec.get("frames", FRAMES)
	var textures: Array[Texture2D] = []
	for swing in spec.get("swings", [spec]):
		for k in per_swing:
			if spec.get("streak", false):
				textures.append(_draw_streak(spec, k, per_swing))
			else:
				textures.append(_draw_frame(swing, spec.pivot_ahead, k, per_swing))
	var count := textures.size()
	var frames := SpriteFrames.new()
	# The attack code plays "attack" on every sword scene, so always provide it too.
	for anim in {spec.animation: true, &"attack": true}:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, false)
		frames.set_animation_speed(anim, count / sweep)
		for k in count:
			var hold := 1.0
			if k == count - 1:
				hold += (spec.duration - sweep) * count / sweep
			frames.add_frame(anim, textures[k], hold)
	return frames


## Frame `k` of `frame_count` for one swing: a crescent along the arc whose leading
## edge races from `from` to `to` while its tail follows and thins out. The last frame
## is empty.
## Frame `k` of `frame_count` of a straight streak: its leading point shoots out from
## `from` to `to` along `angle` while the tail follows, thickest at the head, with a
## slight bow. The last frame is empty.
static func _draw_streak(spec: Dictionary, k: int, frame_count: int) -> Texture2D:
	var reach: float = spec.to + spec.thickness + 2.0
	var ahead: float = spec.pivot_ahead
	var width := int(2.0 * (ahead + reach))
	var height := int(2.0 * reach)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var pivot := Vector2(width / 2.0 + ahead, height / 2.0)
	var angle := deg_to_rad(spec.angle)
	var dir := Vector2(-cos(angle), sin(angle)) # Mirrored: the art faces left.
	var normal := dir.orthogonal()
	var p := float(k + 1) / frame_count
	var head: float = lerpf(spec.from, spec.to, 1.0 - pow(1.0 - minf(1.0, p / 0.55), 3.0))
	var tail: float = lerpf(spec.from, spec.to, clampf((p - 0.35) / 0.65, 0.0, 1.0))
	if head > tail:
		var s := tail
		while s <= head:
			var u := (s - tail) / (head - tail) # 0 at the tail, 1 at the head.
			var bow := sin(PI * (s - spec.from) / (spec.to - spec.from)) * 2.0
			var center := pivot + dir * s + normal * bow
			var half: float = spec.thickness * 0.5 * pow(u, 0.5) + 0.4
			for y in range(int(center.y - half - 1), int(center.y + half + 2)):
				for x in range(int(center.x - half - 1), int(center.x + half + 2)):
					var off := Vector2(x + 0.5, y + 0.5).distance_to(center)
					if off <= half and x >= 0 and y >= 0 and x < width and y < height:
						var color := CORE_COLOR if off < half * 0.5 else EDGE_COLOR
						color.a = 0.35 + 0.65 * u
						if image.get_pixel(x, y).a < color.a:
							image.set_pixel(x, y, color)
			s += 0.5
	return ImageTexture.create_from_image(image)


static func _draw_frame(spec: Dictionary, ahead: float, k: int, frame_count: int) -> Texture2D:
	var radius: float = spec.radius
	var thickness: float = spec.thickness
	var width := int(2.0 * (ahead + radius + thickness + 2.0))
	var height := int(2.0 * (radius + thickness + 2.0))
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var pivot := Vector2(width / 2.0 + ahead, height / 2.0)

	# The visible stretch of the arc, as fractions of the whole sweep.
	var p := float(k + 1) / frame_count
	var head := 1.0 - pow(1.0 - minf(1.0, p / 0.6), 2.0)
	var tail := clampf((p - 0.45) / 0.55, 0.0, 1.0)
	if head > tail:
		var reach := radius + thickness
		for y in range(maxi(0, int(pivot.y - reach)), mini(height, int(pivot.y + reach) + 1)):
			for x in range(maxi(0, int(pivot.x - reach)), mini(width, int(pivot.x + reach) + 1)):
				var dx := pivot.x - (x + 0.5) # Mirrored: the art faces left.
				var dy := (y + 0.5) - pivot.y
				var off := absf(sqrt(dx * dx + dy * dy) - radius)
				if off > thickness:
					continue
				var q: float = (rad_to_deg(atan2(dy, dx)) - spec.from) / (spec.to - spec.from)
				if q < tail or q > head:
					continue
				var u: float = (q - tail) / (head - tail) # 0 at the trailing end, 1 at the blade.
				var half := thickness * 0.5 * pow(u, 0.6)
				if off > half:
					continue
				var color := CORE_COLOR if off < half * 0.45 else EDGE_COLOR
				color.a = 0.3 + 0.7 * u
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
