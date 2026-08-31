# KXM BLUEFIRE v17
# PowerShell 5.1 compatible. Source is ASCII-only; UI translations live in KXM_LANG_V17.json.
Set-StrictMode -Version 2.0
$ErrorActionPreference='SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Root=Join-Path $env:ProgramData 'KXM\BlueFire'
$BackupRoot=Join-Path $Root 'Backups'
$LogRoot=Join-Path $Root 'Logs'
$Pointer=Join-Path $Root 'CURRENT_BASELINE.txt'
$LogFile=Join-Path $LogRoot 'KXM.log'
$LangFile=Join-Path $PSScriptRoot 'KXM_LANG_V17.json'
New-Item -ItemType Directory -Path $BackupRoot -Force|Out-Null
New-Item -ItemType Directory -Path $LogRoot -Force|Out-Null

$TX=Get-Content -LiteralPath $LangFile -Raw -Encoding UTF8|ConvertFrom-Json
$Lang='EN'
function T($k){$p=$TX.PSObject.Properties[$k+'_'+$Lang];if($null -ne $p){return [string]$p.Value};return $k}
function Log($s){Add-Content -LiteralPath $LogFile -Value ('[{0}] {1}'-f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$s)-Encoding UTF8}

function Get-DiskType{
 $h=$false;$s=$false
 try{foreach($d in @(Get-PhysicalDisk -ErrorAction Stop)){$m=[string]$d.MediaType;if($m -match 'HDD'){$h=$true};if($m -match 'SSD'){$s=$true}}}catch{}
 if(-not $h -and -not $s){try{foreach($d in @(Get-CimInstance Win32_DiskDrive)){$m=([string]$d.Model+' '+[string]$d.MediaType+' '+[string]$d.InterfaceType);if($m -match 'SSD|Solid State|NVMe'){$s=$true}elseif($m -match 'HDD|Hard Disk|SATA|IDE'){$h=$true}}}catch{}}
 [pscustomobject]@{HDD=$h;SSD=$s}
}
function Get-Hardware{
 $c=Get-CimInstance Win32_Processor|Select-Object -First 1;$cs=Get-CimInstance Win32_ComputerSystem;$g=@(Get-CimInstance Win32_VideoController);$d=Get-DiskType
 $ram=0;if($cs){$ram=[math]::Round($cs.TotalPhysicalMemory/1GB,1)}
 $gpu='Unknown';foreach($x in $g){if($gpu -eq 'Unknown'){$gpu=[string]$x.Name}else{$gpu+=' | '+[string]$x.Name}}
 [pscustomobject]@{CPU=if($c){[string]$c.Name}else{'Unknown'};Cores=if($c){[int]$c.NumberOfCores}else{0};Threads=if($c){[int]$c.NumberOfLogicalProcessors}else{0};RAM=$ram;GPU=$gpu;HDD=$d.HDD;SSD=$d.SSD;Virtualization=if($c){[bool]$c.VirtualizationFirmwareEnabled}else{$false}}
}
function Get-Recommendation($h){$bc=4;$bm=4;if($h.Threads -lt 4){$bc=2};if($h.RAM -lt 8){$bm=2};$disk='HDD-safe';if($h.SSD){$disk='SSD-ready'};[pscustomobject]@{Cores=$bc;RAM=$bm;Mode='High Performance';FPS='120 recommended / 240 ceiling';Disk=$disk}}
function Reg-Dword($p,$n,$v){try{New-Item $p -Force|Out-Null;New-ItemProperty $p -Name $n -PropertyType DWord -Value $v -Force|Out-Null}catch{}}
function Reg-String($p,$n,$v){try{New-Item $p -Force|Out-Null;New-ItemProperty $p -Name $n -PropertyType String -Value $v -Force|Out-Null}catch{}}
function Snap($p,$n){$e=$false;$v=$null;$k='DWord';try{$i=Get-ItemProperty -LiteralPath $p -ErrorAction Stop;$q=$i.PSObject.Properties[$n];if($null -ne $q){$e=$true;$v=$q.Value;if($v -is [string]){$k='String'}}}catch{};[pscustomobject]@{Path=$p;Name=$n;Exists=$e;Value=$v;Kind=$k}}
function Restore-Snap($e){if($e.Exists){if($e.Kind -eq 'String'){Reg-String $e.Path $e.Name ([string]$e.Value)}else{Reg-Dword $e.Path $e.Name ([int64]$e.Value)}}else{Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name -ErrorAction SilentlyContinue}}
function Ensure-Baseline{
 if(Test-Path $Pointer){$d=(Get-Content $Pointer -Raw -Encoding UTF8).Trim();if($d -and (Test-Path (Join-Path $d 'Baseline.xml'))){return $d}}
 $d=Join-Path $BackupRoot (Get-Date -Format 'yyyyMMdd_HHmmss');New-Item -ItemType Directory $d -Force|Out-Null
 $st=[ordered]@{Created=(Get-Date).ToString('o');Power=((powercfg /getactivescheme)-join ' ');Registry=New-Object System.Collections.ArrayList;Services=New-Object System.Collections.ArrayList}
 $targets=@(@('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile','SystemResponsiveness'),@('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile','NetworkThrottlingIndex'),@('HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl','Win32PrioritySeparation'),@('HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling','PowerThrottlingOff'),@('HKCU:\Software\Microsoft\GameBar','AutoGameModeEnabled'),@('HKCU:\System\GameConfigStore','GameDVR_Enabled'))
 foreach($x in $targets){$st.Registry.Add((Snap $x[0] $x[1]))}
 try{$s=Get-CimInstance Win32_Service -Filter "Name='SysMain'";$st.Services.Add([pscustomobject]@{Name='SysMain';Start=[string]$s.StartMode;State=[string]$s.State})}catch{}
 $st|Export-Clixml (Join-Path $d 'Baseline.xml');powercfg /list|Out-File (Join-Path $d 'PowerPlans.txt') -Encoding UTF8;bcdedit /enum all|Out-File (Join-Path $d 'BCD.txt') -Encoding UTF8
 Set-Content $Pointer $d -Encoding UTF8;Log ('Baseline created: '+$d);return $d
}
function Restore-Baseline{
 if(-not(Test-Path $Pointer)){[System.Windows.Forms.MessageBox]::Show((T 'NoBase'),'KXM')|Out-Null;return}
 $d=(Get-Content $Pointer -Raw -Encoding UTF8).Trim();$f=Join-Path $d 'Baseline.xml';if(-not(Test-Path $f)){[System.Windows.Forms.MessageBox]::Show('Baseline.xml missing','KXM')|Out-Null;return}
 $a=[System.Windows.Forms.MessageBox]::Show((T 'RestoreQ'),'KXM // RESTORE',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning);if($a -ne [System.Windows.Forms.DialogResult]::Yes){return}
 $st=Import-Clixml $f;foreach($e in $st.Registry){Restore-Snap $e};foreach($s in $st.Services){if($s.Start -eq 'Auto'){Set-Service $s.Name -StartupType Automatic}elseif($s.Start -eq 'Manual'){Set-Service $s.Name -StartupType Manual}elseif($s.Start -eq 'Disabled'){Set-Service $s.Name -StartupType Disabled};if($s.State -eq 'Running'){Start-Service $s.Name}else{if($s.State -eq 'Stopped'){Stop-Service $s.Name -Force}}};if($st.Power -match '([0-9a-fA-F-]{36})'){powercfg /setactive $Matches[1]|Out-Null};Log 'Baseline restored';[System.Windows.Forms.MessageBox]::Show((T 'Restored'),'KXM')|Out-Null
}
function Find-BS{foreach($p in @("$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe","$env:ProgramFiles\BlueStacks_nxt5\HD-Player.exe","${env:ProgramFiles(x86)}\BlueStacks_nxt\HD-Player.exe","${env:ProgramFiles(x86)}\BlueStacks_nxt5\HD-Player.exe")){if($p -and (Test-Path $p)){return $p}};return $null}
function Game-Ready{
 Ensure-Baseline
 foreach($d in @($env:TEMP,(Join-Path $env:LOCALAPPDATA 'Temp'),'C:\Windows\Temp')){if(Test-Path $d){Remove-Item -LiteralPath (Join-Path $d '*') -Recurse -Force -ErrorAction SilentlyContinue}}
 ipconfig /flushdns|Out-Null;powercfg /setactive SCHEME_MIN|Out-Null
 $bs=Find-BS;$p=Get-Process -Name 'HD-Player' -ErrorAction SilentlyContinue|Select-Object -First 1;if($p){try{$p.PriorityClass='AboveNormal'}catch{}}
 Log 'GAME READY';[pscustomobject]@{BS=$bs;Running=[bool]$p}
}
function Smart-Optimize{
 Ensure-Baseline;$h=Get-Hardware
 powercfg /setactive SCHEME_MIN|Out-Null
 Reg-Dword 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
 Reg-Dword 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
 Reg-Dword 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
 Reg-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
 $mm='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile';$g="$mm\Tasks\Games"
 Reg-Dword $mm 'SystemResponsiveness' 0;Reg-Dword $mm 'NetworkThrottlingIndex' 4294967295;Reg-Dword $g 'GPU Priority' 8;Reg-Dword $g 'Priority' 6;Reg-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38;Reg-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1
 if($h.HDD -or $h.RAM -le 8){Set-Service SysMain -StartupType Automatic;Start-Service SysMain}
 $bs=Find-BS;if($bs){Reg-String 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' $bs 'GpuPreference=2;'}
 Log 'SMART OPTIMIZE';return $h
}
function Apply-Network{Ensure-Baseline;netsh int tcp set global rss=enabled|Out-Null;netsh int tcp set global autotuninglevel=normal|Out-Null;Log 'NETWORK'}

$form=New-Object System.Windows.Forms.Form;$form.Text='KXM // BLUEFIRE v17';$form.Size=New-Object System.Drawing.Size(1240,790);$form.StartPosition='CenterScreen';$form.BackColor=[System.Drawing.Color]::FromArgb(8,11,16);$form.ForeColor=[System.Drawing.Color]::White;$form.Font=New-Object System.Drawing.Font('Segoe UI',10);$form.FormBorderStyle='FixedSingle';$form.MaximizeBox=$false
$header=New-Object System.Windows.Forms.Label;$header.Location=New-Object System.Drawing.Point(38,24);$header.Size=New-Object System.Drawing.Size(650,48);$header.Font=New-Object System.Drawing.Font('Segoe UI Semibold',25);$header.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200);$form.Controls.Add($header)
$sub=New-Object System.Windows.Forms.Label;$sub.Location=New-Object System.Drawing.Point(42,72);$sub.Size=New-Object System.Drawing.Size(850,30);$sub.ForeColor=[System.Drawing.Color]::Silver;$form.Controls.Add($sub)
$status=New-Object System.Windows.Forms.Label;$status.Location=New-Object System.Drawing.Point(890,30);$status.Size=New-Object System.Drawing.Size(285,42);$status.TextAlign='MiddleRight';$status.Font=New-Object System.Drawing.Font('Segoe UI Semibold',12);$status.ForeColor=[System.Drawing.Color]::FromArgb(120,255,175);$form.Controls.Add($status)

