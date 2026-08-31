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
Write-Host 'PASS: core functions are present' -ForegroundColor Green
