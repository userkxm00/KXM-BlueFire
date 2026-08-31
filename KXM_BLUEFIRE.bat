@echo off
setlocal EnableExtensions
title KXM // BLUEFIRE v26
color 0A

fltmc >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "ENGINE=%~dp0KXM_BLUEFIRE.ps1"
set "LANG=%~dp0KXM_LANG.json"

if not exist "%ENGINE%" (
  echo [KXM] Missing KXM_BLUEFIRE.ps1
  pause
  exit /b 2
)
if not exist "%LANG%" (
  echo [KXM] Missing KXM_LANG.json
  pause
  exit /b 3
)

echo [KXM] Validating Windows PowerShell 5.1 engine...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p='%ENGINE%';$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$null,[ref]$e);if($e.Count -gt 0){Write-Host 'KXM // SYNTAX CHECK FAILED' -ForegroundColor Red;foreach($x in $e){Write-Host ('Line '+$x.Extent.StartLineNumber+': '+$x.Message) -ForegroundColor Red};exit 10}else{Write-Host '[KXM] Syntax check: PASS' -ForegroundColor Green}"
if errorlevel 1 (
  echo KXM engine was NOT executed.
  pause
  exit /b 10
)

chcp 65001 >nul 2>&1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%"
exit /b %errorlevel%
