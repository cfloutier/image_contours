@echo off
setlocal

rem Defensive: if an environment variable named ERRORLEVEL exists,
rem it can mask CMD's dynamic errorlevel expansion.
set "ERRORLEVEL="

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
echo.

"%PY%" "%SCRIPT%" %*
set "EC=%ERRORLEVEL%"

if not defined EC set "EC=1"

echo.
if "%EC%"=="0" (
  echo Done.
) else (
  echo Failed with exit code %EC%.
)

pause
exit /b %EC%
