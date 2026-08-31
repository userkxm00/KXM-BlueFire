# KXM BlueFire

> **Hardware-aware Windows gaming optimizer for GGOS, BlueStacks and Free Fire.**
>
> **Current line:** v24 — Community Release Candidate

[![Windows](https://img.shields.io/badge/platform-Windows-0078D6?style=flat-square&logo=windows)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell)](https://learn.microsoft.com/powershell/)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

---

## English

### What is KXM BlueFire?

**KXM BlueFire** is a hardware-aware Windows gaming optimizer designed around a simple idea:

> **Detect first. Back up first. Optimize selectively. Measure the result. Restore cleanly.**

It is primarily designed for **BlueStacks + Free Fire / Free Fire MAX**, while keeping its core optimization modules usable for general Windows gaming.

KXM is deliberately different from aggressive "one-click Windows debloat" projects. It avoids making destructive system removals part of the normal gaming path and keeps experimental changes separate.

### Why KXM?

KXM is built around four principles:

1. **Hardware awareness** — recommendations depend on CPU, threads, RAM, GPU and storage type instead of blindly applying one preset to every PC.
2. **Recovery first** — KXM creates a baseline before its first system-changing profile and stores it outside the portable application folder.
3. **Session-friendly gaming** — the lightweight **GAME READY** mode is intended for the moment immediately before a gaming session.
4. **Measured changes** — benchmark and verification tools are included so a change can be tested instead of assumed to be beneficial.

### Free Fire / BlueStacks guidance

For current BlueStacks guidance, the official BlueStacks documentation recommends **4 CPU cores** for graphics-intensive apps such as Free Fire. Current Free Fire guidance also recommends **4 GB or more of memory**, High Performance mode, and enabling high frame rate. BlueStacks' current Free Fire MAX guide documents **4 cores + 4 GB + 120 FPS** as the 120-FPS configuration. citeturn380828search1turn380828search8turn380828search0

KXM therefore treats the following as a **starting recommendation**, not a universal hard rule:

```text
BlueStacks CPU       4 cores
BlueStacks Memory    4 GB
Performance mode     High / High Performance
High frame rate      Enabled where supported
FPS target           120 recommended for supported Free Fire MAX setup
240 FPS              Optional ceiling only; not an FPS guarantee
```

BlueStacks currently documents high-FPS settings in the **120–240 FPS range for supported games**, but the actual frame rate remains dependent on the game, emulator configuration, hardware and display. citeturn380828search10

### Main features

#### ⚡ GAME READY

A lightweight pre-game workflow for daily use:

- Verify or create the KXM recovery baseline.
- Clean safe Windows temporary directories.
- Flush DNS.
- Activate the configured high-performance gaming power plan.
- Detect BlueStacks.
- Raise the running BlueStacks player process priority where applicable.

GAME READY is intentionally **not** the place for experimental kernel or graphics-driver registry changes.

#### 🧠 Smart Hardware Detection

KXM evaluates:

- CPU model, cores and logical processors
- Installed RAM
- GPU(s)
- Virtualization availability
- HDD / SSD storage characteristics
- BlueStacks installation state

Recommendations are then adapted to the detected system rather than assuming every PC has the same resources.

#### 🎮 Gaming profiles

The project separates:

- **Recommended Profile** — conservative, hardware-aware baseline.
- **Competitive Profile** — stronger gaming-oriented settings where appropriate.
- **Free Fire / BlueStacks guidance** — tuned around emulator workloads.
- **Experimental Lab** — isolated advanced settings that require explicit user choice and benchmarking.

#### 💾 Recovery-first design

Before the first KXM system-changing profile, a baseline is written under:

`C:\ProgramData\KXM\BlueFire\Backups\YYYYMMDD_HHMMSS`

This is outside the portable KXM folder, so deleting the downloaded application does not automatically delete the recovery data.

The baseline can include KXM-managed registry values, selected service state, the active power scheme and other state required by the implemented recovery workflow.

Use **Restore Original** / **R - Restore** to return to the captured pre-KXM state.

> KXM's baseline is a **targeted configuration backup**, not a full disk image or a replacement for a complete Windows backup.

#### 🔍 Conflict and dependency awareness

Advanced gaming changes can conflict with virtualization or other utilities. KXM therefore aims to detect relevant conditions before applying settings that could be inappropriate for the current environment.

#### 📊 Benchmark + Verify

KXM provides system snapshots and verification tools so you can inspect the current state before and after optimization.

The project intentionally does **not** invent FPS measurements. Actual in-game FPS should be measured inside Free Fire / Free Fire MAX or with an appropriate frame-time/FPS monitoring tool.

#### 🌐 Network tools

The networking module focuses on measured, conventional Windows networking configuration such as RSS and TCP auto-tuning, with optional gaming-oriented settings exposed separately.

For latency diagnosis, KXM can be extended with gateway / public endpoint ping and jitter measurements so users can distinguish a PC configuration problem from an internet-path problem.

### Safety policy

KXM does **not** make the following part of its normal recommended path:

- disabling Microsoft Defender as a default
- disabling Windows Update as a default
- disabling the Windows pagefile
- disabling memory compression as a default
- blindly forcing MSI mode
- forcing HPET/timer changes without a specific reason
- removing Edge/WebView2 as a normal optimization step
- removing large groups of Windows services blindly
- modifying game files
- injecting DLLs
- bypassing anti-cheat or game security

Experimental changes remain separate because a tweak that helps one configuration can hurt another.

### Recommended workflow

```text
1. Launch KXM as Administrator
        ↓
2. Hardware Audit
        ↓
3. Review Smart Recommendation
        ↓
4. Create / verify recovery baseline
        ↓
5. Apply a profile only if you understand the changes
        ↓
6. Reboot when required
        ↓
7. Benchmark / Verify
        ↓
8. Keep the result or Restore Original
```

For daily gaming:

```text
GAME READY → Launch BlueStacks → Play
```

### Important notes for low-end PCs

On systems with **8 GB RAM and/or HDD storage**, KXM intentionally avoids aggressive "make RAM free at all costs" behavior. Pagefile management remains Windows-managed, and low-memory/HDD systems should not blindly disable services such as SysMain merely because an optimization list on the internet recommends it.

This is especially important for older systems where storage latency, memory pressure and background activity interact differently from modern SSD/NVMe systems.

### Languages

The user interface is designed to support:

- 🇬🇧 English
- 🇩🇿 العربية — Arabic / RTL
- 🇫🇷 Français

Arabic is treated as a first-class interface requirement rather than plain text pasted into a legacy console.

### Project status

**v24 is a Community Release Candidate.**

The public `main` branch is intentionally kept clean so users do not accidentally download an obsolete development engine.

Before calling any release "production ready", the project should pass its Windows-side PowerShell/GUI validation, hardware-detection checks and recovery verification on representative machines.

### Contributing

Issues, hardware compatibility reports, benchmark comparisons and pull requests are welcome.

When reporting a problem, include:

- Windows version/build
- CPU
- RAM
- GPU
- HDD / SSD / NVMe
- BlueStacks version
- KXM profile used
- Whether a reboot was performed
- Relevant KXM log output

Do **not** upload personal files, passwords, tokens or private system data.

### License

Released under the [MIT License](LICENSE).

---

# العربية

## ما هو KXM BlueFire؟

**KXM BlueFire** هو محسن أداء لويندوز يعتمد على مواصفات الجهاز، ومصمم خصوصًا من أجل:

**GGOS + BlueStacks + Free Fire / Free Fire MAX**.

الفكرة الأساسية للمشروع:

> **افحص الجهاز أولًا → احفظ الإعدادات أولًا → طبّق المناسب فقط → اختبر النتيجة → استرجع بسهولة عند الحاجة.**

KXM ليس مجرد ملف Registry أو قائمة Tweaks عشوائية. الهدف هو أن يتعامل البرنامج مع الأجهزة المختلفة بطريقة مختلفة بدل إجبار كل جهاز على نفس الإعدادات.

## لماذا KXM؟

المشروع مبني على أربع أفكار:

### 1. 🧠 تحليل الجهاز

يقوم KXM بفحص:

- المعالج CPU
- عدد الأنوية والـThreads
- RAM
- GPU
- نوع التخزين HDD / SSD
- Virtualization
- وجود BlueStacks

ثم يعطي توصية مناسبة نسبيًا لهذا الجهاز.

### 2. 💾 الاسترجاع قبل التعديل

قبل أول Profile يقوم بتعديل النظام، ينشئ KXM نسخة Baseline في:

`C:\ProgramData\KXM\BlueFire\Backups`

أي أن نسخة الاسترجاع ليست داخل مجلد البرنامج المحمول على سطح المكتب.

ومن زر **Restore Original** يمكن إعادة الإعدادات التي كانت موجودة قبل تعديلات KXM ضمن نطاق الإعدادات التي يديرها البرنامج.

> هذه ليست صورة كاملة للقرص وليست بديلًا عن Backup كامل لويندوز.

### 3. ⚡ GAME READY

وضع خفيف للاستخدام اليومي قبل اللعب.

يستطيع تنفيذ:

- تنظيف الملفات المؤقتة الآمنة.
- Flush DNS.
- تفعيل خطة طاقة الأداء العالي.
- اكتشاف BlueStacks.
- رفع أولوية عملية BlueStacks عند توفرها.

ولا يقوم GAME READY بتطبيق تعديلات Kernel التجريبية في المسار العادي.

### 4. 📊 الاختبار والقياس

يوفر KXM أدوات Benchmark وVerify حتى لا نفترض أن كل Tweak يزيد FPS.

الهدف هو معرفة ما إذا كان التغيير أعطى فائدة فعلية على الجهاز المستهدف.

## Free Fire وBlueStacks

وفق توثيق BlueStacks الحالي، يتم التوصية بـ **4 أنوية CPU** لتطبيقات رسومية مثل Free Fire، كما توصي إرشادات Free Fire الحالية بـ4 GB RAM أو أكثر ووضع High Performance وتفعيل High Frame Rate. وبالنسبة إلى Free Fire MAX، يوثق BlueStacks إعداد **4 أنوية + 4 GB + 120 FPS** للوصول إلى إعداد 120 FPS. citeturn380828search1turn380828search8turn380828search0

لذلك تكون نقطة البداية في KXM عادةً:

```text
CPU في BlueStacks    4 Cores
RAM                  4 GB
Performance          High Performance
High Frame Rate      ON عندما يكون مدعومًا
FPS                  120 هدف موصى به
240 FPS              سقف اختياري وليس ضمانًا
```

يدعم BlueStacks حاليًا معدلات مرتفعة بين 120 و240 FPS لبعض الألعاب المدعومة، لكن الرقم الفعلي يعتمد على اللعبة والجهاز والإعدادات والشاشة. citeturn380828search10

## أهم المميزات

- ⚡ GAME READY
- 🧠 Smart Hardware Detection
- 🎮 Recommended / Competitive Profiles
- 💾 Baseline + Restore
- 🔍 Conflict / Dependency Checks
- 📊 Benchmark + Verify
- 🌐 Network tools
- 🧪 Experimental Lab
- 🌍 English / العربية / Français

## سياسة الأمان

KXM لا يجعل بشكل افتراضي:

- تعطيل Defender
- تعطيل Windows Update
- تعطيل Pagefile
- تعطيل Memory Compression
- Force MSI بشكل أعمى
- Force HPET بدون سبب واضح
- إزالة Edge / WebView2
- قتل عدد كبير من خدمات Windows عشوائيًا
- تعديل ملفات اللعبة
- DLL Injection
- تجاوز Anti-Cheat

التعديلات التجريبية منفصلة، لأن نفس الـTweak قد يفيد جهازًا ويضر جهازًا آخر.

## طريقة الاستخدام المقترحة

```text
1. شغّل KXM كمسؤول
        ↓
2. Hardware Audit
        ↓
3. راجع Smart Recommendation
        ↓
4. تأكد من وجود Baseline
        ↓
5. طبّق Profile المناسب
        ↓
6. أعد التشغيل إذا طلب البرنامج
        ↓
7. Benchmark / Verify
        ↓
8. احتفظ بالنتيجة أو Restore Original
```

وللاستخدام اليومي:

```text
GAME READY → افتح BlueStacks → العب
```

## الأجهزة الضعيفة

في أجهزة **8 GB RAM أو HDD** لا نريد تحويل البرنامج إلى "RAM Cleaner" عدواني.

لذلك يحتفظ KXM بالـPagefile بإدارة Windows، ولا يجعل تعطيل SysMain أو تفريغ الذاكرة بشكل قسري جزءًا من المسار الآمن لهذه الفئة من الأجهزة.

## حالة المشروع

**v24 = Community Release Candidate**.

الهدف الآن هو تثبيت الاعتمادية، اختبار الاسترجاع، اختبار اكتشاف العتاد، والتحقق على أجهزة مختلفة قبل وصف الإصدار بأنه Production Release.

## المساهمة

يمكن إرسال:

- تقارير مشاكل
- نتائج Benchmark
- تقارير توافق الأجهزة
- Pull Requests

ويفضل ذكر مواصفات الجهاز ونسخة Windows وBlueStacks وProfile المستخدم.

لا ترفع كلمات مرور أو Tokens أو ملفات شخصية.

---

# Français

## Qu'est-ce que KXM BlueFire ?

**KXM BlueFire** est un optimiseur Windows conscient du matériel, conçu principalement pour :

**GGOS + BlueStacks + Free Fire / Free Fire MAX**.

Sa philosophie est simple :

> **Analyser d'abord → sauvegarder avant modification → appliquer uniquement ce qui est pertinent → mesurer → restaurer proprement si nécessaire.**

KXM ne cherche pas à appliquer aveuglément le même lot de tweaks à tous les PC.

## Pourquoi KXM ?

### 🧠 Analyse matérielle

KXM peut prendre en compte :

- CPU
- Nombre de coeurs et threads
- RAM
- GPU
- HDD / SSD
- Virtualisation
- Présence de BlueStacks

Le profil recommandé est ensuite adapté à la machine détectée.

### 💾 Recovery-first

Avant le premier profil qui modifie le système, KXM crée une baseline dans :

`C:\ProgramData\KXM\BlueFire\Backups`

La sauvegarde est donc séparée du dossier portable de l'application.

Le bouton **Restore Original** permet de revenir à l'état capturé avant les modifications KXM prises en charge.

> Il s'agit d'une sauvegarde de configuration ciblée, pas d'une image complète de Windows.

### ⚡ GAME READY

Un mode léger destiné à la préparation quotidienne d'une session de jeu :

- nettoyage des fichiers temporaires sûrs
- Flush DNS
- activation du profil d'alimentation haute performance
- détection de BlueStacks
- priorité supérieure pour le processus BlueStacks lorsqu'il est disponible

Le mode GAME READY n'applique pas les réglages Kernel expérimentaux du laboratoire.

### 📊 Benchmark et vérification

KXM fournit des snapshots et des outils de vérification afin de comparer l'état du système avant et après une optimisation.

Le projet ne prétend pas mesurer un FPS de jeu qu'il n'a pas réellement mesuré. Les FPS réels doivent être vérifiés dans le jeu ou avec un outil de monitoring approprié.

## Free Fire / BlueStacks

La documentation actuelle de BlueStacks recommande **4 coeurs CPU** pour les applications graphiquement exigeantes comme Free Fire. Les recommandations Free Fire actuelles mentionnent également 4 GB de mémoire ou plus, le mode High Performance et le High Frame Rate. Pour Free Fire MAX, BlueStacks documente actuellement la configuration **4 coeurs + 4 GB + 120 FPS** pour le mode 120 FPS. citeturn380828search1turn380828search8turn380828search0

KXM utilise donc comme point de départ :

```text
CPU BlueStacks       4 coeurs
Mémoire               4 GB
Mode                 High Performance
High Frame Rate      Activé si supporté
FPS                  120 recommandé selon le jeu
240 FPS              plafond optionnel, pas une garantie
```

BlueStacks documente actuellement des plages de 120 à 240 FPS pour certains jeux compatibles. Le FPS réel dépend toutefois du jeu, du matériel, de la configuration de l'émulateur et de l'écran. citeturn380828search10

## Fonctionnalités principales

- ⚡ GAME READY
- 🧠 Détection matérielle intelligente
- 🎮 Profils Recommended / Competitive
- 💾 Baseline et restauration
- 🔍 Détection des conflits et dépendances
- 📊 Benchmark et Verify
- 🌐 Outils réseau
- 🧪 Laboratoire expérimental
- 🌍 Anglais / Arabe / Français

## Politique de sécurité

Le profil normal de KXM ne désactive pas volontairement :

- Microsoft Defender par défaut
- Windows Update par défaut
- le Pagefile
- la compression mémoire
- MSI Mode de façon aveugle
- HPET/timer tweaks sans raison spécifique
- Edge / WebView2
- de grandes quantités de services Windows sans validation

KXM ne modifie pas les fichiers du jeu, n'injecte pas de DLL et ne contourne pas les systèmes anti-triche.

## Workflow recommandé

```text
1. Lancer KXM en administrateur
        ↓
2. Audit matériel
        ↓
3. Examiner la recommandation intelligente
        ↓
4. Vérifier la baseline de récupération
        ↓
5. Appliquer le profil choisi
        ↓
6. Redémarrer si nécessaire
        ↓
7. Benchmark / Verify
        ↓
8. Conserver le résultat ou restaurer l'original
```

Pour le jeu quotidien :

```text
GAME READY → lancer BlueStacks → jouer
```

## PC anciens / entrée de gamme

Sur un PC avec **8 GB de RAM et/ou un HDD**, KXM évite volontairement les stratégies agressives qui cherchent uniquement à afficher plus de RAM libre.

Le Pagefile reste géré par Windows et les services tels que SysMain ne doivent pas être désactivés aveuglément sur une machine lente à base de HDD.

## Statut du projet

**v24 est une Community Release Candidate.**

La branche `main` est volontairement maintenue propre pour éviter qu'un utilisateur télécharge accidentellement un ancien moteur de développement.

Avant une déclaration de version Production, KXM doit encore être validé sur plusieurs configurations Windows pour la syntaxe PowerShell, la détection matériel, la GUI et surtout la restauration.

## Contribuer

Les rapports de compatibilité, benchmarks, issues et pull requests sont les bienvenus.

Pour un rapport utile, indiquez :

- version/build de Windows
- CPU
- RAM
- GPU
- HDD / SSD / NVMe
- version de BlueStacks
- profil KXM utilisé
- redémarrage effectué ou non
- logs KXM pertinents

Ne partagez pas de mots de passe, tokens ou données privées.

## Licence

Projet publié sous [MIT License](LICENSE).
