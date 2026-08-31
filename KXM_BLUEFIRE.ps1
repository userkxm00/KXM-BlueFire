# KXM BLUEFIRE v13
# Windows PowerShell 5.1 compatible.
# Recovery-first: baseline before first change, restore from ProgramData.

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
$Script:CurrentBaseline = Join-Path $Script:Root "CURRENT_BASELINE.txt"
$Script:LanguageFile = Join-Path $Script:Root "language.txt"
$Script:LogFile = Join-Path $Script:LogRoot "KXM.log"
$Script:ConfigFile = Join-Path $PSScriptRoot "KXM_CONFIG.ini"

New-Item -ItemType Directory -Path $Script:Root -Force | Out-Null
New-Item -ItemType Directory -Path $Script:BackupRoot -Force | Out-Null
New-Item -ItemType Directory -Path $Script:LogRoot -Force | Out-Null
New-Item -ItemType Directory -Path $Script:BenchRoot -Force | Out-Null

if (Test-Path $Script:ConfigFile) {
    foreach ($line in (Get-Content -LiteralPath $Script:ConfigFile -Encoding UTF8)) {
        if ($line -match "^AUTHOR=(.*)$") { $Script:Author = $Matches[1] }
        elseif ($line -match "^VERSION=(.*)$") { $Script:Version = $Matches[1] }
        elseif ($line -match "^PROJECT_URL=(.*)$") { $Script:ProjectURL = $Matches[1] }
        elseif ($line -match "^LICENSE=(.*)$") { $Script:License = $Matches[1] }
    }
}

$Script:Lang = "EN"
if (Test-Path $Script:LanguageFile) {
    $savedLang = (Get-Content -LiteralPath $Script:LanguageFile -Raw -Encoding UTF8).Trim().ToUpperInvariant()
    if ($savedLang -eq "AR") { $Script:Lang = "AR" }
    elseif ($savedLang -eq "FR") { $Script:Lang = "FR" }
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

function UI {
    param([string]$Text,[ConsoleColor]$Color=[ConsoleColor]::Gray)
    Write-Host $Text -ForegroundColor $Color
}

function Header {
    param([string]$EN,[string]$AR,[string]$FR)
    Clear-Host
    UI "" 
    UI "=========================================================================" Cyan
    UI "                         KXM // BLUEFIRE" White
    UI (T $EN $AR $FR) Green
    UI "=========================================================================" Cyan
    UI "" 
}

function Wait-Key {
    UI ""
    UI (T "Press any key to continue..." "اضغط أي مفتاح للمتابعة..." "Appuyez sur une touche pour continuer...") DarkGray
    try { $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null } catch {}
}

function Ask-YesNo {
    param([string]$Question)
    while ($true) {
        UI ""
        UI $Question Yellow
        $a = Read-Host "Y/N"
        if ($a -match "^[Yy]$") { return $true }
        if ($a -match "^[Nn]$") { return $false }
    }
}

function Log-Message {
    param([string]$Text)
    try {
        Add-Content -LiteralPath $Script:LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$Text) -Encoding UTF8
    } catch {}
}

function Reg-Dword {
    param([string]$Path,[string]$Name,[int64]$Value)
    try {
        New-Item -Path $Path -Force | Out-Null
        New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
    } catch {}
}

function Reg-String {
    param([string]$Path,[string]$Name,[string]$Value)
    try {
        New-Item -Path $Path -Force | Out-Null
        New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $Value -Force | Out-Null
    } catch {}
}

# ---------------------------------------------------------------------------
# Hardware detection and recommendations
# ---------------------------------------------------------------------------
function Get-Hardware {
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $os = Get-CimInstance Win32_OperatingSystem
    $gpus = @(Get-CimInstance Win32_VideoController)
    $disks = @(Get-PhysicalDisk)

    $ram = 0
    if ($cs) { $ram = [math]::Round($cs.TotalPhysicalMemory / 1GB,1) }
    $cores = 0
    $threads = 0
    $cpuName = "Unknown"
    $virt = $false

    if ($cpu) {
        $cpuName = [string]$cpu.Name
        $cores = [int]$cpu.NumberOfCores
        $threads = [int]$cpu.NumberOfLogicalProcessors
        $virt = [bool]$cpu.VirtualizationFirmwareEnabled
    }

    $gpuName = ""
    $modern = $false
    foreach ($g in $gpus) {
        if ($gpuName -ne "") { $gpuName += " | " }
        $gpuName += [string]$g.Name
        if ([string]$g.Name -match "RTX|GTX|Radeon RX|Arc") { $modern = $true }
    }

    $hdd = $false
    $ssd = $false
    foreach ($d in $disks) {
        if ([string]$d.MediaType -eq "HDD") { $hdd = $true }
        if ([string]$d.MediaType -eq "SSD") { $ssd = $true }
    }

    $win = "Unknown"
    if ($os) { $win = "{0} Build {1}" -f $os.Caption,$os.BuildNumber }

    return [pscustomobject]@{
        CPU=$cpuName
        Cores=$cores
        Threads=$threads
        RAMGB=$ram
        GPU=$gpuName
        Virtualization=$virt
        HasHDD=$hdd
        HasSSD=$ssd
        ModernDiscrete=$modern
        Windows=$win
    }
}

