@echo off
rem Launches SwordSaint in a debug window, without the Godot editor.
rem print() output, script errors and stack traces appear in this console.
rem Extra Godot flags can be passed through, e.g.:  run.bat --debug-collisions
"C:\Users\James\Desktop\gam\Godot\Godot_v4.3-stable_win64_console.exe" --path "%~dp0test" %*
rem Keep the console open after the game closes, so errors can still be read.
pause
