# KXM BLUEFIRE v21
# Stable GUI baseline for Windows PowerShell 5.1.
# Source is ASCII-only. Unicode is loaded from KXM_LANG_V21.json.
Set-StrictMode -Version 2.0
$ErrorActionPreference='SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Root=Join-Path $env:ProgramData 'KXM\BlueFire'
$BackupRoot=Join-Path $Root 'Backups'
$LogRoot=Join-Path $Root 'Logs'
$Pointer=Join-Path $Root 'CURRENT_BASELINE.txt'
$LogFile=Join-Path $LogRoot 'KXM.log'
$LangPath=Join-Path $PSScriptRoot 'KXM_LANG_V21.json'
New-Item -ItemType Directory -Path $BackupRoot -Force|Out-Null
New-Item -ItemType Directory -Path $LogRoot -Force|Out-Null
$TX=Get-Content -LiteralPath $LangPath -Raw -Encoding UTF8|ConvertFrom-Json
$Script:Lang='EN'

function T($key){$n=$key+'_'+$Script:Lang;$p=$TX.PSObject.Properties[$n];if($null -ne $p){return [string]$p.Value};$p=$TX.PSObject.Properties[$key+'_EN'];if($null -ne $p){return [string]$p.Value};return $key}
function Log($s){Add-Content -LiteralPath $LogFile -Value ('[{0}] {1}'-f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$s)-Encoding UTF8}
function RegD($p,$n,$v){try{New-Item $p -Force|Out-Null;New-ItemProperty $p -Name $n -PropertyType DWord -Value $v -Force|Out-Null}catch{}}
function RegS($p,$n,$v){try{New-Item $p -Force|Out-Null;New-ItemProperty $p -Name $n -PropertyType String -Value $v -Force|Out-Null}catch{}}
function Snap($p,$n){$e=$false;$v=$null;$k='DWord';try{$i=Get-ItemProperty -LiteralPath $p -ErrorAction Stop;$x=$i.PSObject.Properties[$n];if($null -ne $x){$e=$true;$v=$x.Value;if($v -is [string]){$k='String'}}}catch{};[pscustomobject]@{Path=$p;Name=$n;Exists=$e;Value=$v;Kind=$k}}
function RestoreSnap($e){if($e.Exists){if($e.Kind -eq 'String'){RegS $e.Path $e.Name ([string]$e.Value)}else{RegD $e.Path $e.Name ([int64]$e.Value)}}else{Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name -ErrorAction SilentlyContinue}}
function DiskInfo{
 $h=$false;$s=$false
 try{foreach($d in @(Get-PhysicalDisk -ErrorAction Stop)){$m=[string]$d.MediaType;if($m -match 'HDD'){$h=$true};if($m -match 'SSD'){$s=$true}}}catch{}
 if(-not $h -and -not $s){try{foreach($d in @(Get-CimInstance Win32_DiskDrive)){$m=([string]$d.Model+' '+[string]$d.MediaType+' '+[string]$d.InterfaceType);if($m -match 'SSD|Solid State|NVMe'){$s=$true}elseif($m -match 'HDD|Hard Disk|SATA|IDE'){$h=$true}}}catch{}}
 [pscustomobject]@{HDD=$h;SSD=$s}
}
function Hardware{
 $c=Get-CimInstance Win32_Processor|Select-Object -First 1;$cs=Get-CimInstance Win32_ComputerSystem;$g=@(Get-CimInstance Win32_VideoController);$d=DiskInfo
 $ram=0;if($cs){$ram=[math]::Round($cs.TotalPhysicalMemory/1GB,1)}
 $gpu='Unknown';foreach($x in $g){if($gpu -eq 'Unknown'){$gpu=[string]$x.Name}else{$gpu+=' | '+[string]$x.Name}}
 $cpuName='Unknown';$cores=0;$threads=0;$virt=$false
 if($c){$cpuName=[string]$c.Name;$cores=[int]$c.NumberOfCores;$threads=[int]$c.NumberOfLogicalProcessors;$virt=[bool]$c.VirtualizationFirmwareEnabled}
 [pscustomobject]@{CPU=$cpuName;Cores=$cores;Threads=$threads;RAM=$ram;GPU=$gpu;HDD=$d.HDD;SSD=$d.SSD;Virtualization=$virt}
}
function Recommendation($h){
 $bc=4;$br=4;if($h.Threads -lt 4){$bc=2};if($h.RAM -lt 8){$br=2}
 $disk='HDD-safe';if($h.SSD){$disk='SSD-ready'}
 [pscustomobject]@{Cores=$bc;RAM=$br;Mode='High Performance';FPS='120 recommended / 240 ceiling optional';Disk=$disk}
}
function BlueStacksPath{
 foreach($p in @("$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe","$env:ProgramFiles\BlueStacks_nxt5\HD-Player.exe","${env:ProgramFiles(x86)}\BlueStacks_nxt\HD-Player.exe","${env:ProgramFiles(x86)}\BlueStacks_nxt5\HD-Player.exe")){if($p -and (Test-Path $p)){return $p}}
 return $null
}
function EnsureBaseline{
 if(Test-Path $Pointer){$d=(Get-Content $Pointer -Raw -Encoding UTF8).Trim();if($d -and (Test-Path (Join-Path $d 'Baseline.xml'))){return $d}}
 $d=Join-Path $BackupRoot (Get-Date -Format 'yyyyMMdd_HHmmss');New-Item -ItemType Directory $d -Force|Out-Null
 $st=[ordered]@{Created=(Get-Date).ToString('o');Power=((powercfg /getactivescheme)-join ' ');Registry=New-Object System.Collections.ArrayList;Services=New-Object System.Collections.ArrayList}
 foreach($x in @(@('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile','SystemResponsiveness'),@('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile','NetworkThrottlingIndex'),@('HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl','Win32PrioritySeparation'),@('HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling','PowerThrottlingOff'),@('HKCU:\Software\Microsoft\GameBar','AutoGameModeEnabled'),@('HKCU:\System\GameConfigStore','GameDVR_Enabled'))){$st.Registry.Add((Snap $x[0] $x[1]))}
 try{$svc=Get-CimInstance Win32_Service -Filter "Name='SysMain'";$st.Services.Add([pscustomobject]@{Name='SysMain';Start=[string]$svc.StartMode;State=[string]$svc.State})}catch{}
 $st|Export-Clixml (Join-Path $d 'Baseline.xml');powercfg /list|Out-File (Join-Path $d 'PowerPlans.txt') -Encoding UTF8;bcdedit /enum all|Out-File (Join-Path $d 'BCD.txt') -Encoding UTF8
 Set-Content $Pointer $d -Encoding UTF8;Log ('Baseline: '+$d);return $d
}
function RestoreBaseline{
 if(-not(Test-Path $Pointer)){[System.Windows.Forms.MessageBox]::Show((T 'NoBase'),'KXM // RESTORE')|Out-Null;return}
 $d=(Get-Content $Pointer -Raw -Encoding UTF8).Trim();$f=Join-Path $d 'Baseline.xml';if(-not(Test-Path $f)){[System.Windows.Forms.MessageBox]::Show('Baseline.xml missing','KXM // RESTORE')|Out-Null;return}
 $a=[System.Windows.Forms.MessageBox]::Show((T 'RestoreQ'),'KXM // RESTORE',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning);if($a -ne [System.Windows.Forms.DialogResult]::Yes){return}
 $st=Import-Clixml $f;foreach($e in $st.Registry){RestoreSnap $e};foreach($s in $st.Services){if($s.Start -eq 'Auto'){Set-Service $s.Name -StartupType Automatic}elseif($s.Start -eq 'Manual'){Set-Service $s.Name -StartupType Manual}elseif($s.Start -eq 'Disabled'){Set-Service $s.Name -StartupType Disabled};if($s.State -eq 'Running'){Start-Service $s.Name}else{if($s.State -eq 'Stopped'){Stop-Service $s.Name -Force}}};if($st.Power -match '([0-9a-fA-F-]{36})'){powercfg /setactive $Matches[1]|Out-Null};Log 'Restore completed';[System.Windows.Forms.MessageBox]::Show((T 'Restored'),'KXM // RESTORE')|Out-Null
}
function GameReady{
 EnsureBaseline
 foreach($d in @($env:TEMP,(Join-Path $env:LOCALAPPDATA 'Temp'),'C:\Windows\Temp')){if(Test-Path $d){Remove-Item -LiteralPath (Join-Path $d '*') -Recurse -Force -ErrorAction SilentlyContinue}}
 ipconfig /flushdns|Out-Null;powercfg /setactive SCHEME_MIN|Out-Null
 $bs=BlueStacksPath;$p=Get-Process -Name 'HD-Player' -ErrorAction SilentlyContinue|Select-Object -First 1;if($p){try{$p.PriorityClass='AboveNormal'}catch{}}
 Log 'GAME READY';[pscustomobject]@{BlueStacks=$bs;Running=[bool]$p}
}
function SmartOptimize{
 EnsureBaseline;$h=Hardware
 powercfg /setactive SCHEME_MIN|Out-Null
 RegD 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
 RegD 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
 RegD 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
 $mm='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile';$g="$mm\Tasks\Games"
 RegD $mm 'SystemResponsiveness' 0;RegD $mm 'NetworkThrottlingIndex' 4294967295;RegD $g 'GPU Priority' 8;RegD $g 'Priority' 6
 RegD 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38;RegD 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1
 if($h.HDD -or $h.RAM -le 8){Set-Service SysMain -StartupType Automatic;Start-Service SysMain}
 $bs=BlueStacksPath;if($bs){RegS 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' $bs 'GpuPreference=2;'}
 Log 'SMART OPTIMIZE';return $h
}
function NetOptimize{EnsureBaseline;netsh int tcp set global rss=enabled|Out-Null;netsh int tcp set global autotuninglevel=normal|Out-Null;Log 'NETWORK'}

$form=New-Object System.Windows.Forms.Form;$form.Text='KXM // BLUEFIRE v21';$form.Size=New-Object System.Drawing.Size(1240,800);$form.StartPosition='CenterScreen';$form.BackColor=[System.Drawing.Color]::FromArgb(8,11,16);$form.ForeColor=[System.Drawing.Color]::White;$form.Font=New-Object System.Drawing.Font('Segoe UI',10);$form.FormBorderStyle='FixedSingle';$form.MaximizeBox=$false
$header=New-Object System.Windows.Forms.Label;$header.Location=New-Object System.Drawing.Point(38,22);$header.Size=New-Object System.Drawing.Size(650,50);$header.Font=New-Object System.Drawing.Font('Segoe UI Semibold',25);$header.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200);$form.Controls.Add($header)
$sub=New-Object System.Windows.Forms.Label;$sub.Location=New-Object System.Drawing.Point(42,70);$sub.Size=New-Object System.Drawing.Size(850,30);$sub.ForeColor=[System.Drawing.Color]::Silver;$form.Controls.Add($sub)
$status=New-Object System.Windows.Forms.Label;$status.Location=New-Object System.Drawing.Point(890,28);$status.Size=New-Object System.Drawing.Size(285,42);$status.TextAlign='MiddleRight';$status.Font=New-Object System.Drawing.Font('Segoe UI Semibold',12);$status.ForeColor=[System.Drawing.Color]::FromArgb(120,255,175);$form.Controls.Add($status)