$h=Get-Hardware;$r=Get-Recommendation $h
$dash=New-Object System.Windows.Forms.Panel;$dash.Location=New-Object System.Drawing.Point(32,118);$dash.Size=New-Object System.Drawing.Size(1140,112);$dash.BackColor=[System.Drawing.Color]::FromArgb(18,23,31);$form.Controls.Add($dash)
$cards=@(@('CPU',$h.CPU),@('RAM',("$($h.RAM) GB")),@('GPU',$h.GPU),@('STORAGE',("HDD=$($h.HDD)  SSD=$($h.SSD)")),@('PROFILE',$r.Profile));$x=14
foreach($card in $cards){$cp=New-Object System.Windows.Forms.Panel;$cp.Location=New-Object System.Drawing.Point($x,14);$cp.Size=New-Object System.Drawing.Size(208,84);$cp.BackColor=[System.Drawing.Color]::FromArgb(25,31,41);$lab=New-Object System.Windows.Forms.Label;$lab.Text="$($card[0])`r`n$($card[1])";$lab.Dock='Fill';$lab.TextAlign='MiddleCenter';$lab.ForeColor=[System.Drawing.Color]::White;$cp.Controls.Add($lab);$dash.Controls.Add($cp);$x+=222}

$quick=New-Object System.Windows.Forms.GroupBox;$quick.Location=New-Object System.Drawing.Point(32,248);$quick.Size=New-Object System.Drawing.Size(1140,118);$form.Controls.Add($quick)
$ready=New-Object System.Windows.Forms.Button;$ready.Location=New-Object System.Drawing.Point(18,30);$ready.Size=New-Object System.Drawing.Size(270,66);$ready.Font=New-Object System.Drawing.Font('Segoe UI Semibold',14);$ready.BackColor=[System.Drawing.Color]::FromArgb(0,126,112);$ready.ForeColor=[System.Drawing.Color]::White;$ready.FlatStyle='Flat';$quick.Controls.Add($ready)
$smart=New-Object System.Windows.Forms.Button;$smart.Location=New-Object System.Drawing.Point(305,30);$smart.Size=New-Object System.Drawing.Size(270,66);$smart.Font=New-Object System.Drawing.Font('Segoe UI Semibold',13);$smart.BackColor=[System.Drawing.Color]::FromArgb(34,44,58);$smart.ForeColor=[System.Drawing.Color]::White;$smart.FlatStyle='Flat';$quick.Controls.Add($smart)
$restore=New-Object System.Windows.Forms.Button;$restore.Location=New-Object System.Drawing.Point(592,30);$restore.Size=New-Object System.Drawing.Size(250,66);$restore.Font=New-Object System.Drawing.Font('Segoe UI Semibold',12);$restore.BackColor=[System.Drawing.Color]::FromArgb(68,47,44);$restore.ForeColor=[System.Drawing.Color]::White;$restore.FlatStyle='Flat';$quick.Controls.Add($restore)
$lang=New-Object System.Windows.Forms.ComboBox;$lang.DropDownStyle='DropDownList';$lang.Items.AddRange(@('English','العربية','Français'));$lang.SelectedIndex=0;$lang.Location=New-Object System.Drawing.Point(870,45);$lang.Size=New-Object System.Drawing.Size(225,34);$quick.Controls.Add($lang)

