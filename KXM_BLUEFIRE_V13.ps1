# KXM BLUEFIRE v13
# Windows PowerShell 5.1 compatible. Recovery-first.

Set-StrictMode -Version 2.0
$ErrorActionPreference = "SilentlyContinue"

$Script:Version = "13.0"
$Script:Author = "KXM"
$Script:License = "MIT"
$Script:ProjectURL = "https://github.com/userkxm00/KXM-BlueFire"
$Script:Root = Join-Path $env:ProgramData "KXM\BlueFire"
$Script:BackupRoot = Join-Path $Script:Root "Backups"
$Script:LogRoot = Join-Path $Script:Root "Logs"
$Script:BenchRoot = Join-Path $Script:Root "Benchmarks"
$Script:BaselinePointer = Join-Path $Script:Root "CURRENT_BASELINE.txt"
$Script:LanguageFile = Join-Path $Script:Root "language.txt"
$Script:LogFile = Join-Path $Script:LogRoot "KXM.log"
$Script:ConfigFile = Join-Path $PSScriptRoot "KXM_CONFIG.ini"

New-Item -ItemType Directory -Path $Script:Root -Force | Out-Null
New-Item -ItemType Directory -Path $Script:BackupRoot -Force | Out-Null
New-Item -ItemType Directory -Path $Script:LogRoot -Force | Out-Null
New-Item -ItemType Directory -Path $Script:BenchRoot -Force | Out-Null

if (Test-Path $Script:ConfigFile) {
    foreach ($line in (Get-Content -LiteralPath $Script:ConfigFile -Encoding UTF8)) {
        if ($line -match '^AUTHOR=(.*)$') { $Script:Author = $Matches[1] }
        elseif ($line -match '^VERSION=(.*)$') { $Script:Version = $Matches[1] }
        elseif ($line -match '^PROJECT_URL=(.*)$') { $Script:ProjectURL = $Matches[1] }
        elseif ($line -match '^LICENSE=(.*)$') { $Script:License = $Matches[1] }
    }
}

$Script:Lang = "EN"
if (Test-Path $Script:LanguageFile) {
    $saved = (Get-Content -LiteralPath $Script:LanguageFile -Raw -Encoding UTF8).Trim().ToUpperInvariant()
    if ($saved -eq "AR") { $Script:Lang = "AR" }
    elseif ($saved -eq "FR") { $Script:Lang = "FR" }
}
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch {}

function T {
    param([string]$EN,[string]$AR,[string]$FR)
    if ($Script:Lang -eq "AR") { return $AR }
    if ($Script:Lang -eq "FR") { return $FR }
    return $EN
}
function P { param([string]$Text,[ConsoleColor]$Color=[ConsoleColor]::Gray); Write-Host $Text -ForegroundColor $Color }
function Pause-KXM { P (T "Press any key to continue..." "اضغط أي مفتاح للمتابعة..." "Appuyez sur une touche...") DarkGray; try { $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null } catch {} }
function Ask { param([string]$Question); while ($true) { P $Question Yellow; $a=Read-Host "Y/N"; if ($a -match '^[Yy]$') { return $true }; if ($a -match '^[Nn]$') { return $false } } }
function Log { param([string]$Text); try { Add-Content -LiteralPath $Script:LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$Text) -Encoding UTF8 } catch {} }
function RegDword { param([string]$Path,[string]$Name,[int64]$Value); try { New-Item -Path $Path -Force | Out-Null; New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null } catch {} }
function RegString { param([string]$Path,[string]$Name,[string]$Value); try { New-Item -Path $Path -Force | Out-Null; New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $Value -Force | Out-Null } catch {} }
function Header { param([string]$EN,[string]$AR,[string]$FR); Clear-Host; P ""; P "=======================================================================" Cyan; P "                         KXM // BLUEFIRE" White; P (T $EN $AR $FR) Green; P "=======================================================================" Cyan; P "" }

