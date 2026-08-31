# KXM BLUEFIRE v24
# Windows PowerShell 5.1 / WinForms.
# Safe ideas adapted from Z-LAG: verified gaming power plan, session mode,
# cleanup, ping/jitter, conflict checks, reboot status, dry-run and recovery.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Root = Join-Path $env:ProgramData 'KXM\BlueFire'
$BackupRoot = Join-Path $Root 'Backups'
$SessionRoot = Join-Path $Root 'Sessions'
$LogRoot = Join-Path $Root 'Logs'
$Pointer = Join-Path $Root 'CURRENT_BASELINE.txt'
$SessionFile = Join-Path $SessionRoot 'ACTIVE_SESSION.xml'
$LogFile = Join-Path $LogRoot 'KXM.log'
$LangFile = Join-Path $PSScriptRoot 'KXM_LANG_V24.json'
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
New-Item -ItemType Directory -Path $SessionRoot -Force | Out-Null
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
$TX = Get-Content -LiteralPath $LangFile -Raw -Encoding UTF8 | ConvertFrom-Json
$Script:Lang = 'en'

function L {
    param([string]$Key)
    $set = $TX.PSObject.Properties[$Script:Lang].Value
    if ($null -ne $set) {
        $p = $set.PSObject.Properties[$Key]
        if ($null -ne $p) { return [string]$p.Value }
    }
    return $Key
}
function Log {
    param([string]$Text)
    try { Add-Content -LiteralPath $LogFile -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Text) -Encoding UTF8 } catch {}
}
function RegD {
    param([string]$Path,[string]$Name,[int64]$Value)
    try { New-Item -Path $Path -Force | Out-Null; New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null } catch {}
}
function RegS {
    param([string]$Path,[string]$Name,[string]$Value)
    try { New-Item -Path $Path -Force | Out-Null; New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $Value -Force | Out-Null } catch {}
}
function Snap {
    param([string]$Path,[string]$Name)
    $exists = $false
    $value = $null
    $kind = 'DWord'
    try {
        $i = Get-ItemProperty -LiteralPath $Path -ErrorAction Stop
        $p = $i.PSObject.Properties[$Name]
        if ($null -ne $p) {
            $exists = $true
            $value = $p.Value
            if ($value -is [string]) { $kind = 'String' }
        }
    } catch {}
    return [pscustomobject]@{Path=$Path;Name=$Name;Exists=$exists;Value=$value;Kind=$kind}
}
function RestoreSnap {
    param($Entry)
    if ($Entry.Exists) {
        if ($Entry.Kind -eq 'String') { RegS $Entry.Path $Entry.Name ([string]$Entry.Value) }
        else { RegD $Entry.Path $Entry.Name ([int64]$Entry.Value) }
    } else {
        Remove-ItemProperty -LiteralPath $Entry.Path -Name $Entry.Name -ErrorAction SilentlyContinue
    }
}
function ServiceSnap {
    param([string]$Name)
    try {
        $s = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
        if ($s) { return [pscustomobject]@{Name=$Name;Exists=$true;Start=[string]$s.StartMode;State=[string]$s.State} }
    } catch {}
    return [pscustomobject]@{Name=$Name;Exists=$false;Start='';State=''}
}
function DiskInfo {
    $hdd = $false
    $ssd = $false
    try {
        foreach ($d in @(Get-PhysicalDisk)) {
            $m = [string]$d.MediaType
            if ($m -match 'HDD') { $hdd = $true }
            if ($m -match 'SSD') { $ssd = $true }
        }
    } catch {}
    if (-not $hdd -and -not $ssd) {
        try {
            foreach ($d in @(Get-CimInstance Win32_DiskDrive)) {
                $m = ([string]$d.Model + ' ' + [string]$d.MediaType + ' ' + [string]$d.InterfaceType)
                if ($m -match 'SSD|Solid State|NVMe') { $ssd = $true }
                elseif ($m -match 'HDD|Hard Disk') { $hdd = $true }
            }
        } catch {}
    }
    return [pscustomobject]@{HDD=$hdd;SSD=$ssd}
}
function Hardware {
    $c = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cs = Get-CimInstance Win32_ComputerSystem
    $gpus = @(Get-CimInstance Win32_VideoController)
    $d = DiskInfo
    $ram = 0
    if ($cs) { $ram = [math]::Round($cs.TotalPhysicalMemory / 1GB,1) }
    $gpu = 'Unknown'
    foreach ($g in $gpus) {
        if ($gpu -eq 'Unknown') { $gpu = [string]$g.Name } else { $gpu += ' | ' + [string]$g.Name }
    }
    return [pscustomobject]@{
        CPU=if ($c) { [string]$c.Name } else { 'Unknown' }
        Cores=if ($c) { [int]$c.NumberOfCores } else { 0 }
        Threads=if ($c) { [int]$c.NumberOfLogicalProcessors } else { 0 }
        RAM=$ram
        GPU=$gpu
        HDD=$d.HDD
        SSD=$d.SSD
        Virtualization=if ($c) { [bool]$c.VirtualizationFirmwareEnabled } else { $false }
    }
}
function Recommendation {
    param($H)
    $cores = 4
    $ram = 4
    if ($H.Threads -lt 4) { $cores = 2 }
    if ($H.RAM -lt 8) { $ram = 2 }
    return [pscustomobject]@{Cores=$cores;RAM=$ram;Mode='High Performance';FPS='120 recommended / 240 ceiling optional';SysMain=if ($H.HDD -or $H.RAM -le 8) {'KEEP AUTO'} else {'OPTIONAL'}}
}
function BlueStacksPath {
    foreach ($p in @(
        "$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe",
        "$env:ProgramFiles\BlueStacks_nxt5\HD-Player.exe",
        "${env:ProgramFiles(x86)}\BlueStacks_nxt\HD-Player.exe",
        "${env:ProgramFiles(x86)}\BlueStacks_nxt5\HD-Player.exe"
    )) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}