function Get-Recommendation {
    param($H)
    $bsCores = 2
    if ($H.Threads -ge 4) { $bsCores = 4 }
    if ($H.Threads -ge 12) { $bsCores = 6 }

    $bsRam = 2
    if ($H.RAMGB -ge 8) { $bsRam = 3 }
    if ($H.RAMGB -ge 16) { $bsRam = 4 }
    if ($H.RAMGB -ge 32) { $bsRam = 6 }

    $profile = "STANDARD"
    if ($H.Threads -ge 8 -and $H.RAMGB -ge 16 -and $H.ModernDiscrete) { $profile = "PERFORMANCE" }

    $sysmain = "OPTIONAL"
    if ($H.HasHDD -or $H.RAMGB -le 8) { $sysmain = "KEEP AUTO" }

    $hags = "DEFAULT"
    if ($H.ModernDiscrete) { $hags = "TEST ON vs DEFAULT" }

    return [pscustomobject]@{
        Profile=$profile
        BlueStacksCores=$bsCores
        BlueStacksRAM=$bsRam
        SysMain=$sysmain
        HAGS=$hags
    }
}

function Show-Hardware {
    param($H,$R)
    UI "Detected hardware" Cyan
    UI ("CPU            : {0}" -f $H.CPU) White
    UI ("Cores / Threads: {0} / {1}" -f $H.Cores,$H.Threads) White
    UI ("RAM            : {0} GB" -f $H.RAMGB) White
    UI ("GPU            : {0}" -f $H.GPU) White
    UI ("Virtualization : {0}" -f $H.Virtualization) White
    UI ("Storage        : HDD={0} | SSD={1}" -f $H.HasHDD,$H.HasSSD) White
    UI ("Windows        : {0}" -f $H.Windows) White
    UI ""
    UI "KXM SMART RECOMMENDATION" Green
    UI ("Profile       : {0}" -f $R.Profile) Yellow
    UI ("BlueStacks    : {0} CPU cores | {1} GB RAM" -f $R.BlueStacksCores,$R.BlueStacksRAM) White
    UI ("HAGS          : {0}" -f $R.HAGS) White
    UI ("SysMain       : {0}" -f $R.SysMain) White
    UI "Pagefile      : Windows managed" White
    UI "Memory Comp.  : keep enabled" White
}

# ---------------------------------------------------------------------------
# Durable baseline / restore
# ---------------------------------------------------------------------------
function Get-RegSnapshot {
    param([string]$Path,[string]$Name)
    $exists = $false
    $value = $null
    $kind = "DWord"
    try {
        $item = Get-ItemProperty -LiteralPath $Path -ErrorAction Stop
        $prop = $item.PSObject.Properties[$Name]
        if ($null -ne $prop) {
            $exists = $true
            $value = $prop.Value
            if ($value -is [string]) { $kind = "String" }
        }
    } catch {}
    return [pscustomobject]@{ Path=$Path; Name=$Name; Exists=$exists; Value=$value; Kind=$kind }
}

function Restore-RegSnapshot {
    param($Entry)
    try {
        if ($Entry.Exists) {
            if ($Entry.Kind -eq "String") { Reg-String $Entry.Path $Entry.Name ([string]$Entry.Value) }
            else { Reg-Dword $Entry.Path $Entry.Name ([int64]$Entry.Value) }
        } else {
            Remove-ItemProperty -LiteralPath $Entry.Path -Name $Entry.Name -ErrorAction SilentlyContinue
        }
    } catch {}
}

function Capture-Service {
    param([string]$Name)
    try {
        $s = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
        if ($s) { return [pscustomobject]@{Name=$Name;Exists=$true;StartMode=[string]$s.StartMode;State=[string]$s.State} }
    } catch {}
    return [pscustomobject]@{Name=$Name;Exists=$false;StartMode="";State=""}
}

