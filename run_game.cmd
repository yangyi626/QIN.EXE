@echo off
setlocal
cd /d "%~dp0"
if defined GODOT_EXE if exist "%GODOT_EXE%" goto found
set "GODOT_EXE="
for %%G in ("D:\Tools\Godot\Godot*_win64.exe") do if exist "%%~fG" set "GODOT_EXE=%%~fG"
if defined GODOT_EXE goto found
for %%G in (godot.exe godot4.exe) do for /f "delims=" %%P in ('where %%G 2^>nul') do set "GODOT_EXE=%%P"
if defined GODOT_EXE goto found
echo Godot not found. Install Godot 4.2+ or set GODOT_EXE to its executable path.
pause
exit /b 1
:found
echo Importing project with "%GODOT_EXE%"...
"%GODOT_EXE%" --headless --path "%~dp0." --editor --import --quit
if errorlevel 1 (
  echo Project import failed. See the output above.
  pause
  exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0." --log-file "%~dp0.godot\game-run.log"
exit /b 0