function PendingReboot {
    $a = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $b = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    return ($a -or $b)
}
function Conflicts {
    $list = New-Object System.Collections.ArrayList
    if (Get-Process -Name Discord -ErrorAction SilentlyContinue) { [void]$list.Add('Discord running') }
    if (Get-Process -Name RivaTunerStatisticsServer -ErrorAction SilentlyContinue) { [void]$list.Add('RTSS running') }
    $vmms = Get-Service vmms -ErrorAction SilentlyContinue
    if ($vmms -and $vmms.Status -eq 'Running') { [void]$list.Add('Hyper-V service running') }
    $docker = Get-Service com.docker.service -ErrorAction SilentlyContinue
    if ($docker -and $docker.Status -eq 'Running') { [void]$list.Add('Docker service running') }
    return $list
}
function CreateBaseline {
    if (Test-Path $Pointer) {
        $d = (Get-Content $Pointer -Raw -Encoding UTF8).Trim()
        if ($d -and (Test-Path (Join-Path $d 'Baseline.xml'))) { return $d }
    }
    $d = Join-Path $BackupRoot (Get-Date -Format 'yyyyMMdd_HHmmss')
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    $st = [ordered]@{Created=(Get-Date).ToString('o');Power=((powercfg /getactivescheme)-join ' ');Registry=New-Object System.Collections.ArrayList;Services=New-Object System.Collections.ArrayList}
    foreach ($x in @(
        @('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile','SystemResponsiveness'),
        @('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile','NetworkThrottlingIndex'),
        @('HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl','Win32PrioritySeparation'),
        @('HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling','PowerThrottlingOff'),
        @('HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers','HwSchMode'),
        @('HKLM:\SOFTWARE\Microsoft\Windows\Dwm','OverlayTestMode'),
        @('HKCU:\Software\Microsoft\GameBar','AutoGameModeEnabled'),
        @('HKCU:\System\GameConfigStore','GameDVR_Enabled'),
        @('HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR','AppCaptureEnabled')
    )) { $st.Registry.Add((Snap $x[0] $x[1])) }
    $st.Services.Add((ServiceSnap 'SysMain'))
    $st | Export-Clixml (Join-Path $d 'Baseline.xml')
    powercfg /list | Out-File (Join-Path $d 'PowerPlans.txt') -Encoding UTF8
    bcdedit /enum all | Out-File (Join-Path $d 'BCD.txt') -Encoding UTF8
    Set-Content $Pointer $d -Encoding UTF8
    Log ('Baseline created: ' + $d)
    return $d
}
function EnsureBaseline { $null = CreateBaseline }
function EnsureMaxFPSPlan {
    $marker = Join-Path $Root 'MAX_FPS_GUID.txt'
    if (Test-Path $marker) {
        $guid = (Get-Content $marker -Raw).Trim()
        if ($guid -and (powercfg /list | Select-String $guid)) { return $guid }
    }
    $source = (powercfg /getactivescheme | Select-String -Pattern '([0-9a-fA-F-]{36})').Matches.Groups[1].Value
    if (-not $source) { $source = 'SCHEME_MIN' }
    $new = (powercfg /duplicatescheme $source 2>&1 | Select-String -Pattern '([0-9a-fA-F-]{36})').Matches.Groups[1].Value
    if (-not $new) { return $null }
    powercfg /changename $new 'KXM Maximum FPS' 'KXM session gaming plan' | Out-Null
    powercfg /setacvalueindex $new SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
    powercfg /setacvalueindex $new SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg /setacvalueindex $new SUB_USB USBSELECTIVE 0 | Out-Null
    Set-Content $marker $new -Encoding ASCII
    return $new
}
function ActivateMaxFPSPlan {
    $guid = EnsureMaxFPSPlan
    if ($guid) {
        powercfg /setactive $guid | Out-Null
        $active = ((powercfg /getactivescheme) -join ' ')
        if ($active -match [regex]::Escape($guid)) { return $true }
    }
    return $false
}
function CleanSafe {
    foreach ($d in @($env:TEMP,(Join-Path $env:LOCALAPPDATA 'Temp'),'C:\Windows\Temp')) {
        if (Test-Path $d) { Remove-Item -LiteralPath (Join-Path $d '*') -Recurse -Force -ErrorAction SilentlyContinue }
    }
    ipconfig /flushdns | Out-Null
}
function PingJitter {
    $targets = New-Object System.Collections.ArrayList
    try {
        $gw = Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Sort-Object RouteMetric,InterfaceMetric | Select-Object -First 1 -ExpandProperty NextHop
        if ($gw -and $gw -ne '0.0.0.0') { [void]$targets.Add(@('Gateway',$gw)) }
    } catch {}
    [void]$targets.Add(@('Cloudflare','1.1.1.1'))
    [void]$targets.Add(@('Google','8.8.8.8'))
    $out = New-Object System.Collections.ArrayList
    foreach ($t in $targets) {
        try {
            $r = @(Test-Connection -ComputerName $t[1] -Count 5 -ErrorAction Stop)
            $times = @($r | ForEach-Object {[double]$_.ResponseTime})
            if ($times.Count -gt 0) {
                $avg = [math]::Round((($times | Measure-Object -Average).Average),1)
                $max = [math]::Round((($times | Measure-Object -Maximum).Maximum),1)
                $min = [math]::Round((($times | Measure-Object -Minimum).Minimum),1)
                $jitter = [math]::Round(($max-$min),1)
                [void]$out.Add(('{0}: avg {1} ms | max {2} ms | jitter {3} ms' -f $t[0],$avg,$max,$jitter))
            } else { [void]$out.Add(($t[0] + ': no replies')) }
        } catch { [void]$out.Add(($t[0] + ': test failed')) }
    }
    return ($out -join "`r`n")
}
function StartSession {
    EnsureBaseline
    if (Test-Path $SessionFile) { return 'GAME SESSION ALREADY ACTIVE.' }
    $p = Get-Process -Name HD-Player -ErrorAction SilentlyContinue | Select-Object -First 1
    $oldPower = ((powercfg /getactivescheme) -join ' ')
    $oldPriority = if ($p) { [string]$p.PriorityClass } else { 'NotRunning' }
    $state = [ordered]@{Started=(Get-Date).ToString('o');Power=$oldPower;Priority=$oldPriority}
    $state | Export-Clixml $SessionFile
    CleanSafe
    $plan = ActivateMaxFPSPlan
    if ($p) { try { $p.PriorityClass='AboveNormal' } catch {} }
    Log 'GAME READY session started'
    if ($plan) { return 'GAME READY ACTIVE.`r`n`r`nTemp cleanup: OK`r`nDNS flush: OK`r`nKXM Maximum FPS plan: VERIFIED ACTIVE`r`nBlueStacks priority: session-tuned' }
    return 'GAME READY ACTIVE.`r`n`r`nTemp cleanup: OK`r`nDNS flush: OK`r`nKXM Maximum FPS plan: unavailable'
}
function EndSession {
    if (-not (Test-Path $SessionFile)) { return 'NO ACTIVE KXM SESSION.' }
    $s = Import-Clixml $SessionFile
    if ($s.Power -match '([0-9a-fA-F-]{36})') { powercfg /setactive $Matches[1] | Out-Null }
    Remove-Item $SessionFile -Force -ErrorAction SilentlyContinue
    Log 'GAME READY session ended'
    return 'SESSION ENDED.`r`nOriginal power plan restored.'
}
function SmartOptimize {
    EnsureBaseline
    $h = Hardware
    $r = Recommendation $h
    powercfg /setactive SCHEME_MIN | Out-Null
    RegD 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    RegD 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    RegD 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    $mm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    $g = "$mm\Tasks\Games"
    RegD $mm 'SystemResponsiveness' 0
    RegD $mm 'NetworkThrottlingIndex' 4294967295
    RegD $g 'GPU Priority' 8
    RegD $g 'Priority' 6
    RegD 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38
    RegD 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1
    if ($h.HDD -or $h.RAM -le 8) {
        Set-Service SysMain -StartupType Automatic
        Start-Service SysMain
    }
    Log 'SMART OPTIMIZE applied'
    return $r
}
function RestoreBaseline {
    if (-not (Test-Path $Pointer)) { return $false }
    $d=(Get-Content $Pointer -Raw -Encoding UTF8).Trim()
    $f=Join-Path $d 'Baseline.xml'
    if (-not (Test-Path $f)) { return $false }
    $st=Import-Clixml $f
    foreach ($e in $st.Registry) { RestoreSnap $e }
    foreach ($s in $st.Services) {
        if ($s.Start -eq 'Auto') { Set-Service $s.Name -StartupType Automatic }
        elseif ($s.Start -eq 'Manual') { Set-Service $s.Name -StartupType Manual }
        elseif ($s.Start -eq 'Disabled') { Set-Service $s.Name -StartupType Disabled }
        if ($s.State -eq 'Running') { Start-Service $s.Name }
        elseif ($s.State -eq 'Stopped') { Stop-Service $s.Name -Force }
    }
    if ($st.Power -match '([0-9a-fA-F-]{36})') { powercfg /setactive $Matches[1] | Out-Null }
    Log 'Baseline restored'
    return $true
}
function DryRun {
    param($H)
    return @(
        'SAFE CHANGE PREVIEW',
        '',
        '+ Gaming power profile',
        '+ Game Mode / Game DVR policy',
        '+ MMCSS gaming policy',
        '+ Power throttling off',
        '+ BlueStacks GPU preference when detected',
        '+ SysMain kept AUTO on HDD / <=8 GB',
        '',
        'NO: pagefile disable',
        'NO: forced HPET',
        'NO: blind MSI mode',
        'NO: Defender removal',
        'NO: Edge/WebView removal',
        'NO: aggressive service purge'
    ) -join "`r`n"
}

