@echo off
cd /d %~dp0

start "SmartButler Backend (DEV)" cmd /k "cd /d %~dp0 && START_DEV.bat"
start "SmartButler Flutter (Emulator)" cmd /k "cd /d %~dp0 && START_FLUTTER_EMULATOR.bat"

