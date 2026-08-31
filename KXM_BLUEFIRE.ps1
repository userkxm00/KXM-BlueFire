# KXM BLUEFIRE v26
# Windows PowerShell 5.1 + WinForms.
# Source is ASCII-only for parser stability. Localized strings are in KXM_LANG.json.
# Recovery-first: baseline before changes, deterministic restore, truthful diagnostics.

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Script:Version = "26.0"
$Script:Root = Join-Path $env:ProgramData "KXM\BlueFire"
$Script:BackupRoot = Join-Path $Script:Root "Backups"
$Script:SessionRoot = Join-Path $Script:Root "Sessions"
$Script:CommunityRoot = Join-Path $Script:Root "Community"
$Script:TelemetryRoot = Join-Path $Script:Root "Telemetry"
$Script:LogRoot = Join-Path $Script:Root "Logs"
$Script:Pointer = Join-Path $Script:Root "CURRENT_BASELINE.txt"
$Script:SessionFile = Join-Path $Script:SessionRoot "ACTIVE_SESSION.xml"
$Script:LastSession = Join-Path $Script:SessionRoot "LAST_SESSION.xml"
$Script:PrefsFile = Join-Path $Script:Root "preferences.json"
$Script:LogFile = Join-Path $Script:LogRoot "KXM.log"
$Script:LangFile = Join-Path $PSScriptRoot "KXM_LANG.json"
$Script:TelemetryModule = Join-Path $PSScriptRoot "KXM_TELEMETRY.ps1"
$Script:TelemetryRoot = Join-Path $Script:Root "Telemetry"
$Script:KxmPowerMarker = Join-Path $Script:Root "KXM_POWER_GUID.txt"
$Script:TestMode = [string]$env:KXM_TEST_MODE -eq "1"
$Script:TelemetryLoaded = $false

foreach ($d in @($Script:Root,$Script:BackupRoot,$Script:SessionRoot,$Script:CommunityRoot,$Script:TelemetryRoot,$Script:LogRoot)) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $Script:LangFile)) {
    throw "Missing KXM_LANG.json"
}
$Script:TX = Get-Content -LiteralPath $Script:LangFile -Raw -Encoding UTF8 | ConvertFrom-Json
$Script:Lang = "en"
$Script:Preferences = [ordered]@{
    Language = "en"
    CommunitySharing = $false
    CommunityEndpoint = ""
    Profile = "Free Fire"
}
if (Test-Path -LiteralPath $Script:PrefsFile) {
    try {
        $loaded = Get-Content -LiteralPath $Script:PrefsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($loaded) {
            $Script:Preferences = $loaded
            if ($loaded.Language) {
                $Script:Lang = [string]$loaded.Language
            }
        }
    } catch {
        Log "Preferences file could not be read; using defaults."
    }
}

function Save-Prefs {
    $Script:Preferences | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Script:PrefsFile -Encoding UTF8
}

function T([string]$key) {
    $set = $Script:TX.PSObject.Properties[$Script:Lang].Value
    if ($set) {
        $p = $set.PSObject.Properties[$key]
        if ($p) {
            return [string]$p.Value
        }
    }
    $en = $Script:TX.PSObject.Properties["en"].Value
    if ($en) {
        $fallback = $en.PSObject.Properties[$key]
        if ($fallback) {
            return [string]$fallback.Value
        }
    }
    return $key
}

function Log([string]$text) {
    try {
        Add-Content -LiteralPath $Script:LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$text) -Encoding UTF8
    } catch {}
}

function Show-Error([string]$context,[System.Management.Automation.ErrorRecord]$ErrorRecord) {
    Log ($context + ": " + $ErrorRecord.Exception.Message)
    try {
        [System.Windows.Forms.MessageBox]::Show(($context + "`r`n`r`n" + $ErrorRecord.Exception.Message),"KXM // ERROR",0,16) | Out-Null
    } catch {}
}

function RegSnap([string]$path,[string]$name) {
    $exists = $false
    $value = $null
    $kind = "DWord"
    try {
        $obj = Get-ItemProperty -LiteralPath $path -ErrorAction Stop
        $p = $obj.PSObject.Properties[$name]
        if ($p) {
            $exists = $true
            $value = $p.Value
            if ($value -is [string]) { $kind = "String" }
            elseif ($value -is [int64]) { $kind = "QWord" }
            elseif ($value -is [int32] -or $value -is [uint32]) { $kind = "DWord" }
            elseif ($value -is [string[]]) { $kind = "MultiString" }
            elseif ($value -is [byte[]]) { $kind = "Binary" }
        }
    } catch {}
    return [pscustomobject]@{Path=$path;Name=$name;Exists=$exists;Value=$value;Kind=$kind}
}

function Ensure-RegKey([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -Path $path -Force -ErrorAction Stop | Out-Null
    }
}

function RegSet([string]$path,[string]$name,$value,[string]$kind) {
    Ensure-RegKey $path
    New-ItemProperty -LiteralPath $path -Name $name -PropertyType $kind -Value $value -Force -ErrorAction Stop | Out-Null
}

function RestoreReg($entry) {
    if ($entry.Exists) {
        switch ([string]$entry.Kind) {
            "String" { RegSet $entry.Path $entry.Name ([string]$entry.Value) "String" }
            "QWord" { RegSet $entry.Path $entry.Name ([int64]$entry.Value) "QWord" }
            "MultiString" { RegSet $entry.Path $entry.Name ([string[]]$entry.Value) "MultiString" }
            "Binary" { RegSet $entry.Path $entry.Name ([byte[]]$entry.Value) "Binary" }
            default { RegSet $entry.Path $entry.Name ([int64]$entry.Value) "DWord" }
        }
    } else {
        if (Test-Path -LiteralPath $entry.Path) {
            Remove-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
        }
    }
}

