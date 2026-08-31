# KXM BLUEFIRE v16 - WinForms GUI
# Windows PowerShell 5.1 compatible. Unicode UI is created at runtime.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Root = Join-Path $env:ProgramData 'KXM\BlueFire'
$BackupRoot = Join-Path $Root 'Backups'
$LogRoot = Join-Path $Root 'Logs'
$Pointer = Join-Path $Root 'CURRENT_BASELINE.txt'
$LogFile = Join-Path $LogRoot 'KXM.log'
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null

$L = @{
EN=@{
Title='KXM // BLUEFIRE';Sub='Gaming Performance Suite  •  GGOS / BlueStacks / Free Fire';Ready='● SYSTEM READY';Quick='QUICK PLAY';Game='⚡ GAME READY';Smart='SMART OPTIMIZE';Restore='↶ RESTORE ORIGINAL';Control='CONTROL CENTER';Details='SYSTEM STATUS';Profile='FREE FIRE PROFILE';Audit='Hardware Audit';BS='BlueStacks Engine';CPU='CPU / Scheduler';Net='Network Engine';Storage='Storage / Memory';BG='Background Control';Bench='Benchmark';Verify='Verify';Backup='Backup Center';Lab='Experimental Lab';Clean='Clean + Prepare';Lang='Language';Exit='Exit';FF='FREE FIRE';MAX='FREE FIRE MAX';Safe='SAFE';Competitive='COMPETITIVE';Cores='CPU Cores';Memory='RAM';Mode='Performance';FPS='FPS Ceiling';Explain='Recommendation is a target profile; actual FPS depends on the game, emulator, GPU and display.';RestoreQ='Restore settings captured before KXM changes?';Restored='Restore completed. Reboot Windows.';NoBase='No KXM baseline exists yet.';Baseline='Baseline';ReadyDone='GAME READY COMPLETE';CleanDone='Temporary files cleaned. DNS flushed. High Performance activated.'},
AR=@{
Title='KXM // BLUEFIRE';Sub='مجموعة أداء الألعاب  •  GGOS / BlueStacks / Free Fire';Ready='● النظام جاهز';Quick='التشغيل السريع';Game='⚡ تجهيز اللعب';Smart='تحسين ذكي';Restore='↶ إرجاع الإعدادات';Control='مركز التحكم';Details='حالة النظام';Profile='بروفايل FREE FIRE';Audit='فحص العتاد';BS='محرك BlueStacks';CPU='المعالج / الجدولة';Net='محرك الشبكة';Storage='التخزين / الذاكرة';BG='التحكم بالخلفية';Bench='Benchmark';Verify='تحقق';Backup='مركز النسخ';Lab='المختبر التجريبي';Clean='تنظيف وتجهيز';Lang='اللغة';Exit='خروج';FF='FREE FIRE';MAX='FREE FIRE MAX';Safe='آمن';Competitive='تنافسي';Cores='أنوية CPU';Memory='الذاكرة';Mode='أداء عالٍ';FPS='سقف FPS';Explain='هذه التوصية هدف وليست ضمانًا لمعدل FPS؛ النتيجة تعتمد على اللعبة والمحاكي وكرت الشاشة والشاشة.';RestoreQ='هل تريد إرجاع الإعدادات التي كانت موجودة قبل KXM؟';Restored='اكتملت الاستعادة. أعد تشغيل Windows.';NoBase='لا توجد نسخة أصلية لـKXM حتى الآن.';Baseline='النسخة الأصلية';ReadyDone='اكتمل تجهيز اللعب';CleanDone='تم تنظيف الملفات المؤقتة وتفريغ DNS وتفعيل High Performance.'},
FR=@{
Title='KXM // BLUEFIRE';Sub='Suite de performance gaming  •  GGOS / BlueStacks / Free Fire';Ready='● SYSTEME PRET';Quick='JEU RAPIDE';Game='⚡ GAME READY';Smart='OPTIMISATION SMART';Restore='↶ RESTAURER';Control='CENTRE DE CONTROLE';Details='ETAT DU SYSTEME';Profile='PROFIL FREE FIRE';Audit='Audit materiel';BS='Moteur BlueStacks';CPU='CPU / Scheduler';Net='Moteur reseau';Storage='Stockage / Memoire';BG='Controle arriere-plan';Bench='Benchmark';Verify='Verification';Backup='Centre sauvegarde';Lab='Laboratoire experimental';Clean='Nettoyer + preparer';Lang='Langue';Exit='Quitter';FF='FREE FIRE';MAX='FREE FIRE MAX';Safe='SECURISE';Competitive='COMPETITIF';Cores='Coeurs CPU';Memory='RAM';Mode='Performance';FPS='Plafond FPS';Explain='La recommandation est une cible; le FPS reel depend du jeu, de l emulateur, du GPU et de l ecran.';RestoreQ='Restaurer les reglages captures avant KXM ?';Restored='Restauration terminee. Redemarrez Windows.';NoBase='Aucune sauvegarde KXM pour le moment.';Baseline='Sauvegarde';ReadyDone='GAME READY TERMINE';CleanDone='Fichiers temporaires nettoyes. DNS actualise. High Performance active.'}
}
$Script:Lang='EN'