function Create-Baseline {
    if (Test-Path $Script:CurrentBaseline) {
        $old = (Get-Content $Script:CurrentBaseline -Raw -Encoding UTF8).Trim()
        if ($old -and (Test-Path (Join-Path $old "Baseline.xml"))) { return $old }
    }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $dir = Join-Path $Script:BackupRoot $stamp
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    $state = [ordered]@{
        Version=$Script:Version
        Created=(Get-Date).ToString("o")
        Computer=$env:COMPUTERNAME
        User=$env:USERNAME
        PowerScheme=((powercfg /getactivescheme) -join " ")
        Registry=New-Object System.Collections.ArrayList
        Services=New-Object System.Collections.ArrayList
        TCP=New-Object System.Collections.ArrayList
        BlueStacksGPU=$null
        BcdExport=$false
        RestorePoint=$false
    }

    $targets = @(
        @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile","SystemResponsiveness"),
        @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile","NetworkThrottlingIndex"),
        @("HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl","Win32PrioritySeparation"),
        @("HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling","PowerThrottlingOff"),
        @("HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers","HwSchMode"),
        @("HKLM:\SOFTWARE\Microsoft\Windows\Dwm","OverlayTestMode"),
        @("HKCU:\Software\Microsoft\GameBar","AutoGameModeEnabled"),
        @("HKCU:\Software\Microsoft\GameBar","AllowAutoGameMode"),
        @("HKCU:\System\GameConfigStore","GameDVR_Enabled"),
        @("HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR","AppCaptureEnabled"),
        @("HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR","AudioCaptureEnabled"),
        @("HKCU:\Control Panel\Mouse","MouseSpeed"),
        @("HKCU:\Control Panel\Mouse","MouseThreshold1"),
        @("HKCU:\Control Panel\Mouse","MouseThreshold2"),
        @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects","VisualFXSetting"),
        @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced","TaskbarAnimations"),
        @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize","EnableTransparency")
    )

    foreach ($item in $targets) {
        $state.Registry.Add((Get-RegSnapshot $item[0] $item[1]))
    }

    $state.Services.Add((Capture-Service "SysMain"))
    $state.Services.Add((Capture-Service "WSearch"))

    try {
        foreach ($nic in @(Get-NetAdapter -Physical)) {
            $guid=$nic.InterfaceGuid.ToString()
            $path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{$guid}"
            $state.TCP.Add([pscustomobject]@{
                Guid=$guid
                TCPNoDelay=(Get-RegSnapshot $path "TCPNoDelay")
                TcpAckFrequency=(Get-RegSnapshot $path "TcpAckFrequency")
            })
        }
    } catch {}

    try {
        foreach ($bs in @(
            "$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe",
            "$env:ProgramFiles\BlueStacks_nxt5\HD-Player.exe",
            "${env:ProgramFiles(x86)}\BlueStacks_nxt\HD-Player.exe",
            "${env:ProgramFiles(x86)}\BlueStacks_nxt5\HD-Player.exe"
        )) {
            if ($bs -and (Test-Path $bs)) {
                $state.BlueStacksGPU=Get-RegSnapshot "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" $bs
                break
            }
        }
    } catch {}

    $state | Export-Clixml -LiteralPath (Join-Path $dir "Baseline.xml")
    powercfg /list | Out-File -LiteralPath (Join-Path $dir "PowerPlans.txt") -Encoding UTF8
    bcdedit /enum all | Out-File -LiteralPath (Join-Path $dir "BCD.txt") -Encoding UTF8

    try { bcdedit /export (Join-Path $dir "BCD_Backup.bak") | Out-Null; $state.BcdExport=$true } catch {}
    try { Checkpoint-Computer -Description "KXM BLUEFIRE BASELINE" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop | Out-Null; $state.RestorePoint=$true } catch {}

    $state | Export-Clixml -LiteralPath (Join-Path $dir "Baseline.xml")
    Set-Content -LiteralPath $Script:CurrentBaseline -Value $dir -Encoding UTF8
    Log-Message ("Baseline created before modification: " + $dir)
    return $dir
}

function Ensure-Baseline { $null=Create-Baseline }