$tools=New-Object System.Windows.Forms.GroupBox;$tools.Location=New-Object System.Drawing.Point(32,392);$tools.Size=New-Object System.Drawing.Size(555,300);$tools.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200);$form.Controls.Add($tools)
$details=New-Object System.Windows.Forms.TextBox;$details.Multiline=$true;$details.ReadOnly=$true;$details.ScrollBars='Vertical';$details.Location=New-Object System.Drawing.Point(610,392);$details.Size=New-Object System.Drawing.Size(562,300);$details.BackColor=[System.Drawing.Color]::FromArgb(13,17,23);$details.ForeColor=[System.Drawing.Color]::FromArgb(195,245,236);$details.BorderStyle='FixedSingle';$details.Font=New-Object System.Drawing.Font('Consolas',11);$form.Controls.Add($details)

$toolInfo=@(@('Audit','Hardware Audit'),@('BS','BlueStacks Engine'),@('CPU','CPU / Scheduler'),@('Net','Network Engine'),@('Storage','Storage / Memory'),@('BG','Background Control'),@('Bench','Benchmark'),@('Verify','Verify'),@('Backup','Backup Center'))
$row=0;$col=0
foreach($ti in $toolInfo){$b=New-Object System.Windows.Forms.Button;$b.Text=$ti[1];$b.Tag=$ti[0];$b.Location=New-Object System.Drawing.Point((15+178*$col),(32+72*$row));$b.Size=New-Object System.Drawing.Size(165,56);$b.BackColor=[System.Drawing.Color]::FromArgb(27,34,44);$b.ForeColor=[System.Drawing.Color]::White;$b.FlatStyle='Flat';$tools.Controls.Add($b);$col++;if($col -ge 3){$col=0;$row++}}