function Get-Hardware {
    $cs=Get-CimInstance Win32_ComputerSystem
    $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1
    $os=Get-CimInstance Win32_OperatingSystem
    $gpus=@(Get-CimInstance Win32_VideoController)
    $disks=@(Get-PhysicalDisk)
    $ram=0; if ($cs) { $ram=[math]::Round($cs.TotalPhysicalMemory/1GB,1) }
    $cores=0; $threads=0; $name="Unknown"; $virt=$false
    if ($cpu) { $name=[string]$cpu.Name; $cores=[int]$cpu.NumberOfCores; $threads=[int]$cpu.NumberOfLogicalProcessors; $virt=[bool]$cpu.VirtualizationFirmwareEnabled }
    $gpu=""; $modern=$false
    foreach ($g in $gpus) { if ($gpu -ne "") { $gpu += " | " }; $gpu += [string]$g.Name; if ([string]$g.Name -match "RTX|GTX|Radeon RX|Arc") { $modern=$true } }
    $hdd=$false; $ssd=$false
    foreach ($d in $disks) { if ([string]$d.MediaType -eq "HDD") { $hdd=$true }; if ([string]$d.MediaType -eq "SSD") { $ssd=$true } }
    $win="Unknown"; if ($os) { $win="{0} Build {1}" -f $os.Caption,$os.BuildNumber }
    return [pscustomobject]@{ CPU=$name;Cores=$cores;Threads=$threads;RAMGB=$ram;GPU=$gpu;Virtualization=$virt;HasHDD=$hdd;HasSSD=$ssd;ModernDiscrete=$modern;Windows=$win }
}
function Get-Recommendation { param($H); $c=2; if ($H.Threads -ge 4) { $c=4 }; if ($H.Threads -ge 12) { $c=6 }; $r=2; if ($H.RAMGB -ge 8) { $r=3 }; if ($H.RAMGB -ge 16) { $r=4 }; if ($H.RAMGB -ge 32) { $r=6 }; $profile="STANDARD"; if ($H.Threads -ge 8 -and $H.RAMGB -ge 16 -and $H.ModernDiscrete) { $profile="PERFORMANCE" }; $sys="OPTIONAL"; if ($H.HasHDD -or $H.RAMGB -le 8) { $sys="KEEP AUTO" }; $hags="DEFAULT"; if ($H.ModernDiscrete) { $hags="TEST ON vs DEFAULT" }; return [pscustomobject]@{Profile=$profile;BlueStacksCores=$c;BlueStacksRAM=$r;SysMain=$sys;HAGS=$hags} }
function Show-Hardware { param($H,$R); P "Detected hardware" Cyan; P ("CPU            : {0}" -f $H.CPU) White; P ("Cores/Threads  : {0}/{1}" -f $H.Cores,$H.Threads) White; P ("RAM            : {0} GB" -f $H.RAMGB) White; P ("GPU            : {0}" -f $H.GPU) White; P ("Virtualization : {0}" -f $H.Virtualization) White; P ("Storage        : HDD={0} | SSD={1}" -f $H.HasHDD,$H.HasSSD) White; P ("Windows        : {0}" -f $H.Windows) White; P ""; P "KXM SMART RECOMMENDATION" Green; P ("Profile       : {0}" -f $R.Profile) Yellow; P ("BlueStacks    : {0} CPU cores | {1} GB RAM" -f $R.BlueStacksCores,$R.BlueStacksRAM) White; P ("HAGS          : {0}" -f $R.HAGS) White; P ("SysMain       : {0}" -f $R.SysMain) White; P "Pagefile      : Windows managed" White; P "Memory Comp.  : keep enabled" White }

function RegSnapshot { param([string]$Path,[string]$Name); $exists=$false;$value=$null;$kind="DWord";try{$item=Get-ItemProperty -LiteralPath $Path -ErrorAction Stop;$prop=$item.PSObject.Properties[$Name];if($null -ne $prop){$exists=$true;$value=$prop.Value;if($value -is [string]){$kind="String"}}}catch{};return [pscustomobject]@{Path=$Path;Name=$Name;Exists=$exists;Value=$value;Kind=$kind} }
function RestoreReg { param($E); if($E.Exists){if($E.Kind -eq "String"){RegString $E.Path $E.Name ([string]$E.Value)}else{RegDword $E.Path $E.Name ([int64]$E.Value)}}else{Remove-ItemProperty -LiteralPath $E.Path -Name $E.Name -ErrorAction SilentlyContinue} }
function ServiceSnapshot { param([string]$Name);try{$s=Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction Stop;if($s){return [pscustomobject]@{Name=$Name;Exists=$true;StartMode=[string]$s.StartMode;State=[string]$s.State}}}catch{};return [pscustomobject]@{Name=$Name;Exists=$false;StartMode="";State=""} }