function T($key){ return [string]$L[$Script:Lang][$key] }
function Log($text){ Add-Content -LiteralPath $LogFile -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$text) -Encoding UTF8 }

function Get-DiskKind {
    $h=$false;$s=$false
    try {
        foreach($d in @(Get-PhysicalDisk -ErrorAction Stop)){
            $m=[string]$d.MediaType
            if($m -match 'HDD'){ $h=$true }
            if($m -match 'SSD'){ $s=$true }
        }
    } catch {}
    if(-not $h -and -not $s){
        try {
            foreach($d in @(Get-CimInstance Win32_DiskDrive)){
                $m=([string]$d.Model+' '+[string]$d.MediaType+' '+[string]$d.InterfaceType)
                if($m -match 'SSD|Solid State|NVMe'){ $s=$true } elseif($m -match 'HDD|Hard Disk|SATA|IDE'){ $h=$true }
            }
        } catch {}
    }
    return [pscustomobject]@{HDD=$h;SSD=$s}
}

function Get-Hardware {
    $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1
    $cs=Get-CimInstance Win32_ComputerSystem
    $g=@(Get-CimInstance Win32_VideoController)
    $dk=Get-DiskKind
    $gpu='Unknown'
    foreach($x in $g){ if($gpu -eq 'Unknown'){ $gpu=[string]$x.Name } else { $gpu += ' | '+[string]$x.Name } }
    $ram=0;if($cs){$ram=[math]::Round($cs.TotalPhysicalMemory/1GB,1)}
    return [pscustomobject]@{
        CPU=if($cpu){[string]$cpu.Name}else{'Unknown'};Cores=if($cpu){[int]$cpu.NumberOfCores}else{0};Threads=if($cpu){[int]$cpu.NumberOfLogicalProcessors}else{0};RAM=$ram;GPU=$gpu;HDD=$dk.HDD;SSD=$dk.SSD;Virtualization=if($cpu){[bool]$cpu.VirtualizationFirmwareEnabled}else{$false}
    }
}

function Get-Recommendation($h){
    $c=4;$m=4
    if($h.Threads -lt 4){$c=2}
    if($h.RAM -lt 8){$m=2}
    $prof='FREE FIRE / 4C-4GB / HIGH PERFORMANCE'
    $disk='HDD-safe'
    if($h.SSD){$disk='SSD-ready'}
    return [pscustomobject]@{Cores=$c;RAM=$m;Profile=$prof;Disk=$disk;FPS='120 recommended; 240 ceiling optional'}
}