function DiskInfo {
    $hdd = $false
    $ssd = $false
    $kind = "Unknown"
    try {
        foreach ($d in @(Get-PhysicalDisk -ErrorAction Stop)) {
            $m = [string]$d.MediaType
            if ($m -match "HDD") { $hdd = $true }
            if ($m -match "SSD") { $ssd = $true }
        }
    } catch {}
    if (-not $hdd -and -not $ssd) {
        try {
            foreach ($d in @(Get-CimInstance Win32_DiskDrive -ErrorAction Stop)) {
                $m = ([string]$d.Model + " " + [string]$d.MediaType + " " + [string]$d.InterfaceType)
                if ($m -match "SSD|Solid State|NVMe") { $ssd = $true }
                elseif ($m -match "HDD|Hard Disk") { $hdd = $true }
            }
        } catch {}
    }
    if ($ssd -and $hdd) { $kind = "Mixed" }
    elseif ($ssd) { $kind = "SSD" }
    elseif ($hdd) { $kind = "HDD" }
    return [pscustomobject]@{ HDD=$hdd; SSD=$ssd; Kind=$kind }
}

function Hardware {
    $cpu = $null
    $cs = $null
    $gpus = @()
    try { $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1 } catch {}
    try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop } catch {}
    try { $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction Stop) } catch {}
    $d = DiskInfo
    $ram = 0
    if ($cs) { $ram = [math]::Round($cs.TotalPhysicalMemory / 1GB,1) }
    $gpu = "Unknown"
    if ($gpus.Count -gt 0) { $gpu = ($gpus | ForEach-Object { [string]$_.Name }) -join " | " }
    $virt = $false
    if ($cpu) { $virt = [bool]$cpu.VirtualizationFirmwareEnabled }
    return [pscustomobject]@{
        CPU = if ($cpu) { [string]$cpu.Name } else { "Unknown" }
        Cores = if ($cpu) { [int]$cpu.NumberOfCores } else { 0 }
        Threads = if ($cpu) { [int]$cpu.NumberOfLogicalProcessors } else { 0 }
        RAM = $ram
        GPU = $gpu
        HDD = $d.HDD
        SSD = $d.SSD
        Storage = $d.Kind
        Virtualization = $virt
    }
}

function Get-RefreshRate {
    try {
        $v = Get-CimInstance Win32_VideoController -ErrorAction Stop | Select-Object -First 1
        if ($v.CurrentRefreshRate) { return [int]$v.CurrentRefreshRate }
    } catch {}
    return 0
}

function PendingReboot {
    $a = Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    $b = Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    $c = $false
    try {
        $p = Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -ErrorAction Stop
        $c = $null -ne $p.PendingFileRenameOperations
    } catch {}
    return ($a -or $b -or $c)
}

function DriverHealth {
    $items = @()
    try {
        foreach ($d in @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { $_.DeviceClass -eq "DISPLAY" })) {
            $items += ,([pscustomobject]@{Name=[string]$d.DeviceName;Version=[string]$d.DriverVersion;Date=[string]$d.DriverDate;Provider=[string]$d.DriverProviderName})
        }
    } catch {}
    return $items
}

function ThermalStatus {
    $readings = @()
    try {
        foreach ($z in @(Get-CimInstance -Namespace "root\wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop)) {
            if ($z.CurrentTemperature -gt 0) {
                $c = [math]::Round(($z.CurrentTemperature / 10) - 273.15,1)
                $readings += ,([pscustomobject]@{C=$c})
            }
        }
    } catch {}
    if ($readings.Count -eq 0) { return [pscustomobject]@{Status="UNKNOWN";MaxC=$null} }
    $max = ($readings | Measure-Object -Property C -Maximum).Maximum
    $status = "SAFE"
    if ($max -ge 85) { $status = "WARNING" }
    if ($max -ge 95) { $status = "THROTTLING RISK" }
    return [pscustomobject]@{Status=$status;MaxC=$max}
}

function FindBlueStacks {
    $paths = @(
        "$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe",
        "$env:ProgramFiles\BlueStacks_nxt5\HD-Player.exe",
        "${env:ProgramFiles(x86)}\BlueStacks_nxt\HD-Player.exe",
        "${env:ProgramFiles(x86)}\BlueStacks_nxt5\HD-Player.exe"
    )
    foreach ($p in $paths) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    return $null
}

function BlueStacksVersion {
    $p = FindBlueStacks
    if (-not $p) { return $null }
    try { return (Get-Item -LiteralPath $p -ErrorAction Stop).VersionInfo.ProductVersion } catch { return $null }
}

function Recommendation($h) {
    $cores = 1
    if ($h.Cores -ge 4) { $cores = 4 }
    elseif ($h.Cores -ge 2) { $cores = 2 }
    if ($h.Cores -ge 8) { $cores = 6 }

    $ram = 2
    if ($h.RAM -ge 6) { $ram = 4 }
    if ($h.RAM -ge 12) { $ram = 6 }
    if ($h.RAM -ge 24) { $ram = 8 }

    $profile = "Conservative"
    if ($h.Cores -ge 4 -and $h.RAM -ge 8) { $profile = "Balanced" }
    if ($h.Cores -ge 6 -and $h.RAM -ge 12 -and $h.SSD) { $profile = "Competitive" }

    $sys = "LEAVE DEFAULT"
    if ($h.HDD -or $h.RAM -le 8) { $sys = "KEEP AUTO" }

    $reason = New-Object System.Collections.Generic.List[string]
    [void]$reason.Add(("CPU: {0} cores / {1} threads" -f $h.Cores,$h.Threads))
    [void]$reason.Add(("RAM: {0} GB physical" -f $h.RAM))
    [void]$reason.Add(("Storage: {0}" -f $h.Storage))
    [void]$reason.Add(("SysMain: {0}" -f $sys))

    return [pscustomobject]@{
        Name="Free Fire";Profile=$profile;Cores=$cores;RAM=$ram;Power="High Performance";FPSTarget=120;FPSCeiling=240;SysMain=$sys;Reason=@($reason)
    }
}

function Get-ActivePowerPlanGuid {
    try {
        $line = (powercfg /getactivescheme | Out-String)
        $m = [regex]::Match($line,"([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})")
        if ($m.Success) { return $m.Groups[1].Value }
    } catch {}
    return $null
}

function Baseline {
    if (Test-Path -LiteralPath $Script:Pointer) {
        $d = (Get-Content -LiteralPath $Script:Pointer -Raw -Encoding UTF8).Trim()
        if ($d -and (Test-Path -LiteralPath (Join-Path $d "Baseline.xml"))) { return $d }
    }

    $d = Join-Path $Script:BackupRoot (Get-Date -Format "yyyyMMdd_HHmmss")
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    $st = [ordered]@{
        Schema=2;Version=$Script:Version;Created=(Get-Date).ToString("o");PowerPlanGuid=(Get-ActivePowerPlanGuid)
        Registry=New-Object System.Collections.ArrayList;Services=New-Object System.Collections.ArrayList
    }

    $targets = @(
        @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile","SystemResponsiveness"),
        @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile","NetworkThrottlingIndex"),
        @("HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl","Win32PrioritySeparation"),
        @("HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling","PowerThrottlingOff"),
        @("HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers","HwSchMode"),
        @("HKLM:\SOFTWARE\Microsoft\Windows\Dwm","OverlayTestMode"),
        @("HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR","AppCaptureEnabled"),
        @("HKCU:\System\GameConfigStore","GameDVR_Enabled"),
        @("HKCU:\Software\Microsoft\GameBar","AutoGameModeEnabled"),
        @("HKCU:\Software\Microsoft\DirectX\UserGpuPreferences",(FindBlueStacks))
    )

    foreach ($x in $targets) {
        if ($x[1]) { [void]$st.Registry.Add((RegSnap $x[0] $x[1])) }
    }

    foreach ($svcName in @("SysMain")) {
        try {
            $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $svcName) -ErrorAction Stop
            $state = (Get-Service -Name $svcName -ErrorAction Stop).Status.ToString()
            [void]$st.Services.Add([pscustomobject]@{Name=$svcName;StartMode=[string]$svc.StartMode;State=$state})
        } catch { Log ("Service baseline skipped: " + $svcName) }
    }

    try {
        $st | Export-Clixml -LiteralPath (Join-Path $d "Baseline.xml")
        powercfg /list | Out-File -LiteralPath (Join-Path $d "PowerPlans.txt") -Encoding UTF8
        bcdedit /enum all | Out-File -LiteralPath (Join-Path $d "BCD.txt") -Encoding UTF8
        (Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture) | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $d "Windows.json") -Encoding UTF8
        Set-Content -LiteralPath $Script:Pointer -Value $d -Encoding UTF8
        Log ("Baseline created: " + $d)
        return $d
    } catch {
        Log ("Baseline creation failed: " + $_.Exception.Message)
        throw
    }
}

