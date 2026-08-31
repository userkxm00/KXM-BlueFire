# KXM Community Telemetry Module
# Windows PowerShell 5.1 compatible.
# OFF by default. No endpoint is configured by default.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'SilentlyContinue'

$KxmDataRoot = Join-Path $env:ProgramData 'KXM\BlueFire'
$KxmTelemetryRoot = Join-Path $KxmDataRoot 'Telemetry'
$KxmTelemetryConfig = Join-Path $KxmTelemetryRoot 'telemetry.json'
$KxmTelemetryQueue = Join-Path $KxmTelemetryRoot 'queue.jsonl'
$KxmTelemetrySchema = 1

New-Item -ItemType Directory -Path $KxmTelemetryRoot -Force | Out-Null

function Get-KxmTelemetrySettings {
    if (Test-Path $KxmTelemetryConfig) {
        try {
            return Get-Content -LiteralPath $KxmTelemetryConfig -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {}
    }
    return [pscustomobject]@{
        enabled = $false
        endpoint = ''
    }
}

function Set-KxmTelemetrySettings {
    param(
        [bool]$Enabled,
        [string]$Endpoint = ''
    )
    if (-not $Enabled) { $Endpoint = '' }
    [pscustomobject]@{
        schema = $KxmTelemetrySchema
        enabled = $Enabled
        endpoint = $Endpoint
    } | ConvertTo-Json | Set-Content -LiteralPath $KxmTelemetryConfig -Encoding UTF8
}

function Get-KxmCoarseHardware {
    param($Hardware)
    $cpuVendor = 'Unknown'
    $cpuFamily = 'Unknown'
    $gpuVendor = 'Unknown'
    $gpuTier = 'unknown'
    $storage = 'unknown'

    if ($Hardware) {
        if ([string]$Hardware.CPU -match 'Intel') { $cpuVendor = 'Intel' }
        elseif ([string]$Hardware.CPU -match 'AMD|Ryzen|Threadripper') { $cpuVendor = 'AMD' }
        elseif ([string]$Hardware.CPU -match 'Qualcomm|Snapdragon') { $cpuVendor = 'Qualcomm' }

        if ([string]$Hardware.CPU -match 'Ivy Bridge') { $cpuFamily = 'Ivy Bridge' }
        elseif ([string]$Hardware.CPU -match 'Sandy Bridge') { $cpuFamily = 'Sandy Bridge' }
        elseif ([string]$Hardware.CPU -match 'Haswell') { $cpuFamily = 'Haswell' }
        elseif ([string]$Hardware.CPU -match 'Skylake') { $cpuFamily = 'Skylake' }
        elseif ([string]$Hardware.CPU -match 'Kaby Lake') { $cpuFamily = 'Kaby Lake' }
        elseif ([string]$Hardware.CPU -match 'Coffee Lake') { $cpuFamily = 'Coffee Lake' }
        elseif ([string]$Hardware.CPU -match 'Zen 2') { $cpuFamily = 'Zen 2' }
        elseif ([string]$Hardware.CPU -match 'Zen 3') { $cpuFamily = 'Zen 3' }
        elseif ([string]$Hardware.CPU -match 'Zen 4') { $cpuFamily = 'Zen 4' }

        if ([string]$Hardware.GPU -match 'NVIDIA|GeForce|Quadro') { $gpuVendor = 'NVIDIA' }
        elseif ([string]$Hardware.GPU -match 'AMD|Radeon') { $gpuVendor = 'AMD' }
        elseif ([string]$Hardware.GPU -match 'Intel') { $gpuVendor = 'Intel' }

        if ([string]$Hardware.GPU -match 'RTX|RX 6|RX 7|Arc') { $gpuTier = 'discrete-modern' }
        elseif ([string]$Hardware.GPU -match 'GTX|RX 5|Vega') { $gpuTier = 'discrete-older' }
        elseif ([string]$Hardware.GPU -match 'HD Graphics|UHD Graphics|Iris') { $gpuTier = 'integrated' }

        if ($Hardware.SSD) { $storage = 'SSD_or_NVMe' }
        elseif ($Hardware.HDD) { $storage = 'HDD' }
    }

    $ramTier = 0
    if ($Hardware) {
        if ($Hardware.RAM -lt 4) { $ramTier = 2 }
        elseif ($Hardware.RAM -lt 8) { $ramTier = 4 }
        elseif ($Hardware.RAM -lt 12) { $ramTier = 8 }
        elseif ($Hardware.RAM -lt 24) { $ramTier = 16 }
        elseif ($Hardware.RAM -lt 48) { $ramTier = 32 }
        else { $ramTier = 64 }
    }

    return [pscustomobject]@{
        cpu_vendor = $cpuVendor
        cpu_family = $cpuFamily
        logical_processors = if ($Hardware) { [int]$Hardware.Threads } else { 0 }
        ram_tier_gb = $ramTier
        gpu_vendor = $gpuVendor
        gpu_tier = $gpuTier
        storage_class = $storage
    }
}

function New-KxmTelemetryEvent {
    param(
        [string]$EventName,
        $Hardware,
        [string]$Game = '',
        [string]$Emulator = '',
        [string]$Profile = '',
        $Changes = @(),
        [bool]$Success = $true,
        [bool]$RebootRequired = $false,
        [bool]$Restored = $false,
        [hashtable]$Benchmark = $null
    )

    $coarse = Get-KxmCoarseHardware $Hardware
    $event = [ordered]@{
        schema = $KxmTelemetrySchema
        kx_version = '24.0'
        event = $EventName
        timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
        hardware = $coarse
        target = [ordered]@{
            emulator = $Emulator
            game = $Game
            profile = $Profile
        }
        changes = @($Changes)
        result = [ordered]@{
            success = $Success
            reboot_required = $RebootRequired
            restored = $Restored
        }
    }

    if ($Benchmark) {
        $event.result.benchmark = $Benchmark
    }

    return [pscustomobject]$event
}

function Queue-KxmTelemetryEvent {
    param($Event)
    $settings = Get-KxmTelemetrySettings
    if (-not $settings.enabled) { return $false }
    $line = $Event | ConvertTo-Json -Depth 8 -Compress
    Add-Content -LiteralPath $KxmTelemetryQueue -Value $line -Encoding UTF8
    return $true
}

function Send-KxmTelemetryQueue {
    $settings = Get-KxmTelemetrySettings
    if (-not $settings.enabled -or [string]::IsNullOrWhiteSpace($settings.endpoint)) { return 0 }
    if (-not (Test-Path $KxmTelemetryQueue)) { return 0 }

    $sent = 0
    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($line in @(Get-Content -LiteralPath $KxmTelemetryQueue -Encoding UTF8)) {
        try {
            Invoke-RestMethod -Method Post -Uri $settings.endpoint -ContentType 'application/json' -Body $line -TimeoutSec 8 | Out-Null
            $sent++
        } catch {
            [void]$kept.Add($line)
        }
    }

    if ($kept.Count -eq 0) {
        Remove-Item -LiteralPath $KxmTelemetryQueue -Force -ErrorAction SilentlyContinue
    } else {
        $kept | Set-Content -LiteralPath $KxmTelemetryQueue -Encoding UTF8
    }
    return $sent
}

function Clear-KxmTelemetryQueue {
    Remove-Item -LiteralPath $KxmTelemetryQueue -Force -ErrorAction SilentlyContinue
    return $true
}

function Get-KxmTelemetryPreview {
    return [ordered]@{
        schema = $KxmTelemetrySchema
        hardware = @('CPU vendor/family','logical processor count','RAM tier','GPU vendor/tier','storage class')
        target = @('KXM version','game/emulator/profile category')
        outcome = @('change IDs and success/failure','reboot required','restored flag','optional benchmark values')
        excluded = @('names','usernames','passwords','tokens','documents','browser data','game account IDs','serial numbers','MAC addresses','registry dumps','file contents')
    } | ConvertTo-Json -Depth 6
}