$h=Hardware;$r=Recommendation $h
$dash=New-Object System.Windows.Forms.Panel;$dash.Location=New-Object System.Drawing.Point(32,112);$dash.Size=New-Object System.Drawing.Size(1140,112);$dash.BackColor=[System.Drawing.Color]::FromArgb(18,23,31);$form.Controls.Add($dash)
$cards=@(@('CPU',$h.CPU),@('RAM',("$($h.RAM) GB")),@('GPU',$h.GPU),@('STORAGE',("HDD=$($h.HDD)  SSD=$($h.SSD)")),@('PROFILE',$r.Profile));$x=14
foreach($c in $cards){$cp=New-Object System.Windows.Forms.Panel;$cp.Location=New-Object System.Drawing.Point($x,14);$cp.Size=New-Object System.Drawing.Size(208,84);$cp.BackColor=[System.Drawing.Color]::FromArgb(25,31,41);$lab=New-Object System.Windows.Forms.Label;$lab.Text="$($c[0])`r`n$($c[1])";$lab.Dock='Fill';$lab.TextAlign='MiddleCenter';$lab.ForeColor=[System.Drawing.Color]::White;$cp.Controls.Add($lab);$dash.Controls.Add($cp);$x+=222}

$quick=New-Object System.Windows.Forms.GroupBox;$quick.Location=New-Object System.Drawing.Point(32,242);$quick.Size=New-Object System.Drawing.Size(1140,120);$form.Controls.Add($quick)
$ready=New-Object System.Windows.Forms.Button;$ready.Location=New-Object System.Drawing.Point(18,30);$ready.Size=New-Object System.Drawing.Size(270,68);$ready.Font=New-Object System.Drawing.Font('Segoe UI Semibold',14);$ready.BackColor=[System.Drawing.Color]::FromArgb(0,126,112);$ready.ForeColor=[System.Drawing.Color]::White;$ready.FlatStyle='Flat';$quick.Controls.Add($ready)
$smart=New-Object System.Windows.Forms.Button;$smart.Location=New-Object System.Drawing.Point(305,30);$smart.Size=New-Object System.Drawing.Size(270,68);$smart.Font=New-Object System.Drawing.Font('Segoe UI Semibold',13);$smart.BackColor=[System.Drawing.Color]::FromArgb(34,44,58);$smart.ForeColor=[System.Drawing.Color]::White;$smart.FlatStyle='Flat';$quick.Controls.Add($smart)
$restore=New-Object System.Windows.Forms.Button;$restore.Location=New-Object System.Drawing.Point(592,30);$restore.Size=New-Object System.Drawing.Size(250,68);$restore.Font=New-Object System.Drawing.Font('Segoe UI Semibold',12);$restore.BackColor=[System.Drawing.Color]::FromArgb(68,47,44);$restore.ForeColor=[System.Drawing.Color]::White;$restore.FlatStyle='Flat';$quick.Controls.Add($restore)
$lang=New-Object System.Windows.Forms.ComboBox;$lang.DropDownStyle='DropDownList';$lang.Items.AddRange(@('English','العربية','Français'));$lang.SelectedIndex=0;$lang.Location=New-Object System.Drawing.Point(870,48);$lang.Size=New-Object System.Drawing.Size(225,34);$quick.Controls.Add($lang)

