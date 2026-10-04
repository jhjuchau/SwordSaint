extends RefCounted

## The playable characters, and which one was picked on the character select screen
## (kept in a static var, so it survives scene changes). Levels read `selected` when
## the player spawns. Launching a level directly (e.g. run_test_area.bat) uses the
## Sword Saint, unless Godot is given `-- character=dogood`.

const SAINT := "saint"
const DOGOOD := "dogood"
const ELF := "elf"

const INFO := {
	SAINT: {
		"name": "Sword Saint",
		"title": "The Wandering Blade",
		"blurb": "An old swordsman of few words. Iai draws that cut the sky itself.",
	},
	DOGOOD: {
		"name": "Dogood",
		"title": "Father of Electricity",
		"blurb": "Statesman, inventor, wrestler. Discovered lightning by suplexing men into storms.",
	},
	ELF: {
		"name": "Ilyra",
		"title": "Arch-Mage of the Wilds",
		"blurb": "An elven sorceress. Her spells take their time. When they land, they land hard.",
	},
}

static var selected := _from_command_line()
## Where the character select screen goes once a character is picked.
static var destination := "res://scenes/opening/opening.tscn"


static func _from_command_line() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("character="):
			return arg.trim_prefix("character=")
	return SAINT
