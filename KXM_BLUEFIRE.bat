@echo off
setlocal
 title KXM // BLUEFIRE
 color 0A
 fltmc >nul 2>&1
 if errorlevel 1 (
   echo Run as administrator.
   pause
   exit /b 1
 )
 set "ENGINE=%~dp0KXM_BLUEFIRE.ps1"
 if not exist "%ENGINE%" (
   echo KXM_BLUEFIRE.ps1 not found.
   pause
   exit /b 2
 )
 echo [KXM] Validating PowerShell engine...
 powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p='%ENGINE%';$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$null,[ref]$e);if($e.Count -gt 0){foreach($x in $e){Write-Host ('Line '+$x.Extent.StartLineNumber+': '+$x.Message) -ForegroundColor Red};exit 10}"
 if errorlevel 1 (
   echo KXM engine syntax check failed.
   pause
   exit /b 10
 )
 chcp 65001 >nul 2>&1
 powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%"
 exit /b %errorlevel%
