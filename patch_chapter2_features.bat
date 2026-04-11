@echo off
set "SETUP_DIR=%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0patch_chapter2_features.ps1"