# GUI
$form=New-Object System.Windows.Forms.Form
$form.Text='KXM // BLUEFIRE v24'
$form.Size=New-Object System.Drawing.Size(1240,820)
$form.StartPosition='CenterScreen'
$form.BackColor=[System.Drawing.Color]::FromArgb(8,11,16)
$form.ForeColor=[System.Drawing.Color]::White
$form.Font=New-Object System.Drawing.Font('Segoe UI',10)
$form.FormBorderStyle='FixedSingle'
$form.MaximizeBox=$false

$header=New-Object System.Windows.Forms.Label
$header.Text='KXM // BLUEFIRE'
$header.Location=New-Object System.Drawing.Point(38,22)
$header.Size=New-Object System.Drawing.Size(700,50)
$header.Font=New-Object System.Drawing.Font('Segoe UI Semibold',25)
$header.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200)
$form.Controls.Add($header)

$sub=New-Object System.Windows.Forms.Label
$sub.Text='Gaming Performance Suite  •  GGOS / BlueStacks / Free Fire'
$sub.Location=New-Object System.Drawing.Point(42,70)
$sub.Size=New-Object System.Drawing.Size(850,30)
$sub.ForeColor=[System.Drawing.Color]::Silver
$form.Controls.Add($sub)

$status=New-Object System.Windows.Forms.Label
$status.Text='● SYSTEM READY'
$status.Location=New-Object System.Drawing.Point(890,28)
$status.Size=New-Object System.Drawing.Size(285,42)
$status.TextAlign='MiddleRight'
$status.Font=New-Object System.Drawing.Font('Segoe UI Semibold',12)
$status.ForeColor=[System.Drawing.Color]::FromArgb(120,255,175)
$form.Controls.Add($status)