function Backup-Center {
    Header "BACKUP CENTER" "مركز النسخ الاحتياطي" "CENTRE DE SAUVEGARDE"
    if (Test-Path $Script:CurrentBaseline) {
        $dir=(Get-Content $Script:CurrentBaseline -Raw -Encoding UTF8).Trim()
        UI (T "Current baseline:" "النسخة الأصلية الحالية:" "Sauvegarde actuelle :") Cyan
        UI $dir White
        UI ""
        UI (T "Captured BEFORE the first KXM modification." "تم حفظها قبل أول تعديل من KXM." "Capturee AVANT la premiere modification KXM.") Green
    } else {
        UI (T "No baseline exists yet." "لا توجد نسخة أصلية بعد." "Aucune sauvegarde n'existe encore.") Yellow
        UI (T "It will be created automatically before the first modification." "سيتم إنشاؤها تلقائيًا قبل أول تعديل." "Elle sera creee automatiquement avant la premiere modification.") White
    }
    UI ""
    UI "C:\ProgramData\KXM\BlueFire\Backups" White
    Wait-Key
}

function Restore-Baseline {
    Header "RESTORE ORIGINAL SETTINGS" "إرجاع الإعدادات الأصلية" "RESTAURER LES REGLAGES INITIAUX"
    if (-not (Test-Path $Script:CurrentBaseline)) {
        UI (T "No KXM baseline found." "لا توجد نسخة KXM أصلية." "Aucune sauvegarde KXM trouvee.") Red
        Wait-Key
        return
    }

    $dir=(Get-Content $Script:CurrentBaseline -Raw -Encoding UTF8).Trim()
    $file=Join-Path $dir "Baseline.xml"
    if (-not (Test-Path $file)) {
        UI (T "Baseline file is missing." "ملف النسخة الأصلية مفقود." "Fichier de sauvegarde manquant.") Red
        Wait-Key
        return
    }

    $state=Import-Clixml -LiteralPath $file
    UI (T "Restore source:" "مصدر الاستعادة:" "Source :") Cyan
    UI $dir White
    UI (T "Restores values captured BEFORE the first KXM modification." "سيتم إرجاع القيم التي كانت موجودة قبل أول تعديل من KXM." "Restaure les valeurs capturees AVANT la premiere modification KXM.") Yellow

    $q=T "Restore now?" "هل تريد الاستعادة الآن؟" "Restaurer maintenant ?"
    if (-not (Ask-YesNo $q)) { return }

    foreach ($entry in $state.Registry) { Restore-RegSnapshot $entry }

    foreach ($svc in $state.Services) {
        if ($svc.Exists) {
            if ($svc.StartMode -eq "Auto") { Set-Service -Name $svc.Name -StartupType Automatic -ErrorAction SilentlyContinue }
            elseif ($svc.StartMode -eq "Manual") { Set-Service -Name $svc.Name -StartupType Manual -ErrorAction SilentlyContinue }
            elseif ($svc.StartMode -eq "Disabled") { Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue }
            if ($svc.State -eq "Running") { Start-Service -Name $svc.Name -ErrorAction SilentlyContinue }
            elseif ($svc.State -eq "Stopped") { Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue }
        }
    }

    foreach ($nic in $state.TCP) {
        Restore-RegSnapshot $nic.TCPNoDelay
        Restore-RegSnapshot $nic.TcpAckFrequency
    }

    if ($null -ne $state.BlueStacksGPU) { Restore-RegSnapshot $state.BlueStacksGPU }
    if ($state.PowerScheme -match "([0-9a-fA-F-]{36})") { powercfg /setactive $Matches[1] | Out-Null }

    UI (T "RESTORE COMPLETE. Reboot Windows." "اكتملت الاستعادة. أعد تشغيل Windows." "RESTAURATION TERMINEE. Redemarrez Windows.") Green
    Log-Message "Baseline restored."
    Wait-Key
}

# ---------------------------------------------------------------------------
# Entry points
# ---------------------------------------------------------------------------
function Audit {
    Header "HARDWARE AUDIT" "فحص العتاد" "AUDIT MATERIEL"
    $h=Get-Hardware
    $r=Get-Recommendation $h
    Show-Hardware $h $r
    Wait-Key
}

function Self-Test {
    Header "SELF-TEST" "الفحص الذاتي" "AUTO-TEST"
    UI (T "Read-only. No system changes." "قراءة فقط. لا تغييرات." "Lecture seule. Aucune modification.") Yellow
    $cmds=@("fltmc.exe","powershell.exe","reg.exe","powercfg.exe","bcdedit.exe","fsutil.exe","netsh.exe","ipconfig.exe","schtasks.exe","sc.exe")
    $pass=0
    $fail=0
    foreach ($cmd in $cmds) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) { UI ("[{0}] PASS" -f $cmd) Green; $pass++ }
        else { UI ("[{0}] FAIL" -f $cmd) Red; $fail++ }
    }
    UI ""
    UI ("PASS: {0} | FAIL: {1}" -f $pass,$fail) Cyan
    Wait-Key
}

