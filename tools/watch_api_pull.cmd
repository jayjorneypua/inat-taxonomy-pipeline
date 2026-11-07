@echo off
title inat api pull watcher
cd /d "%~dp0.."
.venv\Scripts\python.exe tools\watch_api_pull.py
pause