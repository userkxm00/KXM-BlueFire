# KXM BLUEFIRE v25
# Windows PowerShell 5.1 + WinForms.
# Source is ASCII-only for parser stability. Localized strings are in KXM_LANG.json.

Set-StrictMode -Version 2.0
$ErrorActionPreference = "SilentlyContinue"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Script:Version = "25.0"
$Script:Root = Join-Path $env:ProgramData "KXM\BlueFire"
$Script:BackupRoot = Join-Path $Script:Root "Backups"
$Script:SessionRoot = Join-Path $Script:Root "Sessions"
$Script:CommunityRoot = Join-Path $Script:Root "Community"
$Script:LogRoot = Join-Path $Script:Root "Logs"
$Script:Pointer = Join-Path $Script:Root "CURRENT_BASELINE.txt"
$Script:SessionFile = Join-Path $Script:SessionRoot "ACTIVE_SESSION.xml"
$Script:LastSession = Join-Path $Script:SessionRoot "LAST_SESSION.xml"
$Script:PrefsFile = Join-Path $Script:Root "preferences.json"
$Script:LogFile = Join-Path $Script:LogRoot "KXM.log"
$Script:LangFile = Join-Path $PSScriptRoot "KXM_LANG.json"

foreach($d in @($Script:Root,$Script:BackupRoot,$Script:SessionRoot,$Script:CommunityRoot,$Script:LogRoot)){
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}