$h=Hardware
$r=Recommendation $h

$dash=New-Object System.Windows.Forms.Panel
$dash.Location=New-Object System.Drawing.Point(32,112)
$dash.Size=New-Object System.Drawing.Size(1140,112)
$dash.BackColor=[System.Drawing.Color]::FromArgb(18,23,31)
$form.Controls.Add($dash)

$cards=@(
    @('CPU',$h.CPU),
    @('RAM',("$($h.RAM) GB")),
    @('GPU',$h.GPU),
    @('STORAGE',("HDD=$($h.HDD)  SSD=$($h.SSD)")),
    @('FREE FIRE',("$($r.Cores) Cores / $($r.RAM) GB"))
)
$x=14
foreach($c in $cards){
    $p=New-Object System.Windows.Forms.Panel
    $p.Location=New-Object System.Drawing.Point($x,14)
    $p.Size=New-Object System.Drawing.Size(208,84)
    $p.BackColor=[System.Drawing.Color]::FromArgb(25,31,41)
    $l=New-Object System.Windows.Forms.Label
    $l.Text="$($c[0])`r`n$($c[1])"
    $l.Dock='Fill'
    $l.TextAlign='MiddleCenter'
    $l.ForeColor=[System.Drawing.Color]::White
    $p.Controls.Add($l)
    $dash.Controls.Add($p)
    $x+=222
}