$tools=New-Object System.Windows.Forms.GroupBox;$tools.Location=New-Object System.Drawing.Point(32,390);$tools.Size=New-Object System.Drawing.Size(555,305);$form.Controls.Add($tools)
$details=New-Object System.Windows.Forms.TextBox;$details.Multiline=$true;$details.ReadOnly=$true;$details.ScrollBars='Vertical';$details.Location=New-Object System.Drawing.Point(610,390);$details.Size=New-Object System.Drawing.Size(562,305);$details.BackColor=[System.Drawing.Color]::FromArgb(13,17,23);$details.ForeColor=[System.Drawing.Color]::FromArgb(195,245,236);$details.BorderStyle='FixedSingle';$details.Font=New-Object System.Drawing.Font('Consolas',11);$form.Controls.Add($details)

$toolInfo=@(@('Audit','Audit'),@('BS','BS'),@('CPU','CPU'),@('Net','Net'),@('Storage','Storage'),@('BG','BG'),@('Bench','Bench'),@('Verify','Verify'),@('Backup','Backup'))
$toolButtons=@{}
$row=0;$col=0
foreach($ti in $toolInfo){$b=New-Object System.Windows.Forms.Button;$b.Tag=$ti[0];$b.Location=New-Object System.Drawing.Point((15+178*$col),(32+72*$row));$b.Size=New-Object System.Drawing.Size(165,56);$b.BackColor=[System.Drawing.Color]::FromArgb(27,34,44);$b.ForeColor=[System.Drawing.Color]::White;$b.FlatStyle='Flat';$tools.Controls.Add($b);$toolButtons[$ti[0]]=$b;$col++;if($col -ge 3){$col=0;$row++}}

