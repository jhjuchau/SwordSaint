@echo off
rem Runs the gameplay tests headlessly and prints PASS/FAIL for each check.
rem   run_tests.bat            all tests
rem   run_tests.bat combo      combo regression tests (options: a case-name prefix, and/or
rem                            enemy=slime or enemy=mole, e.g.  run_tests.bat combo "Iai" enemy=mole)
rem   run_tests.bat fireball   fireball / projectile tests
rem Tileset warnings from level_1's tileset are filtered out.
setlocal
set GODOT="C:\Users\James\Desktop\gam\Godot\Godot_v4.3-stable_win64_console.exe"
set PROJECT="%~dp0..\test"
set FILTER=findstr /v /c:"tile_set.cpp" /c:"TileSetAtlas" /c:"Cannot create tile" /c:"leaked" /c:"resources still in use" /c:"   at: "
if "%~1"=="" (
	call :run combo_tests
	call :run fireball_tests
) else (
	call :run %~1_tests %2 %3
)
pause
exit /b

:run
echo.
echo ===== %1 =====
%GODOT% --headless --path %PROJECT% --script "%~dp0%1.gd" -- %~2 %~3 2>&1 | %FILTER%
exit /b