function Reg-Snap($p,$n){
    $e=$false;$v=$null;$k='DWord'
    try{$i=Get-ItemProperty -LiteralPath $p -ErrorAction Stop;$q=$i.PSObject.Properties[$n];if($null -ne $q){$e=$true;$v=$q.Value;if($v -is [string]){$k='String'}}}catch{}
    [pscustomobject]@{Path=$p;Name=$n;Exists=$e;Value=$v;Kind=$k}
}
function Reg-Dword($p,$n,$v){try{New-Item -Path $p -Force|Out-Null;New-ItemProperty -Path $p -Name $n -PropertyType DWord -Value $v -Force|Out-Null}catch{}}
function Reg-String($p,$n,$v){try{New-Item -Path $p -Force|Out-Null;New-ItemProperty -Path $p -Name $n -PropertyType String -Value $v -Force|Out-Null}catch{}}
function Restore-Reg($e){if($e.Exists){if($e.Kind -eq 'String'){Reg-String $e.Path $e.Name ([string]$e.Value)}else{Reg-Dword $e.Path $e.Name ([int64]$e.Value)}}else{Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name -ErrorAction SilentlyContinue}}

function Ensure-Baseline {
    if(Test-Path $Pointer){$d=(Get-Content $Pointer -Raw -Encoding UTF8).Trim();if($d -and (Test-Path (Join-Path $d 'Baseline.xml'))){return $d}}
    $d=Join-Path $BackupRoot (Get-Date -Format 'yyyyMMdd_HHmmss');New-Item -ItemType Directory -Path $d -Force|Out-Null
    $st=[ordered]@{Created=(Get-Date).ToString('o');Power=((powercfg /getactivescheme)-join ' ');Registry=New-Object System.Collections.ArrayList;Service=New-Object System.Collections.ArrayList}
    foreach($x in @(@('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile','SystemResponsiveness'),@('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile','NetworkThrottlingIndex'),@('HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl','Win32PrioritySeparation'),@('HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling','PowerThrottlingOff'),@('HKCU:\Software\Microsoft\GameBar','AutoGameModeEnabled'),@('HKCU:\System\GameConfigStore','GameDVR_Enabled'))){$st.Registry.Add((Reg-Snap $x[0] $x[1]))}
    try{$s=Get-CimInstance Win32_Service -Filter "Name='SysMain'";$st.Service.Add([pscustomobject]@{Name='SysMain';Start=[string]$s.StartMode;State=[string]$s.State})}catch{}
    $st|Export-Clixml -LiteralPath (Join-Path $d 'Baseline.xml');powercfg /list|Out-File (Join-Path $d 'PowerPlans.txt') -Encoding UTF8;bcdedit /enum all|Out-File (Join-Path $d 'BCD.txt') -Encoding UTF8
    Set-Content -LiteralPath $Pointer -Value $d -Encoding UTF8;Log ('Baseline: '+$d);return $d
}

function Restore-Baseline {
    if(-not(Test-Path $Pointer)){[System.Windows.Forms.MessageBox]::Show((T 'NoBase'),'KXM // RESTORE')|Out-Null;return}
    $d=(Get-Content $Pointer -Raw -Encoding UTF8).Trim();$f=Join-Path $d 'Baseline.xml'
    if(-not(Test-Path $f)){[System.Windows.Forms.MessageBox]::Show('Baseline.xml missing','KXM // RESTORE')|Out-Null;return}
    $a=[System.Windows.Forms.MessageBox]::Show((T 'RestoreQ'),'KXM // RESTORE',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning)
    if($a -ne [System.Windows.Forms.DialogResult]::Yes){return}
    $st=Import-Clixml $f
    foreach($e in $st.Registry){Restore-Reg $e}
    foreach($s in $st.Service){
        if($s.Start -eq 'Auto'){Set-Service $s.Name -StartupType Automatic}else{if($s.Start -eq 'Manual'){Set-Service $s.Name -StartupType Manual}else{if($s.Start -eq 'Disabled'){Set-Service $s.Name -StartupType Disabled}}}
        if($s.State -eq 'Running'){Start-Service $s.Name}else{if($s.State -eq 'Stopped'){Stop-Service $s.Name -Force}}
    }
    if($st.Power -match '([0-9a-fA-F-]{36})'){powercfg /setactive $Matches[1]|Out-Null}
    Log 'Baseline restored';[System.Windows.Forms.MessageBox]::Show((T 'Restored'),'KXM // RESTORE')|Out-Null
}

