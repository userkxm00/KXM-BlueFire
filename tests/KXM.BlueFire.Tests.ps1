$ErrorActionPreference = 'Stop'
$env:KXM_TEST_MODE = '1'

. "$PSScriptRoot\..\KXM_BLUEFIRE.ps1"

function Assert-Equal([object]$actual,[object]$expected,[string]$name) {
    if ($actual -ne $expected) { throw ("FAIL: {0}. Expected [{1}], got [{2}]" -f $name,$expected,$actual) }
    Write-Host ("PASS: {0}" -f $name) -ForegroundColor Green
}

$h1 = [pscustomobject]@{Cores=4;Threads=8;RAM=8;SSD=$false;HDD=$true;Storage='HDD';GPU='Intel HD'}
$r1 = Recommendation $h1
Assert-Equal $r1.Cores 4 '4-core CPU gets 4 emulator cores'
Assert-Equal $r1.RAM 4 '8 GB system gets 4 GB emulator memory'
Assert-Equal $r1.SysMain 'KEEP AUTO' 'HDD/8 GB keeps SysMain automatic'
Assert-Equal $r1.Profile 'Balanced' '8 GB quad-core class uses Balanced profile'

$h2 = [pscustomobject]@{Cores=2;Threads=4;RAM=4;SSD=$false;HDD=$true;Storage='HDD';GPU='Intel HD'}
$r2 = Recommendation $h2
Assert-Equal $r2.Cores 2 '2-core CPU gets 2 emulator cores'
Assert-Equal $r2.RAM 2 '4 GB system gets 2 GB emulator memory'
Assert-Equal $r2.Profile 'Conservative' 'Low-memory dual-core uses Conservative profile'

$h3 = [pscustomobject]@{Cores=8;Threads=16;RAM=16;SSD=$true;HDD=$false;Storage='SSD';GPU='NVIDIA'}
$r3 = Recommendation $h3
Assert-Equal $r3.Cores 6 '8-core CPU gets 6 emulator cores'
Assert-Equal $r3.RAM 6 '16 GB system gets 6 GB emulator memory'
Assert-Equal $r3.Profile 'Competitive' '8-core/16 GB SSD class uses Competitive profile'
Assert-Equal $r3.SysMain 'LEAVE DEFAULT' 'Healthy SSD system does not force SysMain changes'

if (-not (Get-Command Recommendation -ErrorAction SilentlyContinue)) { throw 'Recommendation function missing' }
if (-not (Get-Command RestoreBaseline -ErrorAction SilentlyContinue)) { throw 'RestoreBaseline function missing' }
if (-not (Get-Command Test-KxmLatency -ErrorAction SilentlyContinue)) { throw 'Test-KxmLatency function missing' }
if (-not (Get-Command PendingReboot -ErrorAction SilentlyContinue)) { throw 'PendingReboot function missing' }

$testRoot = Join-Path $env:TEMP ('KXM-Restore-Test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$testKey = 'HKCU:\Software\KXM\BlueFireTest'
try {
    New-Item -Path $testKey -Force | Out-Null
    New-ItemProperty -Path $testKey -Name 'TemporaryValue' -PropertyType DWord -Value 123 -Force | Out-Null
    $entry = [pscustomobject]@{Path=$testKey;Name='TemporaryValue';Exists=$false;Value=$null;Kind='DWord'}
    $state = [pscustomobject]@{Schema=2;Version='26.0';Created=(Get-Date).ToString('o');PowerPlanGuid=$null;Registry=@($entry);Services=@()}
    $baselineDir = Join-Path $testRoot 'Baseline'
    New-Item -ItemType Directory -Path $baselineDir -Force | Out-Null
    $baselineFile = Join-Path $baselineDir 'Baseline.xml'
    $state | Export-Clixml -LiteralPath $baselineFile
    $oldPointer = $Script:Pointer
    $oldMarker = $Script:KxmPowerMarker
    $Script:Pointer = Join-Path $testRoot 'CURRENT_BASELINE.txt'
    Set-Content -LiteralPath $Script:Pointer -Value $baselineDir -Encoding UTF8
    $Script:KxmPowerMarker = Join-Path $testRoot 'NO_POWER_PLAN.txt'
    $restore = RestoreBaseline
    Assert-Equal $restore.Success $true 'RestoreBaseline reports success for a valid snapshot'
    $existsAfter = Test-Path -LiteralPath $testKey
    Assert-Equal $existsAfter $true 'Restore preserves the registry key when needed'
    $valueAfter = (Get-ItemProperty -LiteralPath $testKey -Name 'TemporaryValue').TemporaryValue
    if ($null -ne $valueAfter) { throw 'FAIL: Restore did not remove a value that was absent in the baseline' }
    Write-Host 'PASS: RestoreBaseline removes values absent from the baseline' -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $testKey) { Remove-Item -LiteralPath $testKey -Recurse -Force -ErrorAction SilentlyContinue }
    if ($oldPointer) { $Script:Pointer = $oldPointer }
    if ($oldMarker) { $Script:KxmPowerMarker = $oldMarker }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host 'PASS: KXM core regression suite completed' -ForegroundColor Green