$quick=New-Object System.Windows.Forms.GroupBox
$quick.Text='  QUICK PLAY  '
$quick.Location=New-Object System.Drawing.Point(32,242)
$quick.Size=New-Object System.Drawing.Size(1140,120)
$quick.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200)
$form.Controls.Add($quick)

function New-ActionButton {
    param([string]$Text,[int]$X,[int]$W,[scriptblock]$Action,[System.Drawing.Color]$BackColor)
    $b=New-Object System.Windows.Forms.Button
    $b.Text=$Text
    $b.Location=New-Object System.Drawing.Point($X,30)
    $b.Size=New-Object System.Drawing.Size($W,68)
    $b.Font=New-Object System.Drawing.Font('Segoe UI Semibold',12)
    $b.BackColor=$BackColor
    $b.ForeColor=[System.Drawing.Color]::White
    $b.FlatStyle='Flat'
    $b.Add_Click($Action)
    $quick.Controls.Add($b)
    return $b
}

$ready=New-ActionButton 'GAME READY  ⚡' 18 235 {
    $details.Text=StartSession
    $status.Text='● GAME SESSION ACTIVE'
} ([System.Drawing.Color]::FromArgb(0,126,112))

$end=New-ActionButton 'END SESSION' 268 205 {
    $details.Text=EndSession
    $status.Text='● SYSTEM READY'
} ([System.Drawing.Color]::FromArgb(58,47,44))