function EnsureBaseline { return (Baseline) }

function Get-ServiceStartupType([string]$startMode) {
    switch ($startMode) {
        "Auto" { return "Automatic" }
        "Manual" { return "Manual" }
        "Disabled" { return "Disabled" }
        default { return $null }
    }
}

function Try-CreateSystemRestorePoint([string]$baselineDir) {
    $marker = Join-Path $baselineDir "SYSTEM_RESTORE_POINT.txt"
    if (Test-Path -LiteralPath $marker) { return "ALREADY CHECKED" }
    try {
        $sr = Get-Service -Name srservice -ErrorAction Stop
        if ($sr.StartType -eq "Disabled") {
            Set-Content -LiteralPath $marker -Value "Unavailable: System Restore service disabled." -Encoding UTF8
            return "UNAVAILABLE"
        }
        Checkpoint-Computer -Description "KXM BlueFire pre-change" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Set-Content -LiteralPath $marker -Value ("Created: " + (Get-Date -Format o)) -Encoding UTF8
        return "CREATED"
    } catch {
        Set-Content -LiteralPath $marker -Value ("Unavailable: " + $_.Exception.Message) -Encoding UTF8
        Log ("System restore point unavailable: " + $_.Exception.Message)
        return "UNAVAILABLE"
    }
}

function RestoreBaseline {
    if (-not (Test-Path -LiteralPath $Script:Pointer)) {
        return [pscustomobject]@{Success=$false;Message="No KXM baseline exists."}
    }
    $d = (Get-Content -LiteralPath $Script:Pointer -Raw -Encoding UTF8).Trim()
    $file = Join-Path $d "Baseline.xml"
    if (-not $d -or -not (Test-Path -LiteralPath $file)) {
        return [pscustomobject]@{Success=$false;Message="Baseline is missing or invalid."}
    }
    try {
        $st = Import-Clixml -LiteralPath $file -ErrorAction Stop
        if (-not $st.Registry -or $st.Schema -lt 2) {
            return [pscustomobject]@{Success=$false;Message="Baseline format is not supported."}
        }
        foreach ($entry in @($st.Registry)) { RestoreReg $entry }
        foreach ($svc in @($st.Services)) {
            try {
                $startup = Get-ServiceStartupType ([string]$svc.StartMode)
                if ($startup) { Set-Service -Name ([string]$svc.Name) -StartupType $startup -ErrorAction Stop }
                $current = Get-Service -Name ([string]$svc.Name) -ErrorAction Stop
                if ([string]$svc.State -eq "Running" -and $current.Status -ne "Running") { Start-Service -Name ([string]$svc.Name) -ErrorAction Stop }
                elseif ([string]$svc.State -ne "Running" -and $current.Status -eq "Running") { Stop-Service -Name ([string]$svc.Name) -Force -ErrorAction Stop }
            } catch { Log ("Service restore failed: " + [string]$svc.Name + " / " + $_.Exception.Message) }
        }
        if ($st.PowerPlanGuid -and ((powercfg /list) -match [regex]::Escape([string]$st.PowerPlanGuid))) { powercfg /setactive ([string]$st.PowerPlanGuid) | Out-Null }
        if (Test-Path -LiteralPath $Script:KxmPowerMarker) {
            $kxmGuid = (Get-Content -LiteralPath $Script:KxmPowerMarker -Raw -Encoding ASCII).Trim()
            if ($kxmGuid -and $kxmGuid -ne [string]$st.PowerPlanGuid) { powercfg /delete $kxmGuid | Out-Null }
            Remove-Item -LiteralPath $Script:KxmPowerMarker -Force -ErrorAction SilentlyContinue
        }
        Set-Content -LiteralPath (Join-Path $d "RESTORED.txt") -Value ("Restored: " + (Get-Date -Format o)) -Encoding UTF8
        Log ("Baseline restored: " + $d)
        return [pscustomobject]@{Success=$true;Message=("RESTORE COMPLETE.`r`n`r`nBaseline: " + $d + "`r`n`r`nReboot before benchmark testing.")}
    } catch {
        Log ("Restore failed: " + $_.Exception.Message)
        return [pscustomobject]@{Success=$false;Message=("RESTORE FAILED.`r`n`r`n" + $_.Exception.Message)}
    }
}

