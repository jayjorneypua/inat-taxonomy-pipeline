@echo off
title inat pipeline watcher
cd /d "%~dp0.."
.venv\Scripts\python.exe tools\watch_pipeline.py
pause