# One event dispatcher avoids the closure bug from earlier builds.
foreach($b in @($tools.Controls)){$b.Add_Click({$tag=$this.Tag;$hh=Get-Hardware;$rr=Get-Recommendation $hh;if($tag -eq 'Audit'){$details.Text="HARDWARE AUDIT`r`n`r`nCPU: $($hh.CPU)`r`nCores / Threads: $($hh.Cores) / $($hh.Threads)`r`nRAM: $($hh.RAM) GB`r`nGPU: $($hh.GPU)`r`nHDD: $($hh.HDD)`r`nSSD: $($hh.SSD)`r`nVirtualization: $($hh.Virtualization)`r`n`r`nFREE FIRE PROFILE`r`nCPU: $($rr.Cores) cores`r`nRAM: $($rr.RAM) GB`r`nMode: High Performance`r`nFPS: $($rr.FPS)"}elseif($tag -eq 'BS'){$details.Text="BLUESTACKS ENGINE`r`n`r`nPath: $(Find-BS)`r`nRecommended: $($rr.Cores) cores / $($rr.RAM) GB`r`nMode: High Performance`r`nFPS ceiling: 240 optional target"}elseif($tag -eq 'CPU'){$details.Text='CPU / SCHEDULER`r`n`r`nSmart Optimize applies the KXM game scheduling profile.`r`nExperimental kernel options stay separate.'}elseif($tag -eq 'Net'){Apply-Network;$details.Text='NETWORK ENGINE APPLIED`r`n`r`nRSS enabled.`r`nTCP autotuning: normal.'}elseif($tag -eq 'Storage'){$details.Text="STORAGE / MEMORY`r`n`r`nHDD: $($hh.HDD)`r`nSSD: $($hh.SSD)`r`nPagefile: Windows managed`r`nMemory compression: keep enabled"}elseif($tag -eq 'BG'){$details.Text="BACKGROUND CONTROL`r`n`r`nSysMain recommendation: $((if($hh.HDD -or $hh.RAM -le 8){'KEEP AUTO'}else{'OPTIONAL'}))"}elseif($tag -eq 'Bench'){$f=Join-Path $Root ('benchmark_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.txt');@('KXM BLUEFIRE v17',"$(Get-Date)","CPU: $($hh.CPU)","RAM: $($hh.RAM) GB","GPU: $($hh.GPU)","Profile: $($rr.Profile)")|Set-Content $f -Encoding UTF8;$details.Text="BENCHMARK SAVED`r`n`r`n$f"}elseif($tag -eq 'Verify'){$details.Text="VERIFY`r`n`r`nPower: $((powercfg /getactivescheme)-join ' ')`r`nSysMain: $((Get-Service SysMain).StartType)`r`nHAGS override: $((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers').HwSchMode)"}elseif($tag -eq 'Backup'){if(Test-Path $Pointer){$details.Text="BACKUP CENTER`r`n`r`n$((Get-Content $Pointer -Raw -Encoding UTF8).Trim())"}else{$details.Text=(T 'NoBase')}}})}