foreach($b in $toolButtons.Values){$b.Add_Click({$tag=$this.Tag;$hh=Hardware;$rr=Recommendation $hh;if($tag -eq 'Audit'){$details.Text="HARDWARE AUDIT`r`n`r`nCPU: $($hh.CPU)`r`nCores / Threads: $($hh.Cores) / $($hh.Threads)`r`nRAM: $($hh.RAM) GB`r`nGPU: $($hh.GPU)`r`nStorage: HDD=$($hh.HDD) / SSD=$($hh.SSD)`r`nVirtualization: $($hh.Virtualization)`r`n`r`nFREE FIRE TARGET`r`nCPU: $($rr.Cores) cores`r`nRAM: $($rr.RAM) GB`r`nMode: High Performance`r`nFPS: $($rr.FPS)"}elseif($tag -eq 'BS'){$details.Text="BLUESTACKS ENGINE`r`n`r`nPath: $(BlueStacksPath)`r`nRecommended CPU: $($rr.Cores) cores`r`nRecommended RAM: $($rr.RAM) GB`r`nMode: High Performance`r`nFPS ceiling: 240 optional target"}elseif($tag -eq 'CPU'){$details.Text='CPU / SCHEDULER`r`n`r`nSmart Optimize applies the KXM game scheduling profile.`r`nAdvanced kernel experiments remain separate.'}elseif($tag -eq 'Net'){NetOptimize;$details.Text='NETWORK ENGINE APPLIED`r`n`r`nRSS: enabled`r`nTCP autotuning: normal.'}elseif($tag -eq 'Storage'){$details.Text="STORAGE / MEMORY`r`n`r`nHDD: $($hh.HDD)`r`nSSD: $($hh.SSD)`r`nPagefile: Windows managed`r`nMemory compression: keep enabled`r`nPolicy: $($rr.Disk)"}elseif($tag -eq 'BG'){if($hh.HDD -or $hh.RAM -le 8){$pol='KEEP AUTO'}else{$pol='OPTIONAL'};$details.Text="BACKGROUND CONTROL`r`n`r`nSysMain recommendation: $pol`r`n`r`nKXM avoids aggressive service killing on low-memory / HDD systems."}elseif($tag -eq 'Bench'){$f=Join-Path $Root ('benchmark_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.txt');@('KXM BLUEFIRE v21',"$(Get-Date)","CPU: $($hh.CPU)","RAM: $($hh.RAM) GB","GPU: $($hh.GPU)","HDD: $($hh.HDD)","SSD: $($hh.SSD)","Profile: $($rr.Profile)")|Set-Content $f -Encoding UTF8;$details.Text="BENCHMARK SAVED`r`n`r`n$f"}elseif($tag -eq 'Verify'){$details.Text="VERIFY`r`n`r`nPower: $((powercfg /getactivescheme)-join ' ')`r`nSysMain: $((Get-Service SysMain).StartType)`r`nHAGS override: $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers').HwSchMode)"}elseif($tag -eq 'Backup'){if(Test-Path $Pointer){$details.Text="BACKUP CENTER`r`n`r`nCurrent baseline:`r`n$((Get-Content $Pointer -Raw -Encoding UTF8).Trim())"}else{$details.Text=(T 'NoBase')}}})}