function Clean-Temp {
    foreach($d in @($env:TEMP,(Join-Path $env:LOCALAPPDATA 'Temp'),'C:\Windows\Temp')){if(Test-Path $d){Remove-Item -LiteralPath (Join-Path $d '*') -Recurse -Force -ErrorAction SilentlyContinue}}
    ipconfig /flushdns|Out-Null
}
function Find-BS {foreach($p in @("$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe","$env:ProgramFiles\BlueStacks_nxt5\HD-Player.exe","${env:ProgramFiles(x86)}\BlueStacks_nxt\HD-Player.exe","${env:ProgramFiles(x86)}\BlueStacks_nxt5\HD-Player.exe")){if($p -and (Test-Path $p)){return $p}}return $null}
function Game-Ready {
    Ensure-Baseline;Clean-Temp;powercfg /setactive SCHEME_MIN|Out-Null
    $bs=Find-BS;$p=Get-Process -Name 'HD-Player' -ErrorAction SilentlyContinue|Select-Object -First 1
    if($p){try{$p.PriorityClass='AboveNormal'}catch{}}
    Log 'GAME READY executed'
    return [pscustomobject]@{BS=$bs;Running=[bool]$p}
}
function Smart-Optimize {
    Ensure-Baseline;$h=Get-Hardware
    powercfg /setactive SCHEME_MIN|Out-Null
    Reg-Dword 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    Reg-Dword 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
    Reg-Dword 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    Reg-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    $mm='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile';$g="$mm\Tasks\Games"
    Reg-Dword $mm 'SystemResponsiveness' 0;Reg-Dword $mm 'NetworkThrottlingIndex' 4294967295;Reg-Dword $g 'GPU Priority' 8;Reg-Dword $g 'Priority' 6;Reg-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38;Reg-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1
    if($h.HDD -or $h.RAM -le 8){Set-Service SysMain -StartupType Automatic;Start-Service SysMain}
    $bs=Find-BS
    if($bs){Reg-String 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' $bs 'GpuPreference=2;'}
    Log 'Smart Optimize applied';return $h
}
function Apply-Network {Ensure-Baseline;netsh int tcp set global rss=enabled|Out-Null;netsh int tcp set global autotuninglevel=normal|Out-Null;Reg-Dword 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 4294967295;Log 'Network profile applied'}

$form=New-Object System.Windows.Forms.Form
$form.Text='KXM // BLUEFIRE v16';$form.Size=New-Object System.Drawing.Size(1240,790);$form.StartPosition='CenterScreen';$form.BackColor=[System.Drawing.Color]::FromArgb(8,11,16);$form.ForeColor=[System.Drawing.Color]::White;$form.Font=New-Object System.Drawing.Font('Segoe UI',10);$form.FormBorderStyle='FixedSingle';$form.MaximizeBox=$false
$header=New-Object System.Windows.Forms.Label;$header.Location=New-Object System.Drawing.Point(38,24);$header.Size=New-Object System.Drawing.Size(650,50);$header.Font=New-Object System.Drawing.Font('Segoe UI Semibold',25);$header.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200);$form.Controls.Add($header)
$sub=New-Object System.Windows.Forms.Label;$sub.Location=New-Object System.Drawing.Point(42,72);$sub.Size=New-Object System.Drawing.Size(850,30);$sub.ForeColor=[System.Drawing.Color]::Silver;$form.Controls.Add($sub)
$status=New-Object System.Windows.Forms.Label;$status.Location=New-Object System.Drawing.Point(890,32);$status.Size=New-Object System.Drawing.Size(285,42);$status.TextAlign='MiddleRight';$status.Font=New-Object System.Drawing.Font('Segoe UI Semibold',12);$status.ForeColor=[System.Drawing.Color]::FromArgb(120,255,175);$form.Controls.Add($status)