$Script:TX = Get-Content -LiteralPath $Script:LangFile -Raw -Encoding UTF8 | ConvertFrom-Json
$Script:Lang = "en"
$Script:Preferences = [ordered]@{Language="en";CommunitySharing=$false;CommunityEndpoint="";Profile="Free Fire"}
if(Test-Path $Script:PrefsFile){
    try { $Script:Preferences = Get-Content $Script:PrefsFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    if($Script:Preferences.Language){$Script:Lang=[string]$Script:Preferences.Language}
}

function Save-Prefs {
    $Script:Preferences | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Script:PrefsFile -Encoding UTF8
}
function T([string]$key) {
    $set = $Script:TX.PSObject.Properties[$Script:Lang].Value
    if($set){
        $p = $set.PSObject.Properties[$key]
        if($p){ return [string]$p.Value }
    }
    return [string]$key
}
function Log([string]$text) {
    Add-Content -LiteralPath $Script:LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$text) -Encoding UTF8
}
function RegSnap([string]$path,[string]$name) {
    $exists=$false;$value=$null;$kind="DWord"
    try {
        $obj=Get-ItemProperty -LiteralPath $path -ErrorAction Stop
        $p=$obj.PSObject.Properties[$name]
        if($p){$exists=$true;$value=$p.Value;if($value -is [string]){$kind="String"}}
    } catch {}
    return [pscustomobject]@{Path=$path;Name=$name;Exists=$exists;Value=$value;Kind=$kind}
}
function RegD([string]$path,[string]$name,[int64]$value) {
    try {
        New-Item -Path $path -Force | Out-Null
        New-ItemProperty -Path $path -Name $name -PropertyType DWord -Value $value -Force | Out-Null
    } catch {}
}
function RegS([string]$path,[string]$name,[string]$value) {
    try {
        New-Item -Path $path -Force | Out-Null
        New-ItemProperty -Path $path -Name $name -PropertyType String -Value $value -Force | Out-Null
    } catch {}
}
function RestoreReg($e) {
    if($e.Exists){
        if($e.Kind -eq "String"){RegS $e.Path $e.Name ([string]$e.Value)}
        else{RegD $e.Path $e.Name ([int64]$e.Value)}
    }else{
        Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name -ErrorAction SilentlyContinue
    }
}
function DiskInfo {
    $hdd=$false;$ssd=$false;$kind="Unknown"
    try {
        foreach($d in @(Get-PhysicalDisk)){
            $m=[string]$d.MediaType
            if($m -match "HDD"){$hdd=$true}
            if($m -match "SSD"){$ssd=$true}
        }
    } catch {}
    if(-not $hdd -and -not $ssd){
        try {
            foreach($d in @(Get-CimInstance Win32_DiskDrive)){
                $m=([string]$d.Model+" "+[string]$d.MediaType+" "+[string]$d.InterfaceType)
                if($m -match "SSD|Solid State|NVMe"){$ssd=$true}
                elseif($m -match "HDD|Hard Disk"){$hdd=$true}
            }
        } catch {}
    }
    if($ssd){$kind="SSD"}elseif($hdd){$kind="HDD"}
    return [pscustomobject]@{HDD=$hdd;SSD=$ssd;Kind=$kind}
}
function Hardware {
    $cpu=Get-CimInstance Win32_Processor|Select-Object -First 1
    $cs=Get-CimInstance Win32_ComputerSystem
    $gpus=@(Get-CimInstance Win32_VideoController)
    $d=DiskInfo
    $ram=if($cs){[math]::Round($cs.TotalPhysicalMemory/1GB,1)}else{0}
    $gpu="Unknown"
    if($gpus.Count -gt 0){$gpu=($gpus|ForEach-Object{[string]$_.Name}) -join " | "}
    return [pscustomobject]@{
        CPU=if($cpu){[string]$cpu.Name}else{"Unknown"}
        Cores=if($cpu){[int]$cpu.NumberOfCores}else{0}
        Threads=if($cpu){[int]$cpu.NumberOfLogicalProcessors}else{0}
        RAM=$ram;GPU=$gpu;HDD=$d.HDD;SSD=$d.SSD;Storage=$d.Kind
        Virtualization=if($cpu){[bool]$cpu.VirtualizationFirmwareEnabled}else{$false}
    }
}
function DriverHealth {
    $items=@()
    foreach($d in @(Get-CimInstance Win32_PnPSignedDriver|Where-Object{$_.DeviceClass -eq "DISPLAY"})){
        $items += ,([pscustomobject]@{Name=[string]$d.DeviceName;Version=[string]$d.DriverVersion;Date=[string]$d.DriverDate;Provider=[string]$d.DriverProviderName})
    }
    return $items
}
function ThermalStatus {
    $read=@()
    try {
        foreach($z in @(Get-CimInstance -Namespace "root\wmi" -ClassName MSAcpi_ThermalZoneTemperature)){
            if($z.CurrentTemperature -gt 0){
                $c=[math]::Round(($z.CurrentTemperature/10)-273.15,1)
                $read += ,([pscustomobject]@{C=$c})
            }
        }
    } catch {}
    if($read.Count -eq 0){return [pscustomobject]@{Status="UNKNOWN";MaxC=$null}}
    $max=($read|Measure-Object C -Maximum).Maximum
    $s="SAFE"
    if($max -ge 85){$s="WARNING"}
    if($max -ge 95){$s="THROTTLING RISK"}
    return [pscustomobject]@{Status=$s;MaxC=$max}
}
function Get-RefreshRate {
    try {
        $v=Get-CimInstance Win32_VideoController|Select-Object -First 1
        if($v.CurrentRefreshRate){return [int]$v.CurrentRefreshRate}
    } catch {}
    return 0
}
function PendingReboot {
    return ((Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") -or (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"))
}
function UpdateDrift {
    $mm="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    $c=@()
    $sr=(Get-ItemProperty $mm -ErrorAction SilentlyContinue).SystemResponsiveness
    $nt=(Get-ItemProperty $mm -ErrorAction SilentlyContinue).NetworkThrottlingIndex
    $gm=(Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -ErrorAction SilentlyContinue).AutoGameModeEnabled
    $c += ,([pscustomobject]@{Name="SystemResponsiveness";Actual=$sr;Drift=([string]$sr -ne "0")})
    $c += ,([pscustomobject]@{Name="NetworkThrottlingIndex";Actual=$nt;Drift=($null -ne $nt -and [int64]$nt -ne 4294967295)})
    $c += ,([pscustomobject]@{Name="GameMode";Actual=$gm;Drift=([string]$gm -ne "1")})
    return $c
}
function FindBlueStacks {
    foreach($p in @(
        "$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe",
        "$env:ProgramFiles\BlueStacks_nxt5\HD-Player.exe",
        "${env:ProgramFiles(x86)}\BlueStacks_nxt\HD-Player.exe",
        "${env:ProgramFiles(x86)}\BlueStacks_nxt5\HD-Player.exe"
    )){if($p -and (Test-Path $p)){return $p}}
    return $null
}
function BlueStacksVersion {
    $p=FindBlueStacks
    if(-not $p){return $null}
    try{return (Get-Item $p).VersionInfo.ProductVersion}catch{return $null}
}
function Recommendation($h) {
    $cores=4;$ram=4
    if($h.Threads -lt 4){$cores=2}
    if($h.RAM -lt 8){$ram=2}
    return [pscustomobject]@{Name="Free Fire";Cores=$cores;RAM=$ram;Power="High Performance";FPSTarget=120;FPSCeiling=240;SysMain=if($h.HDD -or $h.RAM -le 8){"KEEP AUTO"}else{"OPTIONAL"}}
}
function Baseline {
    if(Test-Path $Script:Pointer){
        $d=(Get-Content $Script:Pointer -Raw -Encoding UTF8).Trim()
        if($d -and (Test-Path (Join-Path $d "Baseline.xml"))){return $d}
    }
    $d=Join-Path $Script:BackupRoot (Get-Date -Format "yyyyMMdd_HHmmss")
    New-Item -ItemType Directory -Path $d -Force|Out-Null
    $st=[ordered]@{Created=(Get-Date).ToString("o");Power=((powercfg /getactivescheme)-join " ");Registry=New-Object System.Collections.ArrayList;Services=New-Object System.Collections.ArrayList}
    foreach($x in @(
        @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile","SystemResponsiveness"),
        @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile","NetworkThrottlingIndex"),
        @("HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl","Win32PrioritySeparation"),
        @("HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling","PowerThrottlingOff"),
        @("HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers","HwSchMode"),
        @("HKLM:\SOFTWARE\Microsoft\Windows\Dwm","OverlayTestMode"),
        @("HKCU:\Software\Microsoft\GameBar","AutoGameModeEnabled"),
        @("HKCU:\System\GameConfigStore","GameDVR_Enabled"),
        @("HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR","AppCaptureEnabled")
    )){$st.Registry.Add((RegSnap $x[0] $x[1]))}
    try{$svc=Get-CimInstance Win32_Service -Filter "Name='SysMain'";$st.Services.Add([pscustomobject]@{Name="SysMain";Start=$svc.StartMode;State=(Get-Service SysMain).Status})|Out-Null}catch{}
    $st|Export-Clixml (Join-Path $d "Baseline.xml")
    powercfg /list|Out-File (Join-Path $d "PowerPlans.txt") -Encoding UTF8
    bcdedit /enum all|Out-File (Join-Path $d "BCD.txt") -Encoding UTF8
    Set-Content $Script:Pointer $d -Encoding UTF8
    Log ("Baseline created "+$d)
    return $d
}
function EnsureBaseline{$null=Baseline}
function CleanSafe {
    foreach($d in @($env:TEMP,(Join-Path $env:LOCALAPPDATA "Temp"),"C:\Windows\Temp")){
        if(Test-Path $d){Remove-Item (Join-Path $d "*") -Recurse -Force -ErrorAction SilentlyContinue}
    }
    ipconfig /flushdns|Out-Null
}
function MaxFPSPlan {
    $marker=Join-Path $Script:Root "MAX_FPS_GUID.txt"
    if(Test-Path $marker){$g=(Get-Content $marker -Raw).Trim();if($g -and (powercfg /list|Select-String $g)){return $g}}
    $src=(powercfg /getactivescheme|Select-String -Pattern "([0-9a-fA-F-]{36})").Matches.Groups[1].Value
    if(-not $src){return $null}
    $g=(powercfg /duplicatescheme $src 2>&1|Select-String -Pattern "([0-9a-fA-F-]{36})").Matches.Groups[1].Value
    if(-not $g){return $null}
    powercfg /changename $g "KXM Maximum FPS" "KXM gaming session plan"|Out-Null
    powercfg /setacvalueindex $g SUB_PROCESSOR PROCTHROTTLEMIN 100|Out-Null
    powercfg /setacvalueindex $g SUB_PROCESSOR PROCTHROTTLEMAX 100|Out-Null
    powercfg /setacvalueindex $g SUB_USB USBSELECTIVE 0|Out-Null
    Set-Content $marker $g -Encoding ASCII
    return $g
}
function ActivateMaxFPS {
    $g=MaxFPSPlan
    if($g){powercfg /setactive $g|Out-Null;return (((powercfg /getactivescheme)-join " ")-match [regex]::Escape($g))}
    return $false
}
function StartSession {
    EnsureBaseline
    if(Test-Path $Script:SessionFile){return "GAME SESSION ALREADY ACTIVE."}
    $p=Get-Process -Name HD-Player -ErrorAction SilentlyContinue|Select-Object -First 1
    $st=[ordered]@{Started=(Get-Date).ToString("o");Power=((powercfg /getactivescheme)-join " ");Priority=if($p){[string]$p.PriorityClass}else{"NotRunning"}}
    $st|Export-Clixml $Script:SessionFile
    CleanSafe
    $plan=ActivateMaxFPS
    if($p){try{$p.PriorityClass="AboveNormal"}catch{}}
    Log "GAME READY session started"
    return ("GAME READY ACTIVE.`r`n`r`nTemp cleanup: OK`r`nMaximum FPS plan verified: {0}`r`nBlueStacks running: {1}"-f$plan,([bool]$p))
}
function EndSession {
    if(-not(Test-Path $Script:SessionFile)){return "NO ACTIVE SESSION."}
    $s=Import-Clixml $Script:SessionFile
    if($s.Power -match "([0-9a-fA-F-]{36})"){powercfg /setactive $Matches[1]|Out-Null}
    $s|Export-Clixml $Script:LastSession
    Remove-Item $Script:SessionFile -Force
    Log "GAME READY session ended"
    return "SESSION ENDED.`r`nOriginal power plan restored."
}
function UndoLastSession {
    if(-not(Test-Path $Script:LastSession)){return "NO LAST SESSION SNAPSHOT."}
    $s=Import-Clixml $Script:LastSession
    if($s.Power -match "([0-9a-fA-F-]{36})"){powercfg /setactive $Matches[1]|Out-Null}
    Remove-Item $Script:LastSession -Force
    Log "Last session undone"
    return "LAST SESSION UNDONE.`r`nPrevious power plan restored."
}
function ApplySafeProfile($h,$p) {
    EnsureBaseline
    powercfg /setactive SCHEME_MIN|Out-Null
    RegD "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    RegD "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1
    RegD "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    RegD "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    $mm="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile";$g="$mm\Tasks\Games"
    RegD $mm "SystemResponsiveness" 0
    RegD $mm "NetworkThrottlingIndex" 4294967295
    RegD $g "GPU Priority" 8
    RegD $g "Priority" 6
    RegD "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38
    RegD "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1
    if($h.HDD -or $h.RAM -le 8){Set-Service SysMain -StartupType Automatic;Start-Service SysMain}
    $bs=FindBlueStacks
    if($bs){RegS "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" $bs "GpuPreference=2;"}
    Log "Safe profile applied"
}
function Preview($h,$p) {
    return @(
        "KXM v25 DRY RUN","",
        "+ High Performance gaming power plan",
        "+ Game Mode / capture policy",
        "+ MMCSS gaming policy",
        "+ Power throttling policy",
        "+ BlueStacks GPU preference when detected",
        "+ SysMain kept AUTO on HDD / <=8 GB","",
        ("BlueStacks target: {0} CPU cores / {1} GB"-f$p.Cores,$p.RAM),
        ("FPS target: {0} | Optional ceiling: {1}"-f$p.FPSTarget,$p.FPSCeiling),"",
        "- No pagefile disable","- No forced HPET","- No blind MSI mode","- No Defender removal","- No Edge/WebView removal","- No aggressive service purge"
    )-join "`r`n"
}
function CollectCommunityEvent([string]$type,[hashtable]$data) {
    if(-not[bool]$Script:Preferences.CommunitySharing){return}
    $h=Hardware;$gv="Other"
    if($h.GPU-match"NVIDIA"){$gv="NVIDIA"}elseif($h.GPU-match"AMD|Radeon"){$gv="AMD"}elseif($h.GPU-match"Intel"){$gv="Intel"}
    $o=[ordered]@{schema=1;event=$type;kxm_version=$Script:Version;timestamp=(Get-Date).ToUniversalTime().ToString("o");os_build=[string](Get-CimInstance Win32_OperatingSystem).BuildNumber;hardware_class=[ordered]@{cpu_threads=$h.Threads;ram_gb=[math]::Round($h.RAM,0);storage=$h.Storage;gpu_vendor=$gv};data=$data}
    $f=Join-Path $Script:CommunityRoot "events.jsonl";($o|ConvertTo-Json -Compress -Depth 8)|Add-Content -LiteralPath $f -Encoding UTF8
    $ep=[string]$Script:Preferences.CommunityEndpoint
    if($ep){try{Invoke-RestMethod -Uri $ep -Method Post -ContentType "application/json" -Body ($o|ConvertTo-Json -Depth 8) -TimeoutSec 8|Out-Null}catch{Log "Community endpoint send failed"}}
}
function CommunityInsights {
    $f=Join-Path $Script:CommunityRoot "events.jsonl"
    if(-not(Test-Path $f)){return "COMMUNITY INSIGHTS`r`n`r`nNo local anonymized evidence yet.`r`n`r`nOnline sending requires an explicit endpoint."}
    $rows=@(Get-Content $f -Encoding UTF8|ForEach-Object{try{$_|ConvertFrom-Json}catch{}})
    $n=$rows.Count;$ap=@($rows|Where-Object{$_.event-eq"profile_applied"}).Count;$undo=@($rows|Where-Object{$_.event-eq"session_undo"-or$_.event-eq"restore"}).Count
    $rate=if($ap){[math]::Round((1-($undo/[double]$ap))*100,1)}else{0}
    return ("COMMUNITY INSIGHTS`r`n`r`nEvents: {0}`r`nProfiles applied: {1}`r`nUndo/restore: {2}`r`nKeep-rate signal: {3}%`r`n`r`nDescriptive only; not proof of FPS improvement."-f$n,$ap,$undo,$rate)
}
function SetCommunitySharing {
    $cur=[bool]$Script:Preferences.CommunitySharing
    $msg=if($cur){"Disable anonymous community data sharing?"}else{"Enable anonymous community data sharing? No personal files, accounts, passwords or serials are collected."}
    $a=[System.Windows.Forms.MessageBox]::Show($msg,"KXM // Community Data",4)
    if($a-eq6){$Script:Preferences.CommunitySharing=(-not$cur);Save-Prefs}
}
function ExportProfile($p) {
    $d=Join-Path $Script:Root "ExportedProfiles";New-Item -ItemType Directory -Path $d -Force|Out-Null
    $f=Join-Path $d ("KXM_Profile_"+(Get-Date -Format "yyyyMMdd_HHmmss")+".json")
    [ordered]@{schema=1;version=$Script:Version;created=(Get-Date).ToString("o");profile=$p.Name;bluestacks_cpu=$p.Cores;bluestacks_ram_gb=$p.RAM;power=$p.Power;fps_target=$p.FPSTarget;fps_ceiling=$p.FPSCeiling;sysmain_policy=$p.SysMain}|ConvertTo-Json -Depth 6|Set-Content $f -Encoding UTF8
    return $f
}
# GUI
$form=New-Object System.Windows.Forms.Form
$form.Text="KXM // BLUEFIRE v25";$form.Size=New-Object System.Drawing.Size(1260,840);$form.StartPosition="CenterScreen";$form.BackColor=[System.Drawing.Color]::FromArgb(8,11,16);$form.ForeColor=[System.Drawing.Color]::White;$form.Font=New-Object System.Drawing.Font("Segoe UI",10);$form.FormBorderStyle="FixedSingle";$form.MaximizeBox=$false
$h=Hardware;$p=Recommendation $h
$header=New-Object System.Windows.Forms.Label;$header.Text="KXM // BLUEFIRE";$header.Location=New-Object System.Drawing.Point(36,22);$header.Size=New-Object System.Drawing.Size(700,48);$header.Font=New-Object System.Drawing.Font("Segoe UI Semibold",25);$header.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200);$form.Controls.Add($header)
$sub=New-Object System.Windows.Forms.Label;$sub.Text=T"subtitle";$sub.Location=New-Object System.Drawing.Point(40,70);$sub.Size=New-Object System.Drawing.Size(850,28);$sub.ForeColor=[System.Drawing.Color]::Silver;$form.Controls.Add($sub)
$status=New-Object System.Windows.Forms.Label;$status.Text=T"system_ready";$status.Location=New-Object System.Drawing.Point(900,28);$status.Size=New-Object System.Drawing.Size(300,42);$status.TextAlign="MiddleRight";$status.Font=New-Object System.Drawing.Font("Segoe UI Semibold",12);$status.ForeColor=[System.Drawing.Color]::FromArgb(120,255,175);$form.Controls.Add($status)
$dash=New-Object System.Windows.Forms.Panel;$dash.Location=New-Object System.Drawing.Point(32,112);$dash.Size=New-Object System.Drawing.Size(1160,112);$dash.BackColor=[System.Drawing.Color]::FromArgb(18,23,31);$form.Controls.Add($dash)
$cards=@(@("CPU",$h.CPU),@("RAM","$($h.RAM) GB"),@("GPU",$h.GPU),@("STORAGE",$h.Storage),@("FREE FIRE","$($p.Cores) C / $($p.RAM) GB"));$x=14
foreach($c in$cards){$cp=New-Object System.Windows.Forms.Panel;$cp.Location=New-Object System.Drawing.Point($x,14);$cp.Size=New-Object System.Drawing.Size(215,84);$cp.BackColor=[System.Drawing.Color]::FromArgb(25,31,41);$cl=New-Object System.Windows.Forms.Label;$cl.Text="$($c[0])`r`n$($c[1])";$cl.Dock="Fill";$cl.TextAlign="MiddleCenter";$cl.ForeColor=[System.Drawing.Color]::White;$cp.Controls.Add($cl);$dash.Controls.Add($cp);$x+=225}
$quick=New-Object System.Windows.Forms.GroupBox;$quick.Text="  $(T"quick")  ";$quick.Location=New-Object System.Drawing.Point(32,242);$quick.Size=New-Object System.Drawing.Size(1160,122);$quick.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200);$form.Controls.Add($quick)
function Btn([string]$text,[int]$x,[int]$w,[scriptblock]$action,[System.Drawing.Color]$bg){$b=New-Object System.Windows.Forms.Button;$b.Text=$text;$b.Location=New-Object System.Drawing.Point($x,30);$b.Size=New-Object System.Drawing.Size($w,68);$b.Font=New-Object System.Drawing.Font("Segoe UI Semibold",12);$b.BackColor=$bg;$b.ForeColor=[System.Drawing.Color]::White;$b.FlatStyle="Flat";$b.Add_Click($action);$quick.Controls.Add($b);return$b}
$ready=Btn (T"ready") 18 235 {$details.Text=StartSession;$status.Text="● GAME SESSION ACTIVE"} ([System.Drawing.Color]::FromArgb(0,126,112))
$end=Btn (T"end") 268 205 {$details.Text=EndSession;$status.Text=T"system_ready"} ([System.Drawing.Color]::FromArgb(58,47,44))
$smart=Btn (T"smart") 486 220 {$ans=[System.Windows.Forms.MessageBox]::Show((Preview $h $p),"KXM // SMART OPTIMIZE",4);if($ans-eq6){ApplySafeProfile $h $p;CollectCommunityEvent "profile_applied" @{profile=$p.Name};$details.Text=("SMART PROFILE APPLIED`r`n`r`nBlueStacks: {0} cores / {1} GB`r`nPower: {2}`r`nFPS: {3} / {4}`r`nSysMain: {5}"-f$p.Cores,$p.RAM,$p.Power,$p.FPSTarget,$p.FPSCeiling,$p.SysMain);$status.Text="● OPTIMIZED"}} ([System.Drawing.Color]::FromArgb(34,44,58))
$restore=Btn (T"restore") 721 220 {$ans=[System.Windows.Forms.MessageBox]::Show("Restore the original state captured before KXM?","KXM // RESTORE",4,48);if($ans-eq6){if(RestoreBaseline){CollectCommunityEvent "restore" @{};$details.Text="RESTORE COMPLETE.`r`n`r`nOriginal captured settings restored.`r`nReboot before testing.";$status.Text="● RESTORED"}}} ([System.Drawing.Color]::FromArgb(73,50,47))
$details=New-Object System.Windows.Forms.TextBox;$details.Multiline=$true;$details.ReadOnly=$true;$details.ScrollBars="Vertical";$details.Location=New-Object System.Drawing.Point(625,394);$details.Size=New-Object System.Drawing.Size(567,306);$details.BackColor=[System.Drawing.Color]::FromArgb(13,17,23);$details.ForeColor=[System.Drawing.Color]::FromArgb(195,245,236);$details.Font=New-Object System.Drawing.Font("Consolas",10.5);$details.Text=("KXM BLUEFIRE v25`r`n`r`nPROFILE: {0}`r`nBlueStacks: {1} CPU / {2} GB`r`nPower: {3}`r`nFPS: {4} target / {5} ceiling`r`nSysMain: {6}`r`n`r`nDriver records: {7}`r`nThermal: {8}`r`nRefresh: {9} Hz`r`nPending reboot: {10}"-f$p.Name,$p.Cores,$p.RAM,$p.Power,$p.FPSTarget,$p.FPSCeiling,$p.SysMain,(DriverHealth).Count,(ThermalStatus).Status,(Get-RefreshRate),(PendingReboot));$form.Controls.Add($details)
$box=New-Object System.Windows.Forms.GroupBox;$box.Text="  $(T"diag")  ";$box.Location=New-Object System.Drawing.Point(32,394);$box.Size=New-Object System.Drawing.Size(570,310);$box.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200);$form.Controls.Add($box)
$spec=@(@("tool_hardware","h"),@("tool_driver","d"),@("tool_thermal","t"),@("tool_conflict","c"),@("tool_update","u"),@("tool_latency","l"),@("tool_bench","b"),@("tool_profile","p"),@("tool_community","i"),@("tool_verify","v"),@("tool_dry","y"),@("tool_backup","k"));$row=0;$col=0
foreach($s0 in$spec){$b0=New-Object System.Windows.Forms.Button;$b0.Text=T$s0[0];$b0.Location=New-Object System.Drawing.Point((14+($col*180)),(32+($row*66)));$b0.Size=New-Object System.Drawing.Size(168,52);$b0.BackColor=[System.Drawing.Color]::FromArgb(27,34,44);$b0.ForeColor=[System.Drawing.Color]::White;$b0.FlatStyle="Flat";$kind=$s0[1]
    $b0.Add_Click({
        switch($kind){
            "h"{$hh=Hardware;$rr=Recommendation $hh;$details.Text=("HARDWARE`r`n`r`nCPU: {0}`r`nCores/Threads: {1}/{2}`r`nRAM: {3} GB`r`nGPU: {4}`r`nStorage: {5}`r`nVirtualization: {6}`r`nRefresh: {7} Hz`r`n`r`nFREE FIRE`r`n{8} cores / {9} GB`r`n120 FPS target / 240 ceiling`r`nSysMain: {10}"-f$hh.CPU,$hh.Cores,$hh.Threads,$hh.RAM,$hh.GPU,$hh.Storage,$hh.Virtualization,(Get-RefreshRate),$rr.Cores,$rr.RAM,$rr.SysMain)}
            "d"{$ds=DriverHealth;if($ds.Count-eq0){$details.Text="DRIVER HEALTH`r`n`r`nNo display driver details available."}else{$details.Text="DRIVER HEALTH`r`n`r`n"+(($ds|ForEach-Object{"$($_.Name)`r`nProvider: $($_.Provider)`r`nVersion: $($_.Version)`r`nDate: $($_.Date)`r`n"})-join"`r`n")}}
            "t"{$x=ThermalStatus;if($x.Status-eq"UNKNOWN"){$details.Text="THERMAL GUARD`r`n`r`nTelemetry unavailable; KXM does not guess temperature."}else{$details.Text=("THERMAL GUARD`r`n`r`nStatus: {0}`r`nMaximum reading: {1} C"-f$x.Status,$x.MaxC)}}
            "c"{$q=@();if(Get-Process Discord-EA SilentlyContinue){$q+=,('Discord running')};if(Get-Process RivaTunerStatisticsServer-EA SilentlyContinue){$q+=,('RTSS running')};$v=Get-Service vmms-EA SilentlyContinue;if($v-and$v.Status-eq"Running"){$q+=,('Hyper-V running')};$details.Text="CONFLICT CHECK`r`n`r`n"+$(if($q.Count){$q-join"`r`n"}else{"No known conflicts."})}
            "u"{$u=UpdateDrift;$details.Text="UPDATE RESILIENCE`r`n`r`nPending reboot: $(PendingReboot)`r`n"+(($u|ForEach-Object{"$($_.Name): actual=$($_.Actual) drift=$($_.Drift)"})-join"`r`n")}
            "l"{$details.Text="NETWORK LATENCY`r`n`r`nUse the gateway plus public endpoints; KXM records results only when explicitly collected."}
            "b"{$details.Text=("FRAME-TIME BENCH`r`n`r`nPresentMon detected: {0}`r`n`r`nKXM records hardware/thermal snapshots but does not invent FPS numbers."-f[bool](Get-Command presentmon.exe-EA SilentlyContinue))}
            "p"{$f=ExportProfile(Recommendation(Hardware));$details.Text="PROFILE EXPORTED`r`n`r`n$f"}
            "i"{$details.Text=CommunityInsights}
            "v"{$details.Text=("VERIFY STATE`r`n`r`nBaseline: {0}`r`nSession: {1}`r`nReboot: {2}`r`nThermal: {3}`r`nDriver records: {4}`r`nBlueStacks: {5}`r`nBlueStacks version: {6}"-f(Test-Path $Script:Pointer),(Test-Path $Script:SessionFile),(PendingReboot),(ThermalStatus).Status,(DriverHealth).Count,(FindBlueStacks),(BlueStacksVersion))}
            "y"{$details.Text=Preview(Hardware)(Recommendation(Hardware))}
            "k"{if(Test-Path$Script:Pointer){$details.Text="BACKUP CENTER`r`n`r`nBaseline:`r`n$((Get-Content $Script:Pointer -Raw -Encoding UTF8).Trim())`r`n`r`nLast session: $(Test-Path $Script:LastSession)"}else{$details.Text="BACKUP CENTER`r`n`r`nNo baseline yet."}}
        }
    })
    $box.Controls.Add($b0);$col++;if($col-ge3){$col=0;$row++}
}
$share=New-Object Windows.Forms.Button;$share.Text=if($Script:Preferences.CommunitySharing){T"share_on"}else{T"share_off"};$share.Location=New-Object Drawing.Point(36,732);$share.Size=New-Object Drawing.Size(260,34);$share.BackColor=[Drawing.Color]::FromArgb(20,80,74);$share.ForeColor=[Drawing.Color]::White;$share.FlatStyle="Flat";$share.Add_Click({SetCommunitySharing;$share.Text=if($Script:Preferences.CommunitySharing){T"share_on"}else{T"share_off"}});$form.Controls.Add($share)
$undo=New-Object Windows.Forms.Button;$undo.Text="UNDO LAST SESSION";$undo.Location=New-Object Drawing.Point(310,732);$undo.Size=New-Object Drawing.Size(220,34);$undo.FlatStyle="Flat";$undo.Add_Click({$details.Text=UndoLastSession;CollectCommunityEvent "session_undo" @{}});$form.Controls.Add($undo)
$lang=New-Object Windows.Forms.ComboBox;$lang.DropDownStyle="DropDownList";$lang.Items.AddRange(@("English","العربية","Français"));$lang.Location=New-Object Drawing.Point(960,732);$lang.Size=New-Object Drawing.Size(230,30);$lang.SelectedIndex=if($Script:Lang-eq"ar"){1}elseif($Script:Lang-eq"fr"){2}else{0};$form.Controls.Add($lang)
$lang.Add_SelectedIndexChanged({$new=if($lang.SelectedIndex-eq1){"ar"}elseif($lang.SelectedIndex-eq2){"fr"}else{"en"};$Script:Lang=$new;$Script:Preferences.Language=$new;Save-Prefs;$sub.Text=T"subtitle";$status.Text=T"system_ready";$quick.Text="  "+(T"quick")+"  ";$share.Text=if($Script:Preferences.CommunitySharing){T"share_on"}else{T"share_off"};$ready.Text=T"ready";$end.Text=T"end";$smart.Text=T"smart";$restore.Text=T"restore";$form.RightToLeft=if($new-eq"ar"){"Yes"}else{"No"};$form.RightToLeftLayout=($new-eq"ar")})
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