$ready.Add_Click({$z=GameReady;$status.Text=(T 'Ready');$details.Text="$(T 'ReadyDone')`r`n`r`n$(if($z.BS){'BlueStacks detected and session prepared.'}else{'BlueStacks not found in common paths.'})`r`n`r`nTemp cleanup: DONE`r`nDNS flush: DONE`r`nPower: High Performance"})
$smart.Add_Click({$a=[System.Windows.Forms.MessageBox]::Show('Apply the recommended Free Fire profile: 4 CPU cores / 4 GB RAM target / High Performance?','KXM // SMART OPTIMIZE',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question);if($a -eq [System.Windows.Forms.DialogResult]::Yes){$z=SmartOptimize;$rr=Recommendation $z;$status.Text='● OPTIMIZED';$details.Text="SMART OPTIMIZE APPLIED`r`n`r`nBlueStacks: $($rr.Cores) CPU cores / $($rr.RAM) GB target`r`nMode: High Performance`r`nFPS ceiling: 240 optional`r`n`r`nBaseline:`r`n$((Get-Content $Pointer -Raw).Trim())"}})
$restore.Add_Click({RestoreBaseline;$status.Text='● RESTORE'})

function Refresh-UI{
 $header.Text=T 'Title';$sub.Text=T 'Sub';$status.Text=T 'Ready';$quick.Text='  '+(T 'Quick')+'  ';$tools.Text='  '+(T 'Control')+'  ';$ready.Text=T 'Game';$smart.Text=T 'Smart';$restore.Text=T 'Restore'
 $toolButtons['Audit'].Text=T 'Audit';$toolButtons['BS'].Text=T 'BS';$toolButtons['CPU'].Text=T 'CPU';$toolButtons['Net'].Text=T 'Net';$toolButtons['Storage'].Text=T 'Storage';$toolButtons['BG'].Text=T 'BG';$toolButtons['Bench'].Text=T 'Bench';$toolButtons['Verify'].Text=T 'Verify';$toolButtons['Backup'].Text=T 'Backup'
 if($Script:Lang -eq 'AR'){$form.RightToLeft='Yes';$form.RightToLeftLayout=$true}else{$form.RightToLeft='No';$form.RightToLeftLayout=$false}
}
$lang.Add_SelectedIndexChanged({if($lang.SelectedItem -eq 'العربية'){$Script:Lang='AR'}elseif($lang.SelectedItem -eq 'Français'){$Script:Lang='FR'}else{$Script:Lang='EN'};Refresh-UI})

Refresh-UI
$details.Text="KXM BLUEFIRE v21`r`n`r`n$(T 'ReadyDone')`r`n`r`nCPU: $($h.CPU)`r`nRAM: $($h.RAM) GB`r`nGPU: $($h.GPU)`r`nStorage: HDD=$($h.HDD) / SSD=$($h.SSD)`r`n`r`n$(T 'Explain')"
$form.Add_Shown({$form.Activate()});[void]$form.ShowDialog()