function CleanSafe {
    $deleted = 0
    foreach ($d in @($env:TEMP,(Join-Path $env:LOCALAPPDATA "Temp"),(Join-Path $env:WINDIR "Temp"))) {
        if (Test-Path -LiteralPath $d) {
            try {
                foreach ($item in @(Get-ChildItem -LiteralPath $d -Force -ErrorAction SilentlyContinue)) {
                    try { Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop; $deleted++ } catch {}
                }
            } catch {}
        }
    }
    try { ipconfig /flushdns | Out-Null } catch {}
    return $deleted
}

function MaxFPSPlan {
    if (Test-Path -LiteralPath $Script:KxmPowerMarker) {
        $g = (Get-Content -LiteralPath $Script:KxmPowerMarker -Raw -Encoding ASCII).Trim()
        if ($g -and ((powercfg /list) -match [regex]::Escape($g))) { return $g }
    }
    $src = Get-ActivePowerPlanGuid
    if (-not $src) { return $null }
    $out = powercfg /duplicatescheme $src 2>&1
    $m = [regex]::Match(($out | Out-String),"([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})")
    if (-not $m.Success) { return $null }
    $g = $m.Groups[1].Value
    powercfg /changename $g "KXM Maximum FPS" "KXM gaming session plan" | Out-Null
    powercfg /setacvalueindex $g SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
    powercfg /setacvalueindex $g SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg /setacvalueindex $g SUB_USB USBSELECTIVE 0 | Out-Null
    Set-Content -LiteralPath $Script:KxmPowerMarker -Value $g -Encoding ASCII
    return $g
}

function ActivateMaxFPS {
    $g = MaxFPSPlan
    if ($g) { powercfg /setactive $g | Out-Null; return ($g -eq (Get-ActivePowerPlanGuid)) }
    return $false
}

function Get-ProcessPrioritySnapshot {
    $p = Get-Process -Name HD-Player -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $p) { return [pscustomobject]@{Running=$false;Id=$null;Priority="NotRunning"} }
    $priority = "Normal"
    try { $priority = $p.PriorityClass.ToString() } catch {}
    return [pscustomobject]@{Running=$true;Id=$p.Id;Priority=$priority}
}

function Restore-ProcessPriority($snapshot) {
    if (-not $snapshot -or -not $snapshot.Running -or -not $snapshot.Id) { return }
    try {
        $p = Get-Process -Id ([int]$snapshot.Id) -ErrorAction Stop
        if ($snapshot.Priority -in @("Normal","Idle","High","RealTime","BelowNormal","AboveNormal")) {
            $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]$snapshot.Priority
        }
    } catch { Log ("Process priority restore skipped: " + $_.Exception.Message) }
}

function StartSession {
    $baselineDir = EnsureBaseline
    if (Test-Path -LiteralPath $Script:SessionFile) { return "GAME SESSION ALREADY ACTIVE." }
    $snapshot = [ordered]@{Schema=2;Started=(Get-Date).ToString("o");PowerPlanGuid=(Get-ActivePowerPlanGuid);Process=(Get-ProcessPrioritySnapshot);RestorePoint=(Try-CreateSystemRestorePoint $baselineDir)}
    $snapshot | Export-Clixml -LiteralPath $Script:SessionFile
    $deleted = CleanSafe
    $plan = $false
    try { $plan = ActivateMaxFPS } catch { Log ("Max FPS plan failed: " + $_.Exception.Message) }
    $p = Get-Process -Name HD-Player -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) { try { $p.PriorityClass = "AboveNormal" } catch {} }
    Log "GAME READY session started"
    return ("GAME READY ACTIVE.`r`n`r`nTemp items removed: {0}`r`nMaximum FPS plan verified: {1}`r`nBlueStacks running: {2}`r`nSystem Restore point: {3}" -f $deleted,$plan,([bool]$p),$snapshot.RestorePoint)
}

function EndSession {
    if (-not (Test-Path -LiteralPath $Script:SessionFile)) { return "NO ACTIVE SESSION." }
    try {
        $s = Import-Clixml -LiteralPath $Script:SessionFile -ErrorAction Stop
        if ($s.PowerPlanGuid -and ((powercfg /list) -match [regex]::Escape([string]$s.PowerPlanGuid))) { powercfg /setactive ([string]$s.PowerPlanGuid) | Out-Null }
        Restore-ProcessPriority $s.Process
        $s | Export-Clixml -LiteralPath $Script:LastSession
        Remove-Item -LiteralPath $Script:SessionFile -Force
        Log "GAME READY session ended"
        return "SESSION ENDED.`r`n`r`nOriginal power plan restored.`r`nOriginal BlueStacks process priority restored when available."
    } catch {
        Log ("End session failed: " + $_.Exception.Message)
        return ("SESSION END FAILED.`r`n`r`n" + $_.Exception.Message)
    }
}

function UndoLastSession {
    if (-not (Test-Path -LiteralPath $Script:LastSession)) { return "NO LAST SESSION SNAPSHOT." }
    try {
        $s = Import-Clixml -LiteralPath $Script:LastSession -ErrorAction Stop
        if ($s.PowerPlanGuid -and ((powercfg /list) -match [regex]::Escape([string]$s.PowerPlanGuid))) { powercfg /setactive ([string]$s.PowerPlanGuid) | Out-Null }
        Restore-ProcessPriority $s.Process
        Remove-Item -LiteralPath $Script:LastSession -Force
        Log "Last session undone"
        return "LAST SESSION UNDONE.`r`n`r`nOriginal session power and process state restored when available."
    } catch {
        Log ("Undo last session failed: " + $_.Exception.Message)
        return ("UNDO FAILED.`r`n`r`n" + $_.Exception.Message)
    }
}