function Recommended {
    Ensure-Baseline
    Header "RECOMMENDED PROFILE" "البروفايل الموصى به" "PROFIL RECOMMANDE"
    $h=Get-Hardware
    $r=Get-Recommendation $h
    Show-Hardware $h $r
    $q=T "Apply this recommended profile?" "تطبيق هذا البروفايل الموصى به؟" "Appliquer ce profil recommande ?"
    if (Ask-YesNo $q) {
        Apply-Base
        Apply-CPU
        Apply-BlueStacks
        if ($h.HasHDD -or $h.RAMGB -le 8) {
            try { Set-Service SysMain -StartupType Automatic -ErrorAction SilentlyContinue } catch {}
            try { Start-Service SysMain -ErrorAction SilentlyContinue } catch {}
        }
        Log-Message "Recommended profile applied."
        UI (T "Applied. Reboot before benchmark." "تم التطبيق. أعد التشغيل قبل الاختبار." "Applique. Redemarrez avant le benchmark.") Green
    }
    Wait-Key
}

function Competitive {
    Ensure-Baseline
    Header "COMPETITIVE PROFILE" "بروفايل المنافسة" "PROFIL COMPETITIF"
    $h=Get-Hardware
    $r=Get-Recommendation $h
    Show-Hardware $h $r
    $q=T "Apply Competitive Profile?" "تطبيق بروفايل المنافسة؟" "Appliquer le profil competitif ?"
    if (Ask-YesNo $q) {
        Apply-Base
        Apply-CPU
        Apply-Network
        Apply-BlueStacks
        if ($h.HasHDD -or $h.RAMGB -le 8) {
            try { Set-Service SysMain -StartupType Automatic -ErrorAction SilentlyContinue } catch {}
            try { Start-Service SysMain -ErrorAction SilentlyContinue } catch {}
        }
        Log-Message "Competitive profile applied."
        UI (T "Applied. Reboot before test." "تم التطبيق. أعد التشغيل قبل الاختبار." "Applique. Redemarrez avant le test.") Green
    }
    Wait-Key
}

