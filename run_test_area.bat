@echo off
rem Launches the old test area (the slime arena, "2D Game.tscn") instead of the opening level.
rem print() output, script errors and stack traces appear in this console.
rem Extra Godot flags can be passed through, e.g.:  run_test_area.bat --debug-collisions
"C:\Users\James\Desktop\gam\Godot\Godot_v4.3-stable_win64_console.exe" --path "%~dp0test" "res://scenes/2D Game.tscn" %*
rem Keep the console open after the game closes, so errors can still be read.
pause
