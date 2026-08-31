@echo off
setlocal EnableExtensions
title KXM // BLUEFIRE v20
color 0A

fltmc >nul 2>&1
if errorlevel 1 (
    cls
    echo.
    echo =======================================================================
    echo                       KXM // ADMINISTRATOR
    echo =======================================================================
    echo.
    echo Right-click KXM_BLUEFIRE.bat and select RUN AS ADMINISTRATOR.
    echo.
    pause
    exit /b 1
)

set "ENGINE=%~dp0KXM_BLUEFIRE_V20_GUI.ps1"
if not exist "%ENGINE%" (
    echo [KXM] ERROR: KXM_BLUEFIRE_V20_GUI.ps1 not found.
    pause
    exit /b 2
)

echo.
echo [KXM] BLUEFIRE v20 - checking PowerShell 5.1 launcher...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p='%ENGINE%';$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$null,[ref]$e);if($e.Count -gt 0){Write-Host 'KXM // LAUNCHER SYNTAX FAILED' -ForegroundColor Red;foreach($x in $e){Write-Host ('Line '+$x.Extent.StartLineNumber+': '+$x.Message) -ForegroundColor Red};exit 10}else{Write-Host '[KXM] Launcher syntax: PASS' -ForegroundColor Green}"
if errorlevel 1 (
    echo.
    echo KXM was NOT executed.
    pause
    exit /b 10
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%"
set "RC=%errorlevel%"
if not "%RC%"=="0" (
    echo.
    echo KXM exited with code %RC%.
    echo Log: C:\ProgramData\KXM\BlueFire\Logs\KXM.log
    echo.
    pause
)
exit /b %RC%
