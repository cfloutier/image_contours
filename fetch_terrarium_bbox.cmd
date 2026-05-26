@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PY=%SCRIPT_DIR%.condaenv\python.exe"
set "SCRIPT=%SCRIPT_DIR%tools\fetch_terrarium_bbox.py"

if not exist "%PY%" (
  echo [ERROR] Python env not found: "%PY%"
  echo Create it first, then retry.
  pause
  exit /b 1
)

if not exist "%SCRIPT%" (
  echo [ERROR] Script not found: "%SCRIPT%"
  pause
  exit /b 1
)

echo.
echo === Terrarium BBox Fetcher ===
echo Tip: Draw a rectangle on a map site, copy coords, then paste here.
echo.

"%PY%" "%SCRIPT%" %*
set "EC=%ERRORLEVEL%"

echo.
if "%EC%"=="0" (
  echo Done.
) else (
  echo Failed with exit code %EC%.
)

pause
exit /b %EC%
