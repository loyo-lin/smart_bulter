@echo off
cd /d %~dp0
python main.py prod --port 8000 --allow-origins *
