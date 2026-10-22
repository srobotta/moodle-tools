@echo off
rem Windows launcher for import-cards-gui.py.
rem Double-click this file to open the GUI without a console window.
rem It runs the GUI with pythonw (no console); if pythonw is missing it
rem falls back to the py launcher, then to python.

setlocal
set "SCRIPT=%~dp0import-cards-gui.py"

rem Prefer pythonw.exe so no console window stays open behind the GUI.
where pythonw >nul 2>nul
if %errorlevel%==0 (
    start "" pythonw "%SCRIPT%"
    goto :eof
)

rem Fall back to the Python launcher (py -w hides the console too).
where py >nul 2>nul
if %errorlevel%==0 (
    start "" py -w "%SCRIPT%"
    goto :eof
)

rem Last resort: plain python (a console window may remain visible).
where python >nul 2>nul
if %errorlevel%==0 (
    start "" python "%SCRIPT%"
    goto :eof
)

echo Python was not found on your PATH.
echo Please install Python from https://www.python.org/downloads/
echo and make sure "Add Python to PATH" is checked during installation.
pause
