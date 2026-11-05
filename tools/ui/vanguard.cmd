@echo off
rem vanguard -- the host command (ADR-045): `vanguard ui` starts the read-only dashboard service.
rem Runs the tools\ui Typer app with tools\.venv's interpreter; tools\ is put on the import path here only.
setlocal
set "PYTHONPATH=%~dp0.."
"%~dp0..\.venv\Scripts\python.exe" -m ui %*
exit /b %ERRORLEVEL%
