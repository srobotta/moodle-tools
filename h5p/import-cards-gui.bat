@echo off

rem Copyright 2026 Stephan Robotta
rem Released under the terms of the GNU General Public Licence, version 3
rem <http://www.gnu.org/licenses/>

rem Windows launcher for import-cards-gui.py.
rem Double-click this file to open the GUI without a console window.
rem It runs the GUI with pythonw (no console); if pythonw is missing it
rem falls back to the py launcher, then to python.

setlocal
set "SCRIPT=%~dp0import-cards-gui.py"
set "EXEC="
set "ARGS="

rem Prefer pythonw.exe so no console window stays open behind the GUI.
where pythonw >nul 2>nul
if %errorlevel%==0 (
    set "EXEC=pythonw"
    goto checkpackage
)

rem Fall back to the Python launcher (py -w hides the console too).
where py >nul 2>nul
if %errorlevel%==0 (
    set "EXEC=py"
    set "ARGS=-w"
    goto checkpackage
)

rem Last resort: plain python (a console window may remain visible).
where python >nul 2>nul
if %errorlevel%==0 (
    set "EXEC=python"
    goto checkpackage
)

echo Python was not found on your PATH.
echo Please install Python from https://www.python.org/downloads/
echo and make sure "Add Python to PATH" is checked during installation.
pause
goto :eof

:checkpackage
rem Check whether odfpy (reads .ods files) is installed.
%EXEC% %ARGS% -c "import odf" >nul 2>nul

if errorlevel 1 (
    echo Installing required Python package odfpy...
    %EXEC% %ARGS% -m pip install --user --no-input odfpy

    if errorlevel 1 (
        echo.
        echo Cannot install required Python package odfpy.
        pause
        goto :eof
    )
)

rem Check whether openpyxl (reads .xlsx files) is installed.
%EXEC% %ARGS% -c "import openpyxl" >nul 2>nul

if errorlevel 1 (
    echo Installing required Python package openpyxl...
    %EXEC% %ARGS% -m pip install --user --no-input openpyxl

    if errorlevel 1 (
        echo.
        echo Cannot install required Python package openpyxl.
        pause
        goto :eof
    )
)

rem Launch the GUI.
start "" %EXEC% %ARGS% "%SCRIPT%"
goto :eof
