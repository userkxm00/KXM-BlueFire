@echo off
setlocal EnableExtensions
title KXM // BLUEFIRE v14
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

set "ENGINE=%~dp0KXM_BLUEFIRE_V14.ps1"
set "LANGFILE=%~dp0KXM_LANG.json"

if not exist "%ENGINE%" (
    echo [KXM] ERROR: KXM_BLUEFIRE_V14.ps1 not found.
    pause
    exit /b 2
)
if not exist "%LANGFILE%" (
    echo [KXM] ERROR: KXM_LANG.json not found.
    pause
    exit /b 3
)

echo.
echo [KXM] Validating Windows PowerShell 5.1 engine...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p='%ENGINE%';$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$null,[ref]$e);if($e.Count -gt 0){Write-Host '';Write-Host 'KXM // SYNTAX CHECK FAILED' -ForegroundColor Red;foreach($x in $e){Write-Host ('Line '+$x.Extent.StartLineNumber+': '+$x.Message) -ForegroundColor Red};exit 10}else{Write-Host '[KXM] Syntax check: PASS' -ForegroundColor Green}"
if errorlevel 1 (
    echo.
    echo KXM engine was NOT executed.
    pause
    exit /b 10
)

chcp 65001 >nul 2>&1
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