function Create-Baseline {
    if (Test-Path $Script:BaselinePointer) { $old=(Get-Content $Script:BaselinePointer -Raw -Encoding UTF8).Trim(); if ($old -and (Test-Path (Join-Path $old "Baseline.xml"))) { return $old } }
    $dir=Join-Path $Script:BackupRoot (Get-Date -Format "yyyyMMdd_HHmmss")
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $state=[ordered]@{Version=$Script:Version;Created=(Get-Date).ToString("o");Computer=$env:COMPUTERNAME;User=$env:USERNAME;PowerScheme=((powercfg /getactivescheme)-join " ");Registry=New-Object System.Collections.ArrayList;Services=New-Object System.Collections.ArrayList;TCP=New-Object System.Collections.ArrayList;BlueStacksGPU=$null;RestorePoint=$false;BcdExport=$false}
    $keys=@(
        @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile","SystemResponsiveness"),@("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile","NetworkThrottlingIndex"),@("HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl","Win32PrioritySeparation"),@("HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling","PowerThrottlingOff"),@("HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers","HwSchMode"),@("HKLM:\SOFTWARE\Microsoft\Windows\Dwm","OverlayTestMode"),@("HKCU:\Software\Microsoft\GameBar","AutoGameModeEnabled"),@("HKCU:\Software\Microsoft\GameBar","AllowAutoGameMode"),@("HKCU:\System\GameConfigStore","GameDVR_Enabled"),@("HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR","AppCaptureEnabled"),@("HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR","AudioCaptureEnabled"),@("HKCU:\Control Panel\Mouse","MouseSpeed"),@("HKCU:\Control Panel\Mouse","MouseThreshold1"),@("HKCU:\Control Panel\Mouse","MouseThreshold2"),@("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects","VisualFXSetting"),@("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced","TaskbarAnimations"),@("HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize","EnableTransparency")
    )
    foreach($k in $keys){$state.Registry.Add((RegSnapshot $k[0] $k[1]))}
    $state.Services.Add((ServiceSnapshot "SysMain"));$state.Services.Add((ServiceSnapshot "WSearch"))
    try{foreach($nic in @(Get-NetAdapter -Physical)){$guid=$nic.InterfaceGuid.ToString();$path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{$guid}";$state.TCP.Add([pscustomobject]@{Guid=$guid;TCPNoDelay=(RegSnapshot $path "TCPNoDelay");TcpAckFrequency=(RegSnapshot $path "TcpAckFrequency")})}}catch{}
    try{foreach($bs in @("$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe","$env:ProgramFiles\BlueStacks_nxt5\HD-Player.exe","${env:ProgramFiles(x86)}\BlueStacks_nxt\HD-Player.exe","${env:ProgramFiles(x86)}\BlueStacks_nxt5\HD-Player.exe")){if($bs -and (Test-Path $bs)){$state.BlueStacksGPU=RegSnapshot "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" $bs;break}}}catch{}
    $state | Export-Clixml -LiteralPath (Join-Path $dir "Baseline.xml")
    powercfg /list | Out-File -LiteralPath (Join-Path $dir "PowerPlans.txt") -Encoding UTF8
    bcdedit /enum all | Out-File -LiteralPath (Join-Path $dir "BCD.txt") -Encoding UTF8
    try{bcdedit /export (Join-Path $dir "BCD_Backup.bak") | Out-Null;$state.BcdExport=$true}catch{}
    try{Checkpoint-Computer -Description "KXM BLUEFIRE BASELINE" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop | Out-Null;$state.RestorePoint=$true}catch{}
    $state | Export-Clixml -LiteralPath (Join-Path $dir "Baseline.xml")
    Set-Content -LiteralPath $Script:BaselinePointer -Value $dir -Encoding UTF8
    Log ("Baseline created BEFORE modifications: " + $dir)
    return $dir
}
function Ensure-Baseline { $null=Create-Baseline }
function Restore-Baseline {
    Header "RESTORE ORIGINAL SETTINGS" "إرجاع الإعدادات الأصلية" "RESTAURER LES REGLAGES INITIAUX"
    if(-not(Test-Path $Script:BaselinePointer)){P (T "No KXM baseline found." "لا توجد نسخة أصلية لـKXM." "Aucune sauvegarde KXM.") Red;Pause-KXM;return}
    $dir=(Get-Content $Script:BaselinePointer -Raw -Encoding UTF8).Trim();$file=Join-Path $dir "Baseline.xml"
    if(-not(Test-Path $file)){P (T "Baseline file is missing." "ملف النسخة الأصلية مفقود." "Fichier de sauvegarde manquant.") Red;Pause-KXM;return}
    P ((T "Baseline: " "النسخة الأصلية: " "Sauvegarde : ") + $dir) Cyan
    $q=T "Restore the settings captured before KXM?" "إرجاع الإعدادات التي كانت موجودة قبل KXM؟" "Restaurer les reglages captures avant KXM ?"
    if(-not(Ask $q)){return}
    $s=Import-Clixml -LiteralPath $file
    foreach($e in $s.Registry){RestoreReg $e}
    foreach($svc in $s.Services){if($svc.Exists){if($svc.StartMode -eq "Auto"){Set-Service $svc.Name -StartupType Automatic -ErrorAction SilentlyContinue}elseif($svc.StartMode -eq "Manual"){Set-Service $svc.Name -StartupType Manual -ErrorAction SilentlyContinue}elseif($svc.StartMode -eq "Disabled"){Set-Service $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue};if($svc.State -eq "Running"){Start-Service $svc.Name -ErrorAction SilentlyContinue}elseif($svc.State -eq "Stopped"){Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue}}}
    foreach($n in $s.TCP){RestoreReg $n.TCPNoDelay;RestoreReg $n.TcpAckFrequency}
    if($null -ne $s.BlueStacksGPU){RestoreReg $s.BlueStacksGPU}
    if($s.PowerScheme -match "([0-9a-fA-F-]{36})"){powercfg /setactive $Matches[1] | Out-Null}
    P (T "RESTORE COMPLETE. Reboot Windows." "اكتملت الاستعادة. أعد تشغيل Windows." "RESTAURATION TERMINEE. Redemarrez Windows.") Green
    Log "Baseline restored."
    Pause-KXM
}

function Apply-Base {powercfg /setactive SCHEME_MIN | Out-Null;RegDword "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1;RegDword "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1;RegDword "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0;RegDword "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0;RegDword "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AudioCaptureEnabled" 0;Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseSpeed -Value "0" -Force;Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseThreshold1 -Value "0" -Force;Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseThreshold2 -Value "0" -Force;RegDword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2;RegDword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0;RegDword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0 }
function Apply-CPU {$mm="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile";$games="$mm\Tasks\Games";RegDword $mm "SystemResponsiveness" 0;RegDword $mm "NetworkThrottlingIndex" 4294967295;RegDword $games "GPU Priority" 8;RegDword $games "Priority" 6;RegString $games "Scheduling Category" "High";RegString $games "SFIO Priority" "High";RegDword "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38;RegDword "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1;powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 | Out-Null;powercfg /setacvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVE 0 | Out-Null }
function Apply-BlueStacks {$paths=@("$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe","$env:ProgramFiles\BlueStacks_nxt5\HD-Player.exe","${env:ProgramFiles(x86)}\BlueStacks_nxt\HD-Player.exe","${env:ProgramFiles(x86)}\BlueStacks_nxt5\HD-Player.exe");$bs=$null;foreach($p in $paths){if($p -and (Test-Path $p)){$bs=$p;break}};if($null -eq $bs){P (T "BlueStacks not found." "لم يتم العثور على BlueStacks." "BlueStacks introuvable.") Yellow;return};RegString "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" $bs "GpuPreference=2;";foreach($exe in @("HD-Player.exe","Bluestacks.exe","HD-Service.exe","HD-Agent.exe","BstkSVC.exe")){RegDword ("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\{0}\PerfOptions" -f $exe) "CpuPriorityClass" 3};$proc=Get-Process -Name "HD-Player" -ErrorAction SilentlyContinue | Select-Object -First 1;if($proc){try{$proc.PriorityClass="AboveNormal"}catch{}} }
function Apply-Network {netsh int tcp set global rss=enabled | Out-Null;netsh int tcp set global autotuninglevel=normal | Out-Null;RegDword "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295;try{foreach($nic in @(Get-NetAdapter -Physical | Where-Object {$_.Status -eq "Up"})){Disable-NetAdapterPowerManagement -Name $nic.Name -ErrorAction SilentlyContinue;$guid=$nic.InterfaceGuid.ToString();$path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{$guid}";RegDword $path "TCPNoDelay" 1;RegDword $path "TcpAckFrequency" 1}}catch{} }
function Apply-Storage {$h=Get-Hardware;if($h.HasSSD){try{Optimize-Volume -DriveLetter C -ReTrim -ErrorAction Stop | Out-Null;P "ReTrim complete." Green}catch{P "ReTrim unavailable." DarkYellow}}else{P (T "No SSD detected; ReTrim skipped." "لم يتم اكتشاف SSD؛ تم تجاوز ReTrim." "Aucun SSD detecte; ReTrim ignore.") DarkYellow};$q=T "Apply NTFS last-access + 8.3 optimization?" "تطبيق تحسينات NTFS الخاصة بـLast Access و8.3؟" "Appliquer les optimisations NTFS Last Access + 8.3 ?";if(Ask $q){fsutil behavior set disablelastaccess 1 | Out-Null;fsutil behavior set disable8dot3 1 | Out-Null}}
function Apply-Background {$q=T "Disable selected telemetry/feedback tasks?" "تعطيل بعض مهام Telemetry/Feedback؟" "Desactiver certaines taches Telemetry/Feedback ?";if(Ask $q){foreach($t in @("\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser","\Microsoft\Windows\Application Experience\ProgramDataUpdater","\Microsoft\Windows\Application Experience\StartupAppTask","\Microsoft\Windows\Customer Experience Improvement Program\Consolidator","\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip","\Microsoft\Windows\Feedback\Siuf\DmClient")){try{$n=$t.Substring($t.LastIndexOf("\")+1);$p=$t.Substring(0,$t.LastIndexOf("\")+1);Disable-ScheduledTask -TaskName $n -TaskPath $p -ErrorAction SilentlyContinue | Out-Null}catch{}}};$h=Get-Hardware;if($h.HasHDD -or $h.RAMGB -le 8){try{Set-Service SysMain -StartupType Automatic -ErrorAction SilentlyContinue;Start-Service SysMain -ErrorAction SilentlyContinue}catch{}}}

function Run-Audit {Header "HARDWARE AUDIT" "فحص العتاد" "AUDIT MATERIEL";$h=Get-Hardware;$r=Get-Recommendation $h;Show-Hardware $h $r;Pause-KXM}
function Run-SelfTest {Header "SELF-TEST" "الفحص الذاتي" "AUTO-TEST";P (T "Read-only. No changes." "قراءة فقط. لا تغييرات." "Lecture seule. Aucune modification.") Yellow;$pass=0;$fail=0;foreach($cmd in @("fltmc.exe","powershell.exe","reg.exe","powercfg.exe","bcdedit.exe","fsutil.exe","netsh.exe","ipconfig.exe","schtasks.exe","sc.exe")){if(Get-Command $cmd -ErrorAction SilentlyContinue){P ("[{0}] PASS" -f $cmd) Green;$pass++}else{P ("[{0}] FAIL" -f $cmd) Red;$fail++}};P ("PASS: {0} | FAIL: {1}" -f $pass,$fail) Cyan;Pause-KXM}
function Run-Recommended {Ensure-Baseline;Header "RECOMMENDED PROFILE" "البروفايل الموصى به" "PROFIL RECOMMANDE";$h=Get-Hardware;$r=Get-Recommendation $h;Show-Hardware $h $r;$q=T "Apply this recommended profile?" "تطبيق هذا البروفايل؟" "Appliquer ce profil ?";if(Ask $q){Apply-Base;Apply-CPU;Apply-BlueStacks;if($h.HasHDD -or $h.RAMGB -le 8){try{Set-Service SysMain -StartupType Automatic -ErrorAction SilentlyContinue;Start-Service SysMain -ErrorAction SilentlyContinue}catch{}};Log "Recommended profile applied.";P (T "Applied. Reboot before benchmark." "تم التطبيق. أعد التشغيل قبل الاختبار." "Applique. Redemarrez avant le benchmark.") Green};Pause-KXM}
function Run-Competitive {Ensure-Baseline;Header "COMPETITIVE PROFILE" "بروفايل المنافسة" "PROFIL COMPETITIF";$h=Get-Hardware;$r=Get-Recommendation $h;Show-Hardware $h $r;$q=T "Apply Competitive Profile?" "تطبيق بروفايل المنافسة؟" "Appliquer le profil competitif ?";if(Ask $q){Apply-Base;Apply-CPU;Apply-Network;Apply-BlueStacks;if($h.HasHDD -or $h.RAMGB -le 8){try{Set-Service SysMain -StartupType Automatic -ErrorAction SilentlyContinue;Start-Service SysMain -ErrorAction SilentlyContinue}catch{}};Log "Competitive profile applied.";P (T "Applied. Reboot before test." "تم التطبيق. أعد التشغيل قبل الاختبار." "Applique. Redemarrez avant le test.") Green};Pause-KXM}
function Run-BlueStacks {Ensure-Baseline;Header "BLUESTACKS MODE" "وضع BlueStacks" "MODE BLUESTACKS";Apply-BlueStacks;Pause-KXM}
function Run-Network {Ensure-Baseline;Header "NETWORK ENGINE" "محرك الشبكة" "MOTEUR RESEAU";Apply-Network;P (T "Network applied." "تم تطبيق إعدادات الشبكة." "Reseau applique.") Green;Pause-KXM}
function Run-Storage {Ensure-Baseline;Header "STORAGE + MEMORY" "التخزين + الذاكرة" "STOCKAGE + MEMOIRE";Apply-Storage;Pause-KXM}
function Run-Background {Ensure-Baseline;Header "BACKGROUND CUT" "تقليل الخلفية" "TACHES DE FOND";Apply-Background;Pause-KXM}
function Run-Clean {Ensure-Baseline;Header "CLEAN + PREPARE" "تنظيف وتجهيز" "NETTOYER + PREPARER";foreach($d in @($env:TEMP,(Join-Path $env:LOCALAPPDATA "Temp"),"C:\Windows\Temp")){if(Test-Path $d){Remove-Item -LiteralPath (Join-Path $d "*") -Recurse -Force -ErrorAction SilentlyContinue}};ipconfig /flushdns | Out-Null;P (T "Cleanup complete. Personal files are not targeted." "اكتمل التنظيف. لا يتم استهداف ملفاتك الشخصية." "Nettoyage termine. Les fichiers personnels ne sont pas cibles.") Green;Pause-KXM}
function Run-Benchmark {Header "BENCHMARK" "Benchmark" "Benchmark";$f=Join-Path $Script:BenchRoot ("KXM_"+(Get-Date -Format "yyyyMMdd_HHmmss")+".txt");$h=Get-Hardware;$r=Get-Recommendation $h;@("KXM BLUEFIRE v$Script:Version","Timestamp: $(Get-Date)","CPU: $($h.CPU)","Cores/Threads: $($h.Cores)/$($h.Threads)","RAM GB: $($h.RAMGB)","GPU: $($h.GPU)","Recommended BlueStacks: $($r.BlueStacksCores) cores / $($r.BlueStacksRAM) GB", "Power: $((powercfg /getactivescheme) -join ' ')") | Set-Content -LiteralPath $f -Encoding UTF8;P $f Green;Pause-KXM}
function Run-Verify {Header "VERIFY" "التحقق" "VERIFICATION";$mm="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile";$g="$mm\Tasks\Games";P (("Power: "+((powercfg /getactivescheme)-join " "))) White;P (("SystemResponsiveness: "+(Get-ItemProperty $mm -ErrorAction SilentlyContinue).SystemResponsiveness)) White;P (("NetworkThrottlingIndex: "+(Get-ItemProperty $mm -ErrorAction SilentlyContinue).NetworkThrottlingIndex)) White;P (("Games GPU Priority: "+(Get-ItemProperty $g -ErrorAction SilentlyContinue)."GPU Priority")) White;P (("Win32PrioritySeparation: "+(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ErrorAction SilentlyContinue).Win32PrioritySeparation)) White;try{$s=Get-Service SysMain;P (("SysMain: "+$s.Status+" | "+$s.StartType)) White}catch{};Pause-KXM}
function Run-Language {Header "LANGUAGE" "اللغة" "LANGUE";P "1. English";P "2. العربية";P "3. Français";$x=Read-Host "Select";if($x -eq "1"){$Script:Lang="EN"}elseif($x -eq "2"){$Script:Lang="AR"}elseif($x -eq "3"){$Script:Lang="FR"};Set-Content -LiteralPath $Script:LanguageFile -Value $Script:Lang -Encoding UTF8}

while($true){
    Header "GGOS // BLUESTACKS // FREE FIRE" "GGOS // BLUESTACKS // FREE FIRE" "GGOS // BLUESTACKS // FREE FIRE"
    P ("KXM // {0}" -f $Script:Author) Cyan
    P ("Version: {0} | License: {1}" -f $Script:Version,$Script:License) Cyan
    P ("Project: {0}" -f $Script:ProjectURL) DarkCyan
    P ""
    Say "SELF" Green;Say "AUDIT" White;Say "BACKUP" White;P "";Say "RECO" Green;Say "COMP" White;Say "BS" White;Say "NET" White;Say "STORE" White;Say "BG" White;P "";Say "LAB" White;Say "CLEAN" White;Say "BENCH" White;Say "VERIFY" White;Say "RESTORE" Yellow;Say "LANG" White;Say "EXIT" Red;P ""
    $c=Read-Host "KXM >"
    if($c -eq "1"){Run-SelfTest}elseif($c -eq "2"){Run-Audit}elseif($c -eq "3"){Backup-Center}elseif($c -eq "4"){Run-Recommended}elseif($c -eq "5"){Run-Competitive}elseif($c -eq "6"){Run-BlueStacks}elseif($c -eq "7"){Run-Network}elseif($c -eq "8"){Run-Storage}elseif($c -eq "9"){Run-Background}elseif($c -eq "A" -or $c -eq "a"){Ensure-Baseline;Header "EXPERIMENTAL LAB" "المختبر التجريبي" "LABORATOIRE EXPERIMENTAL";$q=T "Force HAGS ON?" "فرض HAGS ON؟" "Forcer HAGS ON ?";if(Ask $q){Reg-Dword "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2};$q=T "Disable MPO as workaround?" "تعطيل MPO كحل للتقطيع؟" "Desactiver MPO comme correctif ?";if(Ask $q){Reg-Dword "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5};$q=T "Disable Dynamic Tick?" "تعطيل Dynamic Tick؟" "Desactiver Dynamic Tick ?";if(Ask $q){bcdedit /set disabledynamictick yes | Out-Null};$q=T "Disable VBS/HVCI?" "تعطيل VBS/HVCI؟" "Desactiver VBS/HVCI ?";if(Ask $q){Reg-Dword "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" "EnableVirtualizationBasedSecurity" 0;Reg-Dword "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags" 0};Wait-Key}elseif($c -eq "B" -or $c -eq "b"){Run-Clean}elseif($c -eq "C" -or $c -eq "c"){Run-Benchmark}elseif($c -eq "D" -or $c -eq "d"){Run-Verify}elseif($c -eq "R" -or $c -eq "r"){Restore-Baseline}elseif($c -eq "L" -or $c -eq "l"){Run-Language}elseif($c -eq "X" -or $c -eq "x"){break}}

function Backup-Center { Header "BACKUP CENTER" "مركز النسخ الاحتياطي" "CENTRE DE SAUVEGARDE";if(Test-Path $Script:BaselinePointer){$d=(Get-Content $Script:BaselinePointer -Raw -Encoding UTF8).Trim();P $d Cyan}else{P (T "No baseline yet. It will be created before the first modification." "لا توجد نسخة أصلية بعد. سيتم إنشاؤها قبل أول تعديل." "Aucune sauvegarde. Elle sera creee avant la premiere modification.") Yellow};Wait-Key }
function Say { param([string]$Key,[ConsoleColor]$Color=[ConsoleColor]::Gray);$x=@{SELF=@("1. Self-Test              Read-only compatibility test","1. الفحص الذاتي             اختبار توافق بدون تعديل","1. Auto-test               Test de compatibilite");AUDIT=@("2. Hardware Audit         Hardware + recommendations","2. فحص العتاد                العتاد + التوصيات","2. Audit materiel         Materiel + recommandations");BACKUP=@("3. Backup Center          Original settings / recovery","3. مركز النسخ الاحتياطي     الإعدادات الأصلية / الاستعادة","3. Centre sauvegarde      Reglages initiaux / restauration");RECO=@("4. Recommended Profile    Smart hardware-aware profile","4. البروفايل الموصى به      بروفايل ذكي حسب الجهاز","4. Profil recommande     Profil adapte au materiel");COMP=@("5. Competitive Profile    Stronger gaming profile","5. بروفايل المنافسة         بروفايل ألعاب أقوى","5. Profil competitif     Profil jeu plus pousse");BS=@("6. BlueStacks Mode        Emulator-specific tuning","6. وضع BlueStacks          تحسين خاص بالمحاكي","6. Mode BlueStacks         Optimisation de l'emulateur");NET=@("7. Network Engine         RSS / TCP / NIC","7. محرك الشبكة              RSS / TCP / NIC","7. Moteur reseau            RSS / TCP / NIC");STORE=@("8. Storage + Memory       HDD / SSD aware","8. التخزين + الذاكرة        حسب HDD / SSD","8. Stockage + memoire     Adapte HDD / SSD");BG=@("9. Background Cut         Selective background reduction","9. تقليل الخلفية            تقليل انتقائي","9. Taches de fond          Reduction selective");LAB=@("A. Experimental Lab       HAGS / MPO / VBS / timers","A. المختبر التجريبي         HAGS / MPO / VBS / timers","A. Laboratoire             HAGS / MPO / VBS / timers");CLEAN=@("B. Clean + Prepare        Pre-game cleanup","B. تنظيف وتجهيز             تنظيف قبل اللعب","B. Nettoyer + preparer    Nettoyage avant jeu");BENCH=@("C. Benchmark              Before / after snapshot","C. Benchmark                قياس قبل / بعد","C. Benchmark               Mesure avant / apres");VERIFY=@("D. Verify                 Verify current state","D. تحقق                     التحقق من الحالة الحالية","D. Verification            Verifier l'etat");RESTORE=@("R. Restore                 Restore original pre-KXM state","R. استعادة                 إرجاع الحالة الأصلية قبل KXM","R. Restaurer              Restaurer l'etat initial");LANG=@("L. Language               English / العربية / Français","L. اللغة                   English / العربية / Français","L. Langue                 English / العربية / Français");EXIT=@("X. Exit","X. خروج","X. Quitter")};$i=0;if($Script:Lang -eq "AR"){$i=1}elseif($Script:Lang -eq "FR"){$i=2};UI $x[$Key][$i] $Color }
function UI {param([string]$Text,[ConsoleColor]$Color=[ConsoleColor]::Gray);Write-Host $Text -ForegroundColor $Color}
function Wait-Key {Pause-KXM}
function Reg-Dword {param([string]$Path,[string]$Name,[int64]$Value);RegDword $Path $Name $Value}
''