$h=Get-Hardware;$r=Get-Recommendation $h
$dash=New-Object System.Windows.Forms.Panel;$dash.Location=New-Object System.Drawing.Point(32,118);$dash.Size=New-Object System.Drawing.Size(1140,112);$dash.BackColor=[System.Drawing.Color]::FromArgb(18,23,31);$form.Controls.Add($dash)
$cards=@(@('CPU',$h.CPU),@('RAM',("{0} GB" -f $h.RAM)),@('GPU',$h.GPU),@('STORAGE',("HDD={0}  SSD={1}" -f $h.HDD,$h.SSD)),@('PROFILE',$r.Profile))
$x=14;foreach($c in $cards){$p=New-Object System.Windows.Forms.Panel;$p.Location=New-Object System.Drawing.Point($x,14);$p.Size=New-Object System.Drawing.Size(208,84);$p.BackColor=[System.Drawing.Color]::FromArgb(25,31,41);$t=New-Object System.Windows.Forms.Label;$t.Text="$($c[0])`r`n$($c[1])";$t.Dock='Fill';$t.TextAlign='MiddleCenter';$t.ForeColor=[System.Drawing.Color]::White;$p.Controls.Add($t);$dash.Controls.Add($p);$x+=222}

$quick=New-Object System.Windows.Forms.GroupBox;$quick.Location=New-Object System.Drawing.Point(32,248);$quick.Size=New-Object System.Drawing.Size(1140,118);$quick.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200);$form.Controls.Add($quick)
$ready=New-Object System.Windows.Forms.Button;$ready.Text='⚡  GAME READY';$ready.Location=New-Object System.Drawing.Point(18,30);$ready.Size=New-Object System.Drawing.Size(270,66);$ready.Font=New-Object System.Drawing.Font('Segoe UI Semibold',14);$ready.BackColor=[System.Drawing.Color]::FromArgb(0,126,112);$ready.ForeColor=[System.Drawing.Color]::White;$ready.FlatStyle='Flat';$quick.Controls.Add($ready)
$smart=New-Object System.Windows.Forms.Button;$smart.Text='SMART OPTIMIZE';$smart.Location=New-Object System.Drawing.Point(305,30);$smart.Size=New-Object System.Drawing.Size(270,66);$smart.Font=New-Object System.Drawing.Font('Segoe UI Semibold',13);$smart.BackColor=[System.Drawing.Color]::FromArgb(34,44,58);$smart.ForeColor=[System.Drawing.Color]::White;$smart.FlatStyle='Flat';$quick.Controls.Add($smart)
$rest=New-Object System.Windows.Forms.Button;$rest.Text='↶  RESTORE ORIGINAL';$rest.Location=New-Object System.Drawing.Point(592,30);$rest.Size=New-Object System.Drawing.Size(250,66);$rest.Font=New-Object System.Drawing.Font('Segoe UI Semibold',12);$rest.BackColor=[System.Drawing.Color]::FromArgb(68,47,44);$rest.ForeColor=[System.Drawing.Color]::White;$rest.FlatStyle='Flat';$quick.Controls.Add($rest)
$lang=New-Object System.Windows.Forms.ComboBox;$lang.DropDownStyle='DropDownList';$lang.Items.AddRange(@('English','العربية','Français'));$lang.SelectedIndex=0;$lang.Location=New-Object System.Drawing.Point(870,45);$lang.Size=New-Object System.Drawing.Size(225,34);$quick.Controls.Add($lang)