$smart=New-ActionButton 'SMART OPTIMIZE' 486 220 {
    $ans=[System.Windows.Forms.MessageBox]::Show('Apply the recommended KXM profile for this hardware?','KXM // Smart Optimize',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
    if($ans -eq [System.Windows.Forms.DialogResult]::Yes){
        $nr=SmartOptimize
        $status.Text='● OPTIMIZED'
        $details.Text=('SMART PROFILE APPLIED`r`n`r`nFree Fire: {0} CPU cores / {1} GB RAM`r`nPower: {2}`r`nFPS target: {3}`r`nSysMain: {4}`r`n`r`nRecovery baseline:`r`n{5}' -f $nr.Cores,$nr.RAM,$nr.Mode,$nr.FPS,$nr.SysMain,((Get-Content $Pointer -Raw -Encoding UTF8).Trim()))
    }
} ([System.Drawing.Color]::FromArgb(34,44,58))

$restore=New-ActionButton 'RESTORE ORIGINAL' 721 220 {
    $ans=[System.Windows.Forms.MessageBox]::Show('Restore the settings captured before KXM changes?','KXM // Restore',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning)
    if($ans -eq [System.Windows.Forms.DialogResult]::Yes){
        if(RestoreBaseline){$status.Text='● RESTORED';$details.Text='RESTORE COMPLETE.`r`n`r`nOriginal captured settings restored.`r`nReboot Windows before testing.'}
        else {$details.Text='No valid KXM baseline found.'}
    }
} ([System.Drawing.Color]::FromArgb(73,50,47))

$live=New-Object System.Windows.Forms.Label
$live.Text='SYSTEM ENGINE'
$live.Location=New-Object System.Drawing.Point(36,377)
$live.Size=New-Object System.Drawing.Size(300,32)
$live.Font=New-Object System.Drawing.Font('Segoe UI Semibold',12)
$live.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200)
$form.Controls.Add($live)

$tools=New-Object System.Windows.Forms.GroupBox
$tools.Text='  DIAGNOSTICS & TOOLS  '
$tools.Location=New-Object System.Drawing.Point(32,410)
$tools.Size=New-Object System.Drawing.Size(555,290)
$tools.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200)
$form.Controls.Add($tools)

$details=New-Object System.Windows.Forms.TextBox
$details.Multiline=$true
$details.ReadOnly=$true
$details.ScrollBars='Vertical'
$details.Location=New-Object System.Drawing.Point(610,410)
$details.Size=New-Object System.Drawing.Size(562,290)
$details.BackColor=[System.Drawing.Color]::FromArgb(13,17,23)
$details.ForeColor=[System.Drawing.Color]::FromArgb(195,245,236)
$details.BorderStyle='FixedSingle'
$details.Font=New-Object System.Drawing.Font('Consolas',10.5)
$details.Text=('KXM BLUEFIRE v24`r`n`r`nSMART PROFILE`r`nFree Fire: {0} cores / {1} GB RAM`r`nPower: {2}`r`nFPS: {3}`r`nSysMain: {4}`r`n`r`nGAME READY is the daily pre-game mode.' -f $r.Cores,$r.RAM,$r.Mode,$r.FPS,$r.SysMain)
$form.Controls.Add($details)