function ApplySafeProfile($h,$p) {
    $baselineDir = EnsureBaseline
    $restorePoint = Try-CreateSystemRestorePoint $baselineDir
    powercfg /setactive SCHEME_MIN | Out-Null
    RegSet "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1 "DWord"
    RegSet "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1 "DWord"
    RegSet "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0 "DWord"
    RegSet "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0 "DWord"
    $mm = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    $g = "$mm\Tasks\Games"
    RegSet $mm "SystemResponsiveness" 0 "DWord"
    RegSet $mm "NetworkThrottlingIndex" 4294967295 "DWord"
    RegSet $g "GPU Priority" 8 "DWord"
    RegSet $g "Priority" 6 "DWord"
    RegSet "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38 "DWord"
    RegSet "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1 "DWord"
    if ($p.SysMain -eq "KEEP AUTO") {
        try { Set-Service -Name SysMain -StartupType Automatic -ErrorAction Stop; Start-Service -Name SysMain -ErrorAction SilentlyContinue } catch { Log ("SysMain safe policy could not be enforced: " + $_.Exception.Message) }
    }
    $bs = FindBlueStacks
    if ($bs) { RegSet "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" $bs "GpuPreference=2;" "String" }
    Log ("Safe profile applied: {0}, BS CPU {1}, BS RAM {2}" -f $p.Profile,$p.Cores,$p.RAM)
    return [pscustomobject]@{Profile=$p.Profile;Cores=$p.Cores;RAM=$p.RAM;Power=$p.Power;SysMain=$p.SysMain;RestorePoint=$restorePoint}
}

function Preview($h,$p) {
    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add("KXM v26 SMART PREVIEW")
    [void]$lines.Add("")
    [void]$lines.Add(("Detected: {0} cores / {1} threads / {2} GB RAM / {3}" -f $h.Cores,$h.Threads,$h.RAM,$h.Storage))
    [void]$lines.Add(("Recommended profile: {0}" -f $p.Profile))
    [void]$lines.Add("")
    [void]$lines.Add(("+ BlueStacks CPU allocation: {0} cores" -f $p.Cores))
    [void]$lines.Add(("+ BlueStacks memory allocation: {0} GB" -f $p.RAM))
    [void]$lines.Add(("+ Power plan: {0}" -f $p.Power))
    [void]$lines.Add(("+ SysMain policy: {0}" -f $p.SysMain))
    [void]$lines.Add("")
    [void]$lines.Add(("FPS guidance: {0} target / {1} optional application ceiling" -f $p.FPSTarget,$p.FPSCeiling))
    [void]$lines.Add("These FPS values are profile guidance, not a guaranteed result.")
    [void]$lines.Add("")
    [void]$lines.Add("- No Defender removal")
    [void]$lines.Add("- No Windows Update disable")
    [void]$lines.Add("- No pagefile disable")
    [void]$lines.Add("- No forced HPET")
    [void]$lines.Add("- No blind MSI mode")
    [void]$lines.Add("- No game file modification")
    [void]$lines.Add("")
    [void]$lines.Add("A baseline and optional System Restore point are created before persistent changes.")
    return ($lines -join "`r`n")
}

function EnsureTelemetryModule {
    if ($Script:TelemetryLoaded) { return $true }
    if (-not (Test-Path -LiteralPath $Script:TelemetryModule)) { return $false }
    try { . $Script:TelemetryModule; $Script:TelemetryLoaded = $true; return $true } catch { Log ("Telemetry module load failed: " + $_.Exception.Message); return $false }
}

function Send-KxmCommunityEvent([string]$name,[hashtable]$data) {
    if (-not [bool]$Script:Preferences.CommunitySharing) { return }
    if (-not (EnsureTelemetryModule)) { return }
    try {
        $h = Hardware
        $bs = FindBlueStacks
        $bv = BlueStacksVersion
        $emulatorName = if ($bs) { "BlueStacks" } else { "NotDetected" }
        $event = New-KxmTelemetryEvent -EventName $name -Hardware $h -Game "Free Fire" -Emulator $emulatorName -Profile ([string]$Script:Preferences.Profile) -EmulatorVersion ([string]$bv) -Changes @() -Success $true
        foreach ($k in $data.Keys) { $event | Add-Member -NotePropertyName $k -NotePropertyValue $data[$k] -Force }
        [void](Queue-KxmTelemetryEvent -Event $event)
        [void](Send-KxmTelemetryQueue)
    } catch { Log ("Community telemetry failed: " + $_.Exception.Message) }
}

function CommunityInsights {
    if (-not (EnsureTelemetryModule)) { return "COMMUNITY INSIGHTS`r`n`r`nTelemetry module is unavailable." }
    try {
        $settings = Get-KxmTelemetrySettings
        if (-not $settings.enabled) { return "COMMUNITY INSIGHTS`r`n`r`nCommunity telemetry is OFF by default.`r`nEnable it explicitly to share anonymized evidence." }
        $insights = Get-KxmCommunityInsights
        if (-not $insights) { return "COMMUNITY INSIGHTS`r`n`r`nNo online aggregate is available yet." }
        if ($insights -is [string]) { return [string]$insights }
        return ($insights | ConvertTo-Json -Depth 8)
    } catch { Log ("Community insights failed: " + $_.Exception.Message); return "COMMUNITY INSIGHTS`r`n`r`nUnavailable." }
}

function Get-DefaultGateway {
    try {
        $r = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction Stop | Sort-Object RouteMetric,InterfaceMetric | Select-Object -First 1
        if ($r -and $r.NextHop) { return [string]$r.NextHop }
    } catch {}
    return $null
}

function Test-KxmLatency {
    $gateway = Get-DefaultGateway
    $targets = @()
    if ($gateway) { $targets += ,$gateway }
    $targets += ,"1.1.1.1"
    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add("NETWORK LATENCY / JITTER")
    [void]$lines.Add("")
    foreach ($target in $targets) {
        try {
            $samples = @(Test-Connection -ComputerName $target -Count 5 -ErrorAction Stop)
            $times = @($samples | ForEach-Object { [double]$_.ResponseTime })
            if ($times.Count -eq 0) { [void]$lines.Add(("{0}: no reply" -f $target)); continue }
            $avg = [math]::Round((($times | Measure-Object -Average).Average),2)
            $min = [math]::Round((($times | Measure-Object -Minimum).Minimum),2)
            $max = [math]::Round((($times | Measure-Object -Maximum).Maximum),2)
            $sum = 0.0
            for ($i=1; $i -lt $times.Count; $i++) { $sum += [math]::Abs($times[$i] - $times[$i-1]) }
            $jitter = if ($times.Count -gt 1) { [math]::Round($sum / ($times.Count - 1),2) } else { 0 }
            [void]$lines.Add(("{0}: avg {1} ms | min {2} | max {3} | jitter {4} ms" -f $target,$avg,$min,$max,$jitter))
        } catch { [void]$lines.Add(("{0}: unavailable" -f $target)) }
    }
    return ($lines -join "`r`n")
}