function Set-Language {
    Header "LANGUAGE" "اللغة" "LANGUE"
    UI "1. English" White
    UI "2. العربية" White
    UI "3. Français" White
    $x=Read-Host "Select"
    if ($x -eq "1") { $Script:Lang="EN" }
    elseif ($x -eq "2") { $Script:Lang="AR" }
    elseif ($x -eq "3") { $Script:Lang="FR" }
    Set-Content -LiteralPath $Script:LanguageFile -Value $Script:Lang -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Main menu
# ---------------------------------------------------------------------------
while ($true) {
    Header "GGOS // BLUESTACKS // FREE FIRE" "GGOS // BLUESTACKS // FREE FIRE" "GGOS // BLUESTACKS // FREE FIRE"
    UI ("KXM // {0}" -f $Script:Author) Cyan
    UI ("Version: {0} | License: {1}" -f $Script:Version,$Script:License) Cyan
    UI ("Project: {0}" -f $Script:ProjectURL) DarkCyan
    UI ""
    Say "SELF" Green
    Say "AUDIT" White
    Say "BACKUP" White
    UI ""
    Say "RECO" Green
    Say "COMP" White
    Say "BS" White
    Say "NET" White
    Say "STORE" White
    Say "BG" White
    UI ""
    Say "LAB" White
    Say "CLEAN" White
    Say "BENCH" White
    Say "VERIFY" White
    Say "RESTORE" Yellow
    Say "LANG" White
    Say "EXIT" Red
    UI ""

    $choice=Read-Host "KXM >"
    if ($choice -eq "1") { Self-Test }
    elseif ($choice -eq "2") { Audit }
    elseif ($choice -eq "3") { Backup-Center }
    elseif ($choice -eq "4") { Recommended }
    elseif ($choice -eq "5") { Competitive }
    elseif ($choice -eq "6") { Ensure-Baseline;Header "BLUESTACKS MODE" "وضع BlueStacks" "MODE BLUESTACKS";Apply-BlueStacks;Wait-Key }
    elseif ($choice -eq "7") { Ensure-Baseline;Header "NETWORK ENGINE" "محرك الشبكة" "MOTEUR RESEAU";Apply-Network;UI "Network settings applied." Green;Wait-Key }
    elseif ($choice -eq "8") { Ensure-Baseline;Header "STORAGE + MEMORY" "التخزين + الذاكرة" "STOCKAGE + MEMOIRE";Apply-Storage;Wait-Key }
    elseif ($choice -eq "9") { Ensure-Baseline;Header "BACKGROUND CUT" "تقليل الخلفية" "TACHES DE FOND";Apply-Background;Wait-Key }
    elseif ($choice -eq "A" -or $choice -eq "a") {
        Ensure-Baseline
        Header "EXPERIMENTAL LAB" "المختبر التجريبي" "LABORATOIRE EXPERIMENTAL"
        UI (T "One experiment at a time. Reboot and benchmark after each." "تجربة واحدة في كل مرة. أعد التشغيل واختبر بعد كل واحدة." "Une experience a la fois. Redemarrez et mesurez.") Yellow
        $q=T "Force HAGS ON?" "فرض HAGS ON؟" "Forcer HAGS ON ?"
        if (Ask-YesNo $q) { Reg-Dword "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2 }
        $q=T "Disable MPO as a stutter/flicker workaround?" "تعطيل MPO كحل للتقطيع/الوميض؟" "Desactiver MPO comme correctif ?"
        if (Ask-YesNo $q) { Reg-Dword "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 }
        $q=T "Disable Dynamic Tick?" "تعطيل Dynamic Tick؟" "Desactiver Dynamic Tick ?"
        if (Ask-YesNo $q) { bcdedit /set disabledynamictick yes | Out-Null }
        $q=T "Set TSC sync policy to Enhanced?" "ضبط TSC sync على Enhanced؟" "Regler tscsyncpolicy sur Enhanced ?"
        if (Ask-YesNo $q) { bcdedit /set tscsyncpolicy Enhanced | Out-Null }
        $q=T "Disable VBS/HVCI?" "تعطيل VBS/HVCI؟" "Desactiver VBS/HVCI ?"
        if (Ask-YesNo $q) {
            Reg-Dword "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" "EnableVirtualizationBasedSecurity" 0
            Reg-Dword "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" "RequirePlatformSecurityFeatures" 0
            Reg-Dword "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags" 0
        }
        UI (T "MSI mode, forced HPET and pagefile disabling are excluded." "تم استبعاد MSI وHPET وتعطيل Pagefile." "MSI, HPET forces et desactivation du Pagefile sont exclus.") DarkYellow
        Wait-Key
    }
    elseif ($choice -eq "B" -or $choice -eq "b") {
        Ensure-Baseline
        Header "CLEAN + PREPARE" "تنظيف وتجهيز" "NETTOYER + PREPARER"
        foreach ($dir in @($env:TEMP,(Join-Path $env:LOCALAPPDATA "Temp"),"C:\Windows\Temp")) {
            if (Test-Path $dir) { Remove-Item -LiteralPath (Join-Path $dir "*") -Recurse -Force -ErrorAction SilentlyContinue }
        }
        ipconfig /flushdns | Out-Null
        UI (T "Cleanup complete. Personal files are not targeted." "اكتمل التنظيف. لا يتم استهداف ملفاتك الشخصية." "Nettoyage termine. Les fichiers personnels ne sont pas cibles.") Green
        Wait-Key
    }
    elseif ($choice -eq "C" -or $choice -eq "c") {
        Header "BENCHMARK" "Benchmark" "Benchmark"
        $stamp=Get-Date -Format "yyyyMMdd_HHmmss"
        $out=Join-Path $Script:BenchRoot ("KXM_"+$stamp+".txt")
        $h=Get-Hardware
        $r=Get-Recommendation $h
        @(
            "KXM BLUEFIRE v$Script:Version",
            "Timestamp: $(Get-Date)",
            "CPU: $($h.CPU)",
            "Cores/Threads: $($h.Cores)/$($h.Threads)",
            "RAM GB: $($h.RAMGB)",
            "GPU: $($h.GPU)",
            "Recommended BlueStacks: $($r.BlueStacksCores) cores / $($r.BlueStacksRAM) GB",
            "Power: $((powercfg /getactivescheme) -join ' ')"
        ) | Set-Content -LiteralPath $out -Encoding UTF8
        UI (T "Benchmark saved:" "تم حفظ Benchmark:" "Benchmark enregistre :") Green
        UI $out White
        Wait-Key
    }
    elseif ($choice -eq "D" -or $choice -eq "d") {
        Header "VERIFY" "التحقق" "VERIFICATION"
        $mm="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $games="$mm\Tasks\Games"
        UI ("Power: {0}" -f ((powercfg /getactivescheme) -join " ")) White
        UI ("SystemResponsiveness: {0}" -f (Get-ItemProperty $mm -ErrorAction SilentlyContinue).SystemResponsiveness) White
        UI ("NetworkThrottlingIndex: {0}" -f (Get-ItemProperty $mm -ErrorAction SilentlyContinue).NetworkThrottlingIndex) White
        UI ("Games GPU Priority: {0}" -f (Get-ItemProperty $games -ErrorAction SilentlyContinue)."GPU Priority") White
        UI ("Win32PrioritySeparation: {0}" -f (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ErrorAction SilentlyContinue).Win32PrioritySeparation) White
        try { $s=Get-Service SysMain;UI ("SysMain: {0} | {1}" -f $s.Status,$s.StartType) White } catch {}
        Wait-Key
    }
    elseif ($choice -eq "R" -or $choice -eq "r") { Restore-Baseline }
    elseif ($choice -eq "L" -or $choice -eq "l") { Set-Language }
    elseif ($choice -eq "X" -or $choice -eq "x") { Log-Message "Exited.";break }
}

# ---------------------------------------------------------------------------
# Supporting actions are defined here as simple functions to keep PowerShell
# 5.1 parsing straightforward.
# ---------------------------------------------------------------------------
function Apply-Background {
    $tasks=@(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\Feedback\Siuf\DmClient"
    )
    $q=T "Disable selected telemetry/feedback tasks?" "تعطيل بعض مهام Telemetry/Feedback؟" "Desactiver certaines taches Telemetry/Feedback ?"
    if (Ask-YesNo $q) {
        foreach ($task in $tasks) {
            try {
                $name=$task.Substring($task.LastIndexOf("\")+1)
                $path=$task.Substring(0,$task.LastIndexOf("\")+1)
                Disable-ScheduledTask -TaskName $name -TaskPath $path -ErrorAction SilentlyContinue | Out-Null
            } catch {}
        }
    }
}

function Apply-Storage {
    $h=Get-Hardware
    if ($h.HasSSD) {
        try { Optimize-Volume -DriveLetter C -ReTrim -ErrorAction Stop | Out-Null;UI "ReTrim complete." Green } catch { UI "ReTrim unavailable." DarkYellow }
    } else { UI (T "No SSD detected; ReTrim skipped." "لم يتم اكتشاف SSD؛ تم تجاوز ReTrim." "Aucun SSD detecte; ReTrim ignore.") DarkYellow }
    $q=T "Apply NTFS last-access + 8.3 creation optimization?" "تطبيق تحسينات NTFS الخاصة بـLast Access و8.3؟" "Appliquer les optimisations NTFS Last Access + 8.3 ?"
    if (Ask-YesNo $q) {
        fsutil behavior set disablelastaccess 1 | Out-Null
        fsutil behavior set disable8dot3 1 | Out-Null
    }
}

function Apply-Network { 
    netsh int tcp set global rss=enabled | Out-Null
    netsh int tcp set global autotuninglevel=normal | Out-Null
    Reg-Dword "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295
    try {
        foreach ($nic in @(Get-NetAdapter -Physical | Where-Object {$_.Status -eq "Up"})) {
            Disable-NetAdapterPowerManagement -Name $nic.Name -ErrorAction SilentlyContinue
            $guid=$nic.InterfaceGuid.ToString()
            $path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{$guid}"
            Reg-Dword $path "TCPNoDelay" 1
            Reg-Dword $path "TcpAckFrequency" 1
        }
    } catch {}
}

function Apply-CPU { 
    $mm="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    $games="$mm\Tasks\Games"
    Reg-Dword $mm "SystemResponsiveness" 0
    Reg-Dword $mm "NetworkThrottlingIndex" 4294967295
    Reg-Dword $games "GPU Priority" 8
    Reg-Dword $games "Priority" 6
    Reg-String $games "Scheduling Category" "High"
    Reg-String $games "SFIO Priority" "High"
    Reg-Dword "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38
    Reg-Dword "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVE 0 | Out-Null
}

function Apply-Base {
    powercfg /setactive SCHEME_MIN | Out-Null
    Reg-Dword "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    Reg-Dword "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1
    Reg-Dword "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
    Reg-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Reg-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AudioCaptureEnabled" 0
    Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseSpeed -Value "0" -Force
    Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseThreshold1 -Value "0" -Force
    Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseThreshold2 -Value "0" -Force
    Reg-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
    Reg-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0
    Reg-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0
    try { Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue } catch {}
}

function Apply-BlueStacks { 
    $paths=@(
        "$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe",
        "$env:ProgramFiles\BlueStacks_nxt5\HD-Player.exe",
        "${env:ProgramFiles(x86)}\BlueStacks_nxt\HD-Player.exe",
        "${env:ProgramFiles(x86)}\BlueStacks_nxt5\HD-Player.exe"
    )
    $bs=$null
    foreach ($p in $paths) { if ($p -and (Test-Path $p)) { $bs=$p;break } }
    if ($null -eq $bs) { UI "BlueStacks was not found in common paths." Yellow;return }
    $h=Get-Hardware
    $r=Get-Recommendation $h
    UI ("Detected: {0}" -f $bs) Cyan
    UI ("Recommended: {0} cores / {1} GB RAM" -f $r.BlueStacksCores,$r.BlueStacksRAM) Green
    Reg-String "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" $bs "GpuPreference=2;"
    foreach ($exe in @("HD-Player.exe","Bluestacks.exe","HD-Service.exe","HD-Agent.exe","BstkSVC.exe")) {
        Reg-Dword ("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\{0}\PerfOptions" -f $exe) "CpuPriorityClass" 3
    }
    $proc=Get-Process -Name "HD-Player" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) { try { $proc.PriorityClass="AboveNormal" } catch {} }
}

function Say { 
    param([string]$Key,[ConsoleColor]$Color=[ConsoleColor]::Gray)
    $m=@{
        SELF=@("1. Self-Test              Read-only compatibility test","1. الفحص الذاتي             اختبار توافق بدون تعديل","1. Auto-test               Test de compatibilite")
        AUDIT=@("2. Hardware Audit         Detect hardware + recommendations","2. فحص العتاد                اكتشاف الجهاز + التوصيات","2. Audit materiel          Detection + recommandations")
        BACKUP=@("3. Backup Center          Original settings / recovery","3. مركز النسخ الاحتياطي     الإعدادات الأصلية / الاستعادة","3. Centre sauvegarde       Reglages initiaux / restauration")
        RECO=@("4. Recommended Profile    Smart hardware-aware profile","4. البروفايل الموصى به      بروفايل ذكي حسب الجهاز","4. Profil recommande      Profil adapte au materiel")
        COMP=@("5. Competitive Profile    Stronger gaming profile","5. بروفايل المنافسة         بروفايل ألعاب أقوى","5. Profil competitif      Profil jeu plus pousse")
        BS=@("6. BlueStacks Mode        Emulator-specific tuning","6. وضع BlueStacks          تحسينات خاصة بالمحاكي","6. Mode BlueStacks         Optimisation de l'emulateur")
        NET=@("7. Network Engine         RSS / TCP / NIC","7. محرك الشبكة              RSS / TCP / NIC","7. Moteur reseau           RSS / TCP / NIC")
        STORE=@("8. Storage + Memory       HDD / SSD aware","8. التخزين + الذاكرة        حسب HDD / SSD","8. Stockage + memoire    Adapte HDD / SSD")
        BG=@("9. Background Cut         Selective background reduction","9. تقليل الخلفية            تقليل انتقائي","9. Taches de fond         Reduction selective")
        LAB=@("A. Experimental Lab       HAGS / MPO / VBS / timers","A. المختبر التجريبي         HAGS / MPO / VBS / timers","A. Laboratoire             HAGS / MPO / VBS / timers")
        CLEAN=@("B. Clean + Prepare        Pre-game cleanup","B. تنظيف وتجهيز             تنظيف قبل اللعب","B. Nettoyer + preparer    Nettoyage avant jeu")
        BENCH=@("C. Benchmark              Before / after snapshot","C. Benchmark                قياس قبل / بعد","C. Benchmark              Mesure avant / apres")
        VERIFY=@("D. Verify                 Verify current state","D. تحقق                     التحقق من الحالة الحالية","D. Verification           Verifier l'etat")
        RESTORE=@("R. Restore                 Restore original pre-KXM state","R. استعادة                 إرجاع الحالة الأصلية قبل KXM","R. Restaurer              Restaurer l'etat initial")
        LANG=@("L. Language               English / العربية / Français","L. اللغة                   English / العربية / Français","L. Langue                 English / العربية / Français")
        EXIT=@("X. Exit","X. خروج","X. Quitter")
    }
    $index=0
    if ($Script:Lang -eq "AR") { $index=1 }
    elseif ($Script:Lang -eq "FR") { $index=2 }
    UI $m[$Key][$index] $Color
}
'''