$tools=New-Object System.Windows.Forms.GroupBox;$tools.Text='  CONTROL CENTER  ';$tools.Location=New-Object System.Drawing.Point(32,392);$tools.Size=New-Object System.Drawing.Size(555,300);$tools.ForeColor=[System.Drawing.Color]::FromArgb(0,230,200);$form.Controls.Add($tools)
$details=New-Object System.Windows.Forms.TextBox;$details.Multiline=$true;$details.ReadOnly=$true;$details.ScrollBars='Vertical';$details.Location=New-Object System.Drawing.Point(610,392);$details.Size=New-Object System.Drawing.Size(562,300);$details.BackColor=[System.Drawing.Color]::FromArgb(13,17,23);$details.ForeColor=[System.Drawing.Color]::FromArgb(195,245,236);$details.BorderStyle='FixedSingle';$details.Font=New-Object System.Drawing.Font('Consolas',11);$form.Controls.Add($details)

$toolsData=@(@('Audit','Hardware Audit'),@('BS','BlueStacks Engine'),@('CPU','CPU / Scheduler'),@('Net','Network Engine'),@('Storage','Storage / Memory'),@('BG','Background Control'),@('Bench','Benchmark'),@('Verify','Verify'),@('Backup','Backup Center'))
$row=0;$col=0
foreach($item in $toolsData){
    $b=New-Object System.Windows.Forms.Button;$b.Text=$item[1];$b.Tag=$item[0];$b.Location=New-Object System.Drawing.Point((15+($col*178)),(32+($row*72)));$b.Size=New-Object System.Drawing.Size(165,56);$b.BackColor=[System.Drawing.Color]::FromArgb(27,34,44);$b.ForeColor=[System.Drawing.Color]::White;$b.FlatStyle='Flat';$tools.Controls.Add($b)
    $b.Add_Click({
        $tag=$this.Tag
        $hh=Get-Hardware;$rr=Get-Recommendation $hh
        switch($tag){
            'Audit' {$details.Text=("HARDWARE AUDIT`r`n`r`nCPU: {0}`r`nCores / Threads: {1}/{2}`r`nRAM: {3} GB`r`nGPU: {4}`r`nHDD: {5}`r`nSSD: {6}`r`nVirtualization: {7}`r`n`r`nRECOMMENDED PROFILE`r`n{8}`r`nBlueStacks: {9} cores / {10} GB`r`nFPS: {11}" -f $hh.CPU,$hh.Cores,$hh.Threads,$hh.RAM,$hh.GPU,$hh.HDD,$hh.SSD,$hh.Virtualization,$rr.Profile,$rr.Cores,$rr.RAM,$rr.FPS)}
            'BS' {$details.Text=("BLUESTACKS ENGINE`r`n`r`nPath: {0}`r`nRecommended: {1} cores / {2} GB`r`nMode: High Performance`r`nFPS ceiling: 240 (optional target)" -f (Find-BS),$rr.Cores,$rr.RAM)}
            'CPU' {$details.Text='CPU / SCHEDULER`r`n`r`nSmart Optimize applies the KXM game scheduling profile.`r`nNo forced HPET or unsafe kernel hacks.'}
            'Net' {Apply-Network;$details.Text='NETWORK ENGINE APPLIED`r`n`r`nRSS: enabled`r`nTCP autotuning: normal`r`nNetwork throttling profile: optimized'}
            'Storage' {$details.Text=("STORAGE / MEMORY`r`n`r`nHDD: {0}`r`nSSD: {1}`r`nPagefile: Windows managed`r`nMemory Compression: keep enabled`r`nPolicy: {2}" -f $hh.HDD,$hh.SSD,$rr.Disk)}
            'BG' {$details.Text=("BACKGROUND CONTROL`r`n`r`nHDD: {0}`r`nRAM: {1} GB`r`nSysMain: {2}`r`n`r`nKXM avoids aggressive service killing on low-memory/HDD systems." -f $hh.HDD,$hh.RAM,(if($hh.HDD -or $hh.RAM -le 8){'KEEP AUTO'}else{'OPTIONAL'}))}
            'Bench' {$f=Join-Path $Root ('benchmark_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.txt');@('KXM BLUEFIRE v16',("{0}"-f (Get-Date)),("CPU: {0}"-f $hh.CPU),("RAM: {0} GB"-f $hh.RAM),("GPU: {0}"-f $hh.GPU),("Profile: {0}"-f $rr.Profile))|Set-Content $f -Encoding UTF8;$details.Text=('BENCHMARK SNAPSHOT SAVED`r`n`r`n'+$f)}
            'Verify' {$details.Text=("VERIFY`r`n`r`nPower: {0}`r`nSysMain: {1}`r`nHAGS override: {2}" -f ((powercfg /getactivescheme)-join ' '),(Get-Service SysMain).StartType,(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers').HwSchMode)}
            'Backup' {if(Test-Path $Pointer){$details.Text=('BACKUP CENTER`r`n`r`n'+(Get-Content $Pointer -Raw -Encoding UTF8).Trim())}else{$details.Text=(T 'NoBase')}}
        }
    })
    $col++;if($col -ge 3){$col=0;$row++}
}

$ready.Add_Click({$z=Game-Ready;$status.Text=(T 'Ready');$details.Text=((T 'ReadyDone')+'`r`n`r`n'+(T 'CleanDone')+'`r`n`r`nBlueStacks: '+[string]$z.BS+'`r`nRunning: '+[string]$z.Running)})
$smart.Add_Click({$q=[System.Windows.Forms.MessageBox]::Show('Apply the recommended Free Fire profile: 4 CPU cores / 4 GB RAM target / High Performance?','KXM // Smart Optimize',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question);if($q -eq [System.Windows.Forms.DialogResult]::Yes){$z=Smart-Optimize;$status.Text='● OPTIMIZED';$details.Text=("SMART OPTIMIZE APPLIED`r`n`r`nProfile: {0}`r`nBlueStacks target: {1} cores / {2} GB`r`nPower: High Performance`r`nFPS ceiling: 240 optional`r`n`r`n{3}" -f (Get-Recommendation $z).Profile,(Get-Recommendation $z).Cores,(Get-Recommendation $z).RAM,(Get-Content $Pointer -Raw))}})
$rest.Add_Click({Restore-Baseline;$status.Text='● RESTORE'})
$lang.Add_SelectedIndexChanged({if($lang.SelectedItem -eq 'العربية'){$Script:Lang='AR';$form.RightToLeft='Yes';$form.RightToLeftLayout=$true}elseif($lang.SelectedItem -eq 'Français'){$Script:Lang='FR';$form.RightToLeft='No';$form.RightToLeftLayout=$false}else{$Script:Lang='EN';$form.RightToLeft='No';$form.RightToLeftLayout=$false};$header.Text=T 'Title';$sub.Text=T 'Sub';$status.Text=T 'Ready';$quick.Text='  '+(T 'Quick')+'  ';$tools.Text='  '+(T 'Control')+'  ';$ready.Text=T 'Game';$smart.Text=T 'Smart';$rest.Text=T 'Restore'})

$header.Text=T 'Title';$sub.Text=T 'Sub';$status.Text=T 'Ready';$details.Text=("KXM BLUEFIRE v16`r`n`r`n{0}`r`n`r`n{1} / {2} GB`r`nSysMain: KEEP AUTO on HDD / <=8GB`r`nFPS target: 120 recommended; 240 ceiling optional`r`n`r`n{3}" -f $r.Profile,$r.Cores,$r.RAM,(T 'Explain'))
$form.Add_Shown({$form.Activate()});[void]$form.ShowDialog()