function Get-FrameTimeToolStatus {
    $cmd = Get-Command presentmon.exe -ErrorAction SilentlyContinue
    if ($cmd) { return "PresentMon detected. Use the Benchmark workflow to collect real frame-time data." }
    return "PresentMon not detected. No FPS or frame-time numbers are invented."
}

function UpdateDrift {
    $mm = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    $items = @()
    $sr = $null; $nt = $null; $gm = $null
    try { $sr = (Get-ItemProperty -LiteralPath $mm -ErrorAction Stop).SystemResponsiveness } catch {}
    try { $nt = (Get-ItemProperty -LiteralPath $mm -ErrorAction Stop).NetworkThrottlingIndex } catch {}
    try { $gm = (Get-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\GameBar" -ErrorAction Stop).AutoGameModeEnabled } catch {}
    $items += ,([pscustomobject]@{Name="SystemResponsiveness";Actual=$sr;Expected="0";Drift=([string]$sr -ne "0")})
    $items += ,([pscustomobject]@{Name="NetworkThrottlingIndex";Actual=$nt;Expected="4294967295";Drift=($null -ne $nt -and [int64]$nt -ne 4294967295)})
    $items += ,([pscustomobject]@{Name="GameMode";Actual=$gm;Expected="1";Drift=([string]$gm -ne "1")})
    return $items
}

function ExportProfile($p) {
    $d = Join-Path $Script:Root "ExportedProfiles"
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    $f = Join-Path $d ("KXM_Profile_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".json")
    [ordered]@{schema=2;version=$Script:Version;created=(Get-Date).ToString("o");name=$p.Name;profile=$p.Profile;bluestacks_cpu=$p.Cores;bluestacks_ram_gb=$p.RAM;power=$p.Power;fps_target=$p.FPSTarget;fps_ceiling=$p.FPSCeiling;sysmain_policy=$p.SysMain} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $f -Encoding UTF8
    return $f
}

function Show-HardwareText($h,$p) {
    return ("HARDWARE AUDIT`r`n`r`nCPU: {0}`r`nCores / Threads: {1} / {2}`r`nRAM: {3} GB`r`nGPU: {4}`r`nStorage: {5}`r`nVirtualization: {6}`r`nRefresh: {7} Hz`r`nBlueStacks: {8}`r`nBlueStacks version: {9}`r`n`r`nRECOMMENDATION`r`nProfile: {10}`r`nBlueStacks CPU: {11} cores`r`nBlueStacks RAM: {12} GB`r`nSysMain: {13}`r`nFPS guidance: {14} target / {15} ceiling" -f $h.CPU,$h.Cores,$h.Threads,$h.RAM,$h.GPU,$h.Storage,$h.Virtualization,(Get-RefreshRate),(FindBlueStacks),(BlueStacksVersion),$p.Profile,$p.Cores,$p.RAM,$p.SysMain,$p.FPSTarget,$p.FPSCeiling)
}

function Show-VerifyText($h,$p) {
    $baseline = $false
    if (Test-Path -LiteralPath $Script:Pointer) {
        $dir = (Get-Content -LiteralPath $Script:Pointer -Raw -Encoding UTF8).Trim()
        $baseline = $dir -and (Test-Path -LiteralPath (Join-Path $dir "Baseline.xml"))
    }
    return ("VERIFY STATE`r`n`r`nBaseline valid: {0}`r`nActive session: {1}`r`nPending reboot: {2}`r`nThermal: {3}`r`nDriver records: {4}`r`nBlueStacks: {5}`r`nBlueStacks version: {6}`r`nRecommended profile: {7}`r`nRecommended CPU / RAM: {8} / {9} GB" -f $baseline,(Test-Path -LiteralPath $Script:SessionFile),(PendingReboot),(ThermalStatus).Status,(DriverHealth).Count,(FindBlueStacks),(BlueStacksVersion),$p.Profile,$p.Cores,$p.RAM)
}

function Start-KxmGui {
    $h = Hardware
    $p = Recommendation $h
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "KXM // BLUEFIRE v26"
    $form.Size = New-Object System.Drawing.Size(1260,840)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(8,11,16)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.Font = New-Object System.Drawing.Font("Segoe UI",10)
    $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false

    $header = New-Object System.Windows.Forms.Label
    $header.Text = "KXM // BLUEFIRE"
    $header.Location = New-Object System.Drawing.Point(36,22)
    $header.Size = New-Object System.Drawing.Size(700,48)
    $header.Font = New-Object System.Drawing.Font("Segoe UI Semibold",25)
    $header.ForeColor = [System.Drawing.Color]::FromArgb(0,230,200)
    $form.Controls.Add($header)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = T "subtitle"
    $sub.Location = New-Object System.Drawing.Point(40,70)
    $sub.Size = New-Object System.Drawing.Size(850,28)
    $sub.ForeColor = [System.Drawing.Color]::Silver
    $form.Controls.Add($sub)

    $status = New-Object System.Windows.Forms.Label
    $status.Text = T "system_ready"
    $status.Location = New-Object System.Drawing.Point(900,28)
    $status.Size = New-Object System.Drawing.Size(300,42)
    $status.TextAlign = "MiddleRight"
    $status.Font = New-Object System.Drawing.Font("Segoe UI Semibold",12)
    $status.ForeColor = [System.Drawing.Color]::FromArgb(120,255,175)
    $form.Controls.Add($status)

    $dash = New-Object System.Windows.Forms.Panel
    $dash.Location = New-Object System.Drawing.Point(32,112)
    $dash.Size = New-Object System.Drawing.Size(1160,112)
    $dash.BackColor = [System.Drawing.Color]::FromArgb(18,23,31)
    $form.Controls.Add($dash)

    $cards = @(
        @("CPU",("{0}C / {1}T" -f $h.Cores,$h.Threads)),
        @("RAM",("$($h.RAM) GB")),
        @("GPU",$h.GPU),
        @("STORAGE",$h.Storage),
        @("FREE FIRE",("$($p.Cores) C / $($p.RAM) GB"))
    )
    $x = 14
    foreach ($c in $cards) {
        $cp = New-Object System.Windows.Forms.Panel
        $cp.Location = New-Object System.Drawing.Point($x,14)
        $cp.Size = New-Object System.Drawing.Size(215,84)
        $cp.BackColor = [System.Drawing.Color]::FromArgb(25,31,41)
        $cl = New-Object System.Windows.Forms.Label
        $cl.Text = "$($c[0])`r`n$($c[1])"
        $cl.Dock = "Fill"
        $cl.TextAlign = "MiddleCenter"
        $cl.ForeColor = [System.Drawing.Color]::White
        $cp.Controls.Add($cl)
        $dash.Controls.Add($cp)
        $x += 225
    }

    $quick = New-Object System.Windows.Forms.GroupBox
    $quick.Text = "  " + (T "quick") + "  "
    $quick.Location = New-Object System.Drawing.Point(32,242)
    $quick.Size = New-Object System.Drawing.Size(1160,122)
    $quick.ForeColor = [System.Drawing.Color]::FromArgb(0,230,200)
    $form.Controls.Add($quick)

    $details = New-Object System.Windows.Forms.TextBox
    $details.Multiline = $true
    $details.ReadOnly = $true
    $details.ScrollBars = "Vertical"
    $details.Location = New-Object System.Drawing.Point(625,394)
    $details.Size = New-Object System.Drawing.Size(567,306)
    $details.BackColor = [System.Drawing.Color]::FromArgb(13,17,23)
    $details.ForeColor = [System.Drawing.Color]::FromArgb(195,245,236)
    $details.Font = New-Object System.Drawing.Font("Consolas",10.5)
    $details.Text = Show-HardwareText $h $p
    $form.Controls.Add($details)

    function Add-QuickButton([string]$text,[int]$xPos,[int]$width,[scriptblock]$action,[System.Drawing.Color]$bg) {
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $text
        $b.Location = New-Object System.Drawing.Point($xPos,30)
        $b.Size = New-Object System.Drawing.Size($width,68)
        $b.Font = New-Object System.Drawing.Font("Segoe UI Semibold",12)
        $b.BackColor = $bg
        $b.ForeColor = [System.Drawing.Color]::White
        $b.FlatStyle = "Flat"
        $b.Add_Click($action)
        $quick.Controls.Add($b)
        return $b
    }

    $ready = Add-QuickButton (T "ready") 18 235 {
        try { $details.Text = StartSession; $status.Text = "GAME SESSION ACTIVE" } catch { Show-Error "GAME READY failed" $_ }
    } ([System.Drawing.Color]::FromArgb(0,126,112))

    $end = Add-QuickButton (T "end") 268 205 {
        try { $details.Text = EndSession; $status.Text = T "system_ready" } catch { Show-Error "End session failed" $_ }
    } ([System.Drawing.Color]::FromArgb(58,47,44))

    $smart = Add-QuickButton (T "smart") 486 220 {
        try {
            $hh = Hardware
            $pp = Recommendation $hh
            $ans = [System.Windows.Forms.MessageBox]::Show((Preview $hh $pp),"KXM // SMART OPTIMIZE",4,48)
            if ($ans -eq [System.Windows.Forms.DialogResult]::OK) {
                $result = ApplySafeProfile $hh $pp
                Send-KxmCommunityEvent "profile_applied" @{profile=$pp.Profile;recommended_cpu=$pp.Cores;recommended_ram=$pp.RAM}
                $details.Text = ("SMART PROFILE APPLIED`r`n`r`nDetected: {0} cores / {1} GB RAM / {2}`r`nProfile: {3}`r`nBlueStacks: {4} cores / {5} GB`r`nPower: {6}`r`nSysMain: {7}`r`nSystem Restore point: {8}" -f $hh.Cores,$hh.RAM,$hh.Storage,$result.Profile,$result.Cores,$result.RAM,$result.Power,$result.SysMain,$result.RestorePoint)
                $status.Text = "OPTIMIZED"
            }
        } catch { Show-Error "Smart Optimize failed" $_ }
    } ([System.Drawing.Color]::FromArgb(34,44,58))

    $restore = Add-QuickButton (T "restore") 721 220 {
        try {
            $ans = [System.Windows.Forms.MessageBox]::Show("Restore the original KXM baseline? This reverses KXM persistent changes captured in the baseline.","KXM // RESTORE",4,48)
            if ($ans -eq [System.Windows.Forms.DialogResult]::OK) {
                $r = RestoreBaseline
                $details.Text = $r.Message
                $status.Text = if($r.Success){"RESTORED"}else{"RESTORE ERROR"}
                if ($r.Success) { Send-KxmCommunityEvent "restore" @{} }
            }
        } catch { Show-Error "Restore failed" $_ }
    } ([System.Drawing.Color]::FromArgb(73,50,47))

    $box = New-Object System.Windows.Forms.GroupBox
    $box.Text = "  " + (T "diag") + "  "
    $box.Location = New-Object System.Drawing.Point(32,394)
    $box.Size = New-Object System.Drawing.Size(570,310)
    $box.ForeColor = [System.Drawing.Color]::FromArgb(0,230,200)
    $form.Controls.Add($box)

    $spec = @(
        @("tool_hardware","h"),@("tool_driver","d"),@("tool_thermal","t"),@("tool_conflict","c"),
        @("tool_update","u"),@("tool_latency","l"),@("tool_bench","b"),@("tool_profile","p"),
        @("tool_community","i"),@("tool_verify","v"),@("tool_dry","y"),@("tool_backup","k")
    )
    $row = 0
    $col = 0
    foreach ($s0 in $spec) {
        $kind = [string]$s0[1]
        $b0 = New-Object System.Windows.Forms.Button
        $b0.Text = T ([string]$s0[0])
        $b0.Location = New-Object System.Drawing.Point((14 + ($col * 180)),(32 + ($row * 66)))
        $b0.Size = New-Object System.Drawing.Size(168,52)
        $b0.BackColor = [System.Drawing.Color]::FromArgb(27,34,44)
        $b0.ForeColor = [System.Drawing.Color]::White
        $b0.FlatStyle = "Flat"
        $handler = {
            param($sender,$eventArgs)
            try {
                switch ($kind) {
                    "h" { $hh=Hardware; $pp=Recommendation $hh; $details.Text=Show-HardwareText $hh $pp }
                    "d" { $ds=DriverHealth; if($ds.Count -eq 0){$details.Text="DRIVER HEALTH`r`n`r`nNo display driver details available."}else{$details.Text="DRIVER HEALTH`r`n`r`n"+(($ds|ForEach-Object{"$($_.Name)`r`nProvider: $($_.Provider)`r`nVersion: $($_.Version)`r`nDate: $($_.Date)`r`n"})-join"`r`n")} }
                    "t" { $x=ThermalStatus; if($x.Status -eq "UNKNOWN"){$details.Text="THERMAL GUARD`r`n`r`nTelemetry unavailable; KXM does not guess temperature."}else{$details.Text="THERMAL GUARD`r`n`r`nStatus: $($x.Status)`r`nMaximum reading: $($x.MaxC) C"} }
                    "c" { $q=New-Object System.Collections.Generic.List[string]; if(Get-Process -Name Discord -ErrorAction SilentlyContinue){[void]$q.Add("Discord running")}; if(Get-Process -Name RivaTunerStatisticsServer -ErrorAction SilentlyContinue){[void]$q.Add("RTSS running")}; $v=Get-Service -Name vmms -ErrorAction SilentlyContinue; if($v -and $v.Status -eq "Running"){[void]$q.Add("Hyper-V running")}; $details.Text="CONFLICT CHECK`r`n`r`n"+$(if($q.Count -gt 0){$q -join "`r`n"}else{"No known conflicts detected."}) }
                    "u" { $drift=UpdateDrift; $details.Text="UPDATE RESILIENCE`r`n`r`nPending reboot: $(PendingReboot)`r`n"+(($drift|ForEach-Object{"$($_.Name): actual=$($_.Actual) expected=$($_.Expected) drift=$($_.Drift)"})-join"`r`n") }
                    "l" { $details.Text=Test-KxmLatency }
                    "b" { $details.Text="FRAME-TIME BENCH`r`n`r`n"+(Get-FrameTimeToolStatus) }
                    "p" { $pp=Recommendation(Hardware);$f=ExportProfile $pp;$details.Text="PROFILE EXPORTED`r`n`r`n$f" }
                    "i" { $details.Text=CommunityInsights }
                    "v" { $details.Text=Show-VerifyText (Hardware) (Recommendation(Hardware)) }
                    "y" { $hh=Hardware;$pp=Recommendation $hh;$details.Text=Preview $hh $pp }
                    "k" { if(Test-Path -LiteralPath $Script:Pointer){$base=(Get-Content -LiteralPath $Script:Pointer -Raw -Encoding UTF8).Trim();$details.Text="BACKUP CENTER`r`n`r`nCurrent baseline:`r`n$base`r`n`r`nLast session snapshot: $(Test-Path -LiteralPath $Script:LastSession)`r`n`r`nBaseline file: $(Test-Path -LiteralPath (Join-Path $base "Baseline.xml"))"}else{$details.Text="BACKUP CENTER`r`n`r`nNo baseline exists yet."} }
                }
            } catch { Show-Error "Diagnostic failed" $_ }
        }.GetNewClosure()
        $b0.Add_Click($handler)
        $box.Controls.Add($b0)
        $col++
        if ($col -ge 3) { $col=0; $row++ }
    }

    $share = New-Object System.Windows.Forms.Button
    $share.Text = if([bool]$Script:Preferences.CommunitySharing){T "share_on"}else{T "share_off"}
    $share.Location = New-Object System.Drawing.Point(36,732)
    $share.Size = New-Object System.Drawing.Size(260,34)
    $share.BackColor = [System.Drawing.Color]::FromArgb(20,80,74)
    $share.ForeColor = [System.Drawing.Color]::White
    $share.FlatStyle = "Flat"
    $share.Add_Click({
        try {
            $cur = [bool]$Script:Preferences.CommunitySharing
            $msg = if($cur){"Disable anonymous community data sharing?"}else{"Enable anonymous community data sharing? No personal files, accounts, passwords, serials, registry dumps or game files are collected."}
            $a = [System.Windows.Forms.MessageBox]::Show($msg,"KXM // Community Data",4,48)
            if ($a -eq [System.Windows.Forms.DialogResult]::OK) { $Script:Preferences.CommunitySharing = -not $cur; Save-Prefs }
            $share.Text = if([bool]$Script:Preferences.CommunitySharing){T "share_on"}else{T "share_off"}
        } catch { Show-Error "Community settings failed" $_ }
    })
    $form.Controls.Add($share)

    $undo = New-Object System.Windows.Forms.Button
    $undo.Text = "UNDO LAST SESSION"
    $undo.Location = New-Object System.Drawing.Point(310,732)
    $undo.Size = New-Object System.Drawing.Size(220,34)
    $undo.FlatStyle = "Flat"
    $undo.Add_Click({
        try { $details.Text = UndoLastSession; Send-KxmCommunityEvent "session_undo" @{} } catch { Show-Error "Session undo failed" $_ }
    })
    $form.Controls.Add($undo)

    $lang = New-Object System.Windows.Forms.ComboBox
    $lang.DropDownStyle = "DropDownList"
    [void]$lang.Items.AddRange(@("English","Arabic","French"))
    $lang.Location = New-Object System.Drawing.Point(960,732)
    $lang.Size = New-Object System.Drawing.Size(230,30)
    $lang.SelectedIndex = if($Script:Lang -eq "ar"){1}elseif($Script:Lang -eq "fr"){2}else{0}
    $form.Controls.Add($lang)
    $lang.Add_SelectedIndexChanged({
        try {
            $new = if($lang.SelectedIndex -eq 1){"ar"}elseif($lang.SelectedIndex -eq 2){"fr"}else{"en"}
            $Script:Lang = $new
            $Script:Preferences.Language = $new
            Save-Prefs
            $sub.Text = T "subtitle"
            $status.Text = T "system_ready"
            $quick.Text = "  " + (T "quick") + "  "
            $share.Text = if([bool]$Script:Preferences.CommunitySharing){T "share_on"}else{T "share_off"}
            $ready.Text = T "ready"; $end.Text = T "end"; $smart.Text = T "smart"; $restore.Text = T "restore"; $box.Text = "  " + (T "diag") + "  "
            $form.RightToLeft = if($new -eq "ar"){"Yes"}else{"No"}
            $form.RightToLeftLayout = ($new -eq "ar")
        } catch { Show-Error "Language change failed" $_ }
    })

    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}

if (-not $Script:TestMode) { Start-KxmGui }