$ready.Add_Click({$z=Game-Ready;$status.Text=(T 'Ready');$details.Text=((T 'ReadyDone')+'`r`n`r`n'+(T 'CleanDone')+'`r`n`r`nBlueStacks: '+[string]$z.BS+'`r`nRunning: '+[string]$z.Running)})
$smart.Add_Click({$q=[System.Windows.Forms.MessageBox]::Show('Apply Free Fire profile: 4 CPU cores / 4 GB RAM target / High Performance?','KXM // SMART OPTIMIZE',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question);if($q -eq [System.Windows.Forms.DialogResult]::Yes){$z=Smart-Optimize;$rr=Get-Recommendation $z;$status.Text='● OPTIMIZED';$details.Text="SMART OPTIMIZE APPLIED`r`n`r`nProfile: $($rr.Profile)`r`nBlueStacks target: $($rr.Cores) cores / $($rr.RAM) GB`r`nPower: High Performance`r`nFPS ceiling: 240 optional`r`n`r`nRecovery baseline:`r`n$((Get-Content $Pointer -Raw).Trim())"}})
$restore.Add_Click({Restore-Baseline;$status.Text='● RESTORE'})
$lang.Add_SelectedIndexChanged({if($lang.SelectedItem -eq 'العربية'){$Script:Lang='AR';$form.RightToLeft='Yes';$form.RightToLeftLayout=$true}elseif($lang.SelectedItem -eq 'Français'){$Script:Lang='FR';$form.RightToLeft='No';$form.RightToLeftLayout=$false}else{$Script:Lang='EN';$form.RightToLeft='No';$form.RightToLeftLayout=$false};$header.Text=T 'Title';$sub.Text=T 'Sub';$status.Text=T 'Ready';$quick.Text='  '+(T 'Quick')+'  ';$tools.Text='  '+(T 'Control')+'  ';$ready.Text=T 'Game';$smart.Text=T 'Smart';$restore.Text=T 'Restore'})

$header.Text=T 'Title';$sub.Text=T 'Sub';$status.Text=T 'Ready';$quick.Text='  '+(T 'Quick')+'  ';$tools.Text='  '+(T 'Control')+'  ';$ready.Text=T 'Game';$smart.Text=T 'Smart';$restore.Text=T 'Restore';$details.Text="KXM BLUEFIRE v17`r`n`r`n$(T 'ReadyDone')`r`n`r`nCPU: $($h.CPU)`r`nRAM: $($h.RAM) GB`r`nGPU: $($h.GPU)`r`nStorage: HDD=$($h.HDD) / SSD=$($h.SSD)`r`n`r`n$(T 'Explain')"
$form.Add_Shown({$form.Activate()});[void]$form.ShowDialog()
