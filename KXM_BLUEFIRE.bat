@echo off
setlocal EnableExtensions
title KXM // BLUEFIRE v24
color 0A

fltmc >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "ENGINE=%~dp0KXM_BLUEFIRE_V24_GUI.ps1"
if not exist "%ENGINE%" (
  echo [KXM] Missing engine: %ENGINE%
  pause
  exit /b 2
)

set "LANG=%~dp0KXM_LANG_V24.json"
if not exist "%LANG%" (
  echo [KXM] Missing language file: %LANG%
  pause
  exit /b 3
)

echo.
echo [KXM] BLUEFIRE v24 - checking Windows PowerShell 5.1...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p='%ENGINE%';$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$null,[ref]$e);if($e.Count -gt 0){Write-Host 'KXM // SYNTAX CHECK FAILED' -ForegroundColor Red;foreach($x in $e){Write-Host ('Line '+$x.Extent.StartLineNumber+': '+$x.Message) -ForegroundColor Red};exit 10}else{Write-Host '[KXM] Syntax check: PASS' -ForegroundColor Green}"
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
