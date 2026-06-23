@echo off
REM ============================================================
REM  All-In-One Spicetify Installer (Windows)
REM  Marketplace + rxri extensions pre-bundled
REM
REM  Double-click this file or run it from Command Prompt.
REM  It launches the PowerShell installer with bypass policy.
REM ============================================================

title All-In-One Spicetify Installer

echo.
echo   All-In-One Spicetify Installer
echo   Marketplace + rxri extensions pre-bundled
echo.

REM Try PowerShell 7+ (pwsh) first, fall back to Windows PowerShell
where pwsh >nul 2>nul
if %errorlevel%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/alunit3/aluspicetify/main/install-alus.ps1 | iex"
    goto :done
)

where powershell >nul 2>nul
if %errorlevel%==0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/alunit3/aluspicetify/main/install-alus.ps1 | iex"
    goto :done
)

echo  ERROR: PowerShell not found on this system.
echo  Please install PowerShell 5.1 or higher.
echo.
pause
exit /b 1

:done
echo.
pause
