# KXM BLUEFIRE v19 launcher/repair wrapper
# Repairs the one parser-fragile expression in the previous v18 GUI at runtime,
# validates the repaired script with the Windows PowerShell 5.1 parser,
# then executes it. This keeps old v18 content usable while v19 remains the entry point.
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$src=Join-Path $PSScriptRoot 'KXM_BLUEFIRE_V18_GUI.ps1'
if(-not(Test-Path $src)){throw 'KXM_BLUEFIRE_V18_GUI.ps1 not found.'}
$raw=Get-Content -LiteralPath $src -Raw -Encoding UTF8
$bad="`$details.Text=((T 'ReadyDone')+'`r`n`r`n'+(if(`$z.BS){'BlueStacks detected.'}else{'BlueStacks not found in common paths.'}) )})"
$good="`$details.Text=((T 'ReadyDone')+'`r`n`r`n'+$(if(`$z.BS){'BlueStacks detected.'}else{'BlueStacks not found in common paths.'}))})"
$fixed=$raw.Replace($bad,$good)
$temp=Join-Path $env:TEMP ('KXM_BLUEFIRE_V19_FIXED_'+[guid]::NewGuid().ToString('N')+'.ps1')
Set-Content -LiteralPath $temp -Value $fixed -Encoding UTF8
try{
  $errors=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($temp,[ref]$null,[ref]$errors)
  if($errors.Count -gt 0){
    foreach($e in $errors){Write-Host ('Line '+$e.Extent.StartLineNumber+': '+$e.Message) -ForegroundColor Red}
    throw 'Repaired KXM engine still has parser errors.'
  }
  & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $temp
  exit $LASTEXITCODE
}finally{
  Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
}