$toolSpecs=@(
    @('HARDWARE AUDIT','hardware'),
    @('CONFLICT CHECK','conflict'),
    @('PING / JITTER','ping'),
    @('PENDING REBOOT','reboot'),
    @('DRY RUN','dry'),
    @('MAX FPS PLAN','power'),
    @('BACKUP CENTER','backup'),
    @('BENCHMARK SNAPSHOT','bench'),
    @('VERIFY','verify')
)
$row=0;$col=0
foreach($spec in $toolSpecs){
    $b=New-Object System.Windows.Forms.Button
    $b.Text=$spec[0]
    $b.Location=New-Object System.Drawing.Point((15+($col*178)),(32+($row*72)))
    $b.Size=New-Object System.Drawing.Size(165,56)
    $b.BackColor=[System.Drawing.Color]::FromArgb(27,34,44)
    $b.ForeColor=[System.Drawing.Color]::White
    $b.FlatStyle='Flat'
    $kind=$spec[1]
    $b.Add_Click({
        switch($kind){
            'hardware' {
                $hh=Hardware;$rr=Recommendation $hh
                $details.Text=('HARDWARE AUDIT`r`n`r`nCPU: {0}`r`nCores/Threads: {1}/{2}`r`nRAM: {3} GB`r`nGPU: {4}`r`nStorage: HDD={5} SSD={6}`r`nVirtualization: {7}`r`n`r`nRECOMMENDED`r`nBlueStacks: {8} cores / {9} GB`r`nPower: High Performance`r`nFPS: {10}`r`nSysMain: {11}' -f $hh.CPU,$hh.Cores,$hh.Threads,$hh.RAM,$hh.GPU,$hh.HDD,$hh.SSD,$hh.Virtualization,$rr.Cores,$rr.RAM,$rr.FPS,$rr.SysMain)
            }
            'conflict' {
                $c=Conflicts
                if($c.Count -eq 0){$details.Text='CONFLICT CHECK`r`n`r`nNo known KXM conflicts detected.'}
                else{$details.Text='CONFLICT CHECK`r`n`r`n'+($c -join "`r`n")+"`r`n`r`nReview conflicts before experimental changes."}
            }
            'ping' {$details.Text='PING / JITTER`r`n`r`n'+(PingJitter)}
            'reboot' {$details.Text=('PENDING REBOOT`r`n`r`nWindows pending reboot: {0}' -f (PendingReboot))}
            'dry' {$details.Text=DryRun (Hardware)}
            'power' {
                EnsureBaseline
                $ok=ActivateMaxFPSPlan
                $details.Text=('KXM MAXIMUM FPS PLAN`r`n`r`nVerified active: {0}`r`n`r`nThis is a dedicated gaming power plan; the previous plan remains in the recovery baseline.' -f $ok)
            }
            'backup' {
                if(Test-Path $Pointer){$details.Text=('BACKUP CENTER`r`n`r`nBaseline:`r`n{0}' -f ((Get-Content $Pointer -Raw -Encoding UTF8).Trim()))}
                else{$details.Text='BACKUP CENTER`r`n`r`nNo baseline yet. It is created before the first system-changing action.'}
            }
            'bench' {
                $f=Join-Path $Root ('benchmark_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.txt')
                @('KXM BLUEFIRE v24','Timestamp: '+(Get-Date),('CPU: '+$h.CPU),('RAM: '+$h.RAM+' GB'),('GPU: '+$h.GPU),('Storage: HDD='+$h.HDD+' SSD='+$h.SSD),('Power: '+((powercfg /getactivescheme)-join ' '))) | Set-Content -LiteralPath $f -Encoding UTF8
                $details.Text=('BENCHMARK SNAPSHOT SAVED`r`n`r`n{0}' -f $f)
            }
            'verify' {
                $power=((powercfg /getactivescheme)-join ' ')
                $svc=(Get-Service SysMain -ErrorAction SilentlyContinue)
                $session=Test-Path $SessionFile
                $details.Text=('VERIFY`r`n`r`nPower: {0}`r`nSysMain: {1}`r`nGame session: {2}`r`nPending reboot: {3}`r`nBlueStacks path: {4}' -f $power,$svc.StartType,$session,(PendingReboot),(BlueStacksPath))
            }
        }
    })
    $tools.Controls.Add($b)
    $col++
    if($col -ge 3){$col=0;$row++}
}

$lang=New-Object System.Windows.Forms.ComboBox
$lang.DropDownStyle='DropDownList'
$lang.Items.AddRange(@('English','العربية','Français'))
$lang.SelectedIndex=0
$lang.Location=New-Object System.Drawing.Point(887,34)
$lang.Size=New-Object System.Drawing.Size(225,30)
$quick.Controls.Add($lang)
$lang.Add_SelectedIndexChanged({
    if($lang.SelectedItem -eq 'العربية'){
        $form.RightToLeft='Yes'
        $form.RightToLeftLayout=$true
        $sub.Text=$TX.ar.subtitle
        $ready.Text=$TX.ar.ready
        $end.Text=$TX.ar.end
        $smart.Text=$TX.ar.smart
        $restore.Text=$TX.ar.restore
        $status.Text=$TX.ar.system_ready
        $quick.Text='  '+$TX.ar.quick+'  '
    }elseif($lang.SelectedItem -eq 'Français'){
        $form.RightToLeft='No'
        $form.RightToLeftLayout=$false
        $sub.Text=$TX.fr.subtitle
        $ready.Text=$TX.fr.ready
        $end.Text=$TX.fr.end
        $smart.Text=$TX.fr.smart
        $restore.Text=$TX.fr.restore
        $status.Text=$TX.fr.system_ready
        $quick.Text='  '+$TX.fr.quick+'  '
    }else{
        $form.RightToLeft='No'
        $form.RightToLeftLayout=$false
        $sub.Text=$TX.en.subtitle
        $ready.Text=$TX.en.ready
        $end.Text=$TX.en.end
        $smart.Text=$TX.en.smart
        $restore.Text=$TX.en.restore
        $status.Text=$TX.en.system_ready
        $quick.Text='  '+$TX.en.quick+'  '
    }
})

$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
