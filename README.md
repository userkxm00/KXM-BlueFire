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

**KXM BlueFire** is a hardware-aware Windows gaming optimizer designed around a simple rule:

> **Detect first. Back up first. Optimize selectively. Measure the result. Restore cleanly.**

It is primarily designed for **BlueStacks + Free Fire / Free Fire MAX**, while keeping its core optimization modules useful for general Windows gaming.

KXM is deliberately different from aggressive one-click Windows debloat projects. The normal gaming path avoids destructive system removals, keeps experimental changes separated, and makes recovery part of the workflow.

### Design principles

**Hardware-aware:** recommendations depend on CPU, logical processors, RAM, GPU and storage characteristics instead of applying a single preset to every PC.

**Recovery-first:** KXM creates a baseline before system-changing profiles and stores it outside the portable application directory.

**Session-friendly:** the **GAME READY** workflow is intended for daily pre-game preparation rather than permanent system modification for every gaming session.

**Evidence-oriented:** benchmark and verification tools are included so a user can compare system state rather than assuming every tweak improves FPS.

### Free Fire / BlueStacks baseline

BlueStacks currently recommends 4 CPU cores for graphics-intensive apps such as Free Fire. Its current Free Fire guidance also recommends 4 GB or more of memory, High Performance mode and High Frame Rate. The current Free Fire MAX guide documents 4 CPU cores + 4 GB memory with 120 FPS enabled for its 120-FPS configuration.

References:
- [BlueStacks — Free Fire on PC](https://support.bluestacks.com/hc/en-us/articles/360059239591-Free-Fire-on-PC-with-BlueStacks-5)
- [BlueStacks — CPU and memory allocation](https://support.bluestacks.com/hc/en-us/articles/360057205611-How-to-allocate-more-CPU-cores-and-memory-RAM-to-BlueStacks-5)
- [BlueStacks — Free Fire MAX on PC](https://support.bluestacks.com/hc/en-us/articles/43864024050829-Free-Fire-MAX-on-PC-with-BlueStacks-5)

KXM therefore treats this as a **starting profile**, not a universal hard rule:

```text
BlueStacks CPU       4 cores
BlueStacks Memory    4 GB
Performance mode     High Performance
High frame rate      Enabled where supported
FPS target           120 recommended for supported Free Fire MAX setup
240 FPS              Optional ceiling only; not an FPS guarantee
```

BlueStacks currently documents 120–240 FPS settings for supported games, but the actual FPS remains dependent on the game, emulator configuration, hardware and display. See the official [BlueStacks high-FPS guide](https://support.bluestacks.com/hc/en-us/articles/38637938620685-How-to-enable-high-FPS-on-BlueStacks-5).

### Main features

#### ⚡ GAME READY

A lightweight daily pre-game workflow:

- verifies or creates the KXM recovery baseline;
- cleans safe Windows temporary directories;
- flushes DNS;
- activates the configured gaming power plan;
- detects BlueStacks;
- raises the running BlueStacks player process priority when applicable.

GAME READY intentionally does **not** become the automatic path for experimental kernel or graphics-driver registry changes.

#### 🧠 Smart Hardware Detection

KXM evaluates:

- CPU model, cores and logical processors;
- installed RAM;
- GPU(s);
- virtualization state;
- HDD / SSD characteristics;
- BlueStacks installation state.

The result is used to produce a recommendation rather than blindly forcing the same settings on every computer.

#### 🎮 Gaming profiles

The project separates:

- **Recommended Profile** — conservative hardware-aware baseline;
- **Competitive Profile** — stronger gaming-oriented settings where appropriate;
- **Free Fire / BlueStacks guidance** — emulator-focused recommendations;
- **Experimental Lab** — advanced settings requiring explicit user choice and benchmarking.

#### 💾 Recovery-first

Before the first KXM profile that changes the system, a baseline is written under:

`C:\ProgramData\KXM\BlueFire\Backups\YYYYMMDD_HHMMSS`

This is outside the portable KXM directory. The baseline is intended to preserve the pre-KXM state of the configuration areas KXM manages.

Use **Restore Original** / **R - Restore** to restore the captured settings.

> KXM's baseline is a **targeted configuration backup**, not a full disk image and not a replacement for a complete Windows backup.

#### 🔍 Conflict and dependency checks

KXM can inspect conditions that may matter before advanced changes, such as virtualization-related services and commonly used monitoring/overlay tools.

The purpose is to prevent a gaming preset from being applied as if every computer had the same software environment.

#### 📊 Benchmark + Verify

KXM provides system snapshots and verification tools so users can inspect the state before and after optimization.

KXM does not invent FPS results. Actual in-game FPS should be measured inside Free Fire / Free Fire MAX or with an appropriate frame-time/FPS monitoring tool.

#### 🌐 Network tools

The networking layer focuses on conventional Windows networking options such as RSS and TCP auto-tuning, plus optional gaming-oriented configuration.

Latency diagnosis should be treated separately from FPS optimization: ping, packet loss and jitter can be caused by the network path rather than the PC.

#### ⚡ Maximum FPS power plan

KXM can use a dedicated gaming power-plan workflow that creates, activates and verifies a KXM Maximum FPS plan instead of assuming that the currently active power plan is appropriate.

The previous power plan is retained in the recovery/session state where applicable.

### Safety policy

KXM does **not** make the following part of its normal recommended path:

- disabling Microsoft Defender as a default;
- disabling Windows Update as a default;
- disabling the Windows pagefile;
- disabling memory compression as a default;
- blindly forcing MSI mode;
- forcing HPET/timer changes without a specific reason;
- removing Edge/WebView2 as a normal optimization step;
- removing large groups of Windows services blindly;
- modifying game files;
- injecting DLLs;
- bypassing anti-cheat or game security.

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
5. Preview the intended profile
        ↓
6. Apply the selected profile
        ↓
7. Reboot when required
        ↓
8. Benchmark / Verify
        ↓
9. Keep the result or Restore Original
```

For daily gaming:

```text
GAME READY → Launch BlueStacks → Play
```

### Low-end PC policy

On systems with **8 GB RAM and/or HDD storage**, KXM deliberately avoids aggressive "free as much RAM as possible" behavior.

The pagefile remains Windows-managed, memory compression is not treated as something to disable for the normal profile, and services such as SysMain should not be disabled blindly on slow HDD-based systems.

This is important because older systems behave differently from modern SSD/NVMe systems under memory pressure and storage latency.

### Languages

The project is designed around three user-facing languages:

- English
- العربية — Arabic / RTL
- Français

Arabic is treated as a first-class interface requirement rather than text inserted into a legacy console.

### Project status

**v24 is a Community Release Candidate.**

The public `main` branch is intentionally kept clean so users do not accidentally run an obsolete development engine.

Before a production release, the project should be validated on representative Windows installations for:

- PowerShell 5.1 parsing;
- GUI startup;
- hardware detection;
- BlueStacks detection;
- recovery baseline creation;
- restore correctness;
- profile switching;
- reboot-required handling.

### Contributing

Compatibility reports, benchmark comparisons, issues and pull requests are welcome.

A useful compatibility report should include:

- Windows version/build;
- CPU;
- RAM;
- GPU;
- HDD / SSD / NVMe;
- BlueStacks version;
- KXM profile used;
- whether a reboot was performed;
- relevant KXM log output.

Do not upload passwords, tokens, personal files or private system information.

### License

Released under the [MIT License](LICENSE).

---

# العربية

## ما هو KXM BlueFire؟

**KXM BlueFire** هو محسن أداء لويندوز يعتمد على مواصفات الجهاز، ومصمم خصوصًا من أجل:

**GGOS + BlueStacks + Free Fire / Free Fire MAX**.

فلسفة المشروع:

> **افحص أولًا → احفظ الإعدادات أولًا → طبّق المناسب فقط → قِس النتيجة → استرجع بسهولة.**

الهدف ليس تطبيق نفس الـTweaks على كل الأجهزة، بل تحليل الجهاز وتقديم توصيات مناسبة له.

## المبادئ الأساسية

### 🧠 تحليل الجهاز

يقوم KXM بتحليل CPU والـCores والـThreads وRAM وGPU ونوع التخزين HDD/SSD وحالة Virtualization ووجود BlueStacks.

بعد ذلك يعرض توصية بدل تنفيذ كل الخيارات بشكل أعمى.

### 💾 Recovery-first

قبل أول Profile يغيّر إعدادات النظام، ينشئ KXM Baseline داخل:

`C:\ProgramData\KXM\BlueFire\Backups\YYYYMMDD_HHMMSS`

هذا المجلد خارج مجلد KXM المحمول، ويمكن استعماله لاحقًا مع **Restore Original** لإرجاع الإعدادات التي التقطها KXM قبل التعديل.

> النسخة الاحتياطية هي **نسخة إعدادات مستهدفة** وليست Image كاملة للقرص أو بديلًا عن Backup كامل لويندوز.

### ⚡ GAME READY

وضع خفيف للاستخدام اليومي قبل اللعب:

- التحقق من Baseline أو إنشاؤه عند الحاجة؛
- تنظيف الملفات المؤقتة الآمنة؛
- Flush DNS؛
- تفعيل خطة طاقة الألعاب؛
- اكتشاف BlueStacks؛
- رفع أولوية BlueStacks عند تشغيله.

ولا يطبّق GAME READY تعديلات Kernel التجريبية أو تعديلات GPU الحساسة في المسار العادي.

## إعدادات Free Fire وBlueStacks

وفق توثيق BlueStacks الحالي، يتم التوصية بـ **4 أنوية CPU** لتطبيقات رسومية مثل Free Fire، مع 4 GB RAM أو أكثر ووضع High Performance وتفعيل High Frame Rate. وبالنسبة إلى Free Fire MAX، توثيق BlueStacks الحالي يشرح إعداد 4 أنوية + 4 GB + 120 FPS للوضع 120 FPS.

المراجع الرسمية:

- [BlueStacks — Free Fire على الكمبيوتر](https://support.bluestacks.com/hc/ar/articles/360059239591-Free-Fire-on-PC-with-BlueStacks-5)
- [BlueStacks — تخصيص CPU وRAM](https://support.bluestacks.com/hc/en-us/articles/360057205611-How-to-allocate-more-CPU-cores-and-memory-RAM-to-BlueStacks-5)
- [BlueStacks — Free Fire MAX](https://support.bluestacks.com/hc/ar/articles/43864024050829-Free-Fire-MAX-%D8%B9%D9%84%D9%89-%D8%A7%D9%84%D9%83%D9%85%D8%A8%D9%8A%D9%88%D8%AA%D8%B1-%D8%A8%D8%A7%D8%B3%D8%AA%D8%AE%D8%AF%D8%A7%D9%85-BlueStacks-5)

كنقطة بداية:

```text
CPU في BlueStacks    4 Cores
RAM                  4 GB
Performance          High Performance
High Frame Rate      ON عندما يكون مدعومًا
FPS                  120 هدف موصى به
240 FPS              سقف اختياري وليس ضمانًا
```

BlueStacks يتيح حاليًا إعدادات 120–240 FPS لبعض الألعاب المتوافقة، لكن FPS الفعلي يعتمد على اللعبة والجهاز وإعدادات المحاكي والشاشة. راجع [دليل BlueStacks لمعدلات FPS العالية](https://support.bluestacks.com/hc/ar/articles/38637938620685-%D9%83%D9%8A%D9%81%D9%8A%D8%A9-%D8%AA%D9%81%D8%B9%D9%8A%D9%84-FPS-%D8%B9%D8%A7%D9%84%D9%8A-%D8%B9%D9%84%D9%89-BlueStacks-5).

## المميزات الرئيسية

### 🎮 Gaming Profiles

- **Recommended Profile:** بروفايل محافظ حسب الجهاز.
- **Competitive Profile:** إعدادات أقوى عندما تكون مناسبة.
- **Free Fire / BlueStacks:** توصيات مرتبطة بالمحاكي.
- **Experimental Lab:** خيارات متقدمة منفصلة وتتطلب اختيارًا صريحًا واختبارًا.

### 🔍 Conflict / Dependency

يفحص KXM بعض الظروف التي قد تجعل بعض التعديلات غير مناسبة، مثل خدمات مرتبطة بالـVirtualization وبعض برامج الـoverlay أو monitoring.

### 📊 Benchmark / Verify

يمكن مقارنة حالة النظام قبل وبعد التعديل، مع تجنب اختراع أرقام FPS غير مقاسة فعلًا.

### 🌐 Network

يشمل أدوات وإعدادات مثل RSS وTCP auto-tuning وبعض إعدادات الألعاب الاختيارية.

### ⚡ Maximum FPS Power Plan

يمكن لـKXM إنشاء خطة طاقة ألعاب مخصصة وتفعيلها ثم التحقق من أنها أصبحت Active، بدل افتراض أن أي Power Plan حالي مناسب للألعاب.

## سياسة الأمان

المسار العادي في KXM لا يقوم افتراضيًا بـ:

- تعطيل Defender؛
- تعطيل Windows Update؛
- تعطيل Pagefile؛
- تعطيل Memory Compression؛
- Force MSI بشكل أعمى؛
- Force HPET بدون سبب محدد؛
- إزالة Edge/WebView2؛
- حذف عشرات الخدمات عشوائيًا؛
- تعديل ملفات اللعبة؛
- DLL Injection؛
- تجاوز Anti-Cheat.

التعديلات التجريبية منفصلة لأن نفس الـTweak قد يفيد جهازًا ويضر جهازًا آخر.

## طريقة الاستخدام

```text
1. شغّل KXM كمسؤول
        ↓
2. Hardware Audit
        ↓
3. راجع Smart Recommendation
        ↓
4. تأكد من وجود Baseline
        ↓
5. عاين التغييرات
        ↓
6. طبّق Profile
        ↓
7. أعد التشغيل عند الحاجة
        ↓
8. Benchmark / Verify
        ↓
9. احتفظ بالنتيجة أو Restore Original
```

للاستخدام اليومي:

```text
GAME READY → افتح BlueStacks → العب
```

## الأجهزة القديمة و8 GB RAM + HDD

في الأجهزة ذات **8 GB RAM أو HDD** لا يحاول KXM تحرير أكبر قدر ممكن من الذاكرة بأي طريقة.

يبقى Pagefile تحت إدارة Windows، ولا يتم جعل تعطيل Memory Compression أو SysMain جزءًا من المسار الآمن لهذه الفئة من الأجهزة.

## اللغات

- English
- العربية — RTL
- Français

العربية متطلب أساسي في الواجهة وليست مجرد نص يضاف إلى Console قديمة.

## حالة المشروع

**v24 = Community Release Candidate.**

الفرع `main` مقصود أن يبقى نظيفًا حتى لا يحمّل المستخدم نسخة تطويرية قديمة بالخطأ.

قبل إعلان Production Release، يجب اختبار KXM على عدة تكوينات Windows للتحقق من PowerShell 5.1 والـGUI واكتشاف العتاد والاسترجاع وتبديل Profiles وحالات إعادة التشغيل.

## المساهمة

نرحب بـIssues وPull Requests وتقارير التوافق ونتائج Benchmark.

عند الإبلاغ عن مشكلة، أرسل مواصفات الجهاز ونسخة Windows وBlueStacks والـProfile المستخدم والسجلات ذات الصلة، دون رفع بيانات شخصية أو كلمات مرور أو Tokens.

## الترخيص

المشروع تحت [MIT License](LICENSE).

---

# Français

## Qu'est-ce que KXM BlueFire ?

**KXM BlueFire** est un optimiseur Windows conscient du matériel, conçu principalement pour :

**GGOS + BlueStacks + Free Fire / Free Fire MAX**.

Sa philosophie :

> **Analyser d'abord → sauvegarder avant modification → appliquer seulement ce qui est pertinent → mesurer → restaurer proprement.**

Le but n'est pas d'imposer le même ensemble de tweaks à tous les ordinateurs.

## Principes du projet

### 🧠 Détection matérielle

KXM prend en compte :

- CPU ;
- coeurs et threads ;
- RAM ;
- GPU ;
- HDD / SSD ;
- virtualisation ;
- présence de BlueStacks.

Les recommandations sont adaptées à la machine détectée.

### 💾 Recovery-first

Avant le premier profil qui modifie le système, KXM crée une baseline dans :

`C:\ProgramData\KXM\BlueFire\Backups\YYYYMMDD_HHMMSS`

La sauvegarde est placée hors du dossier portable de KXM et sert à restaurer les réglages pris en charge avant les modifications.

> Il s'agit d'une sauvegarde de configuration ciblée, pas d'une image complète de Windows.

### ⚡ GAME READY

Mode léger pour la préparation quotidienne d'une session :

- vérifier ou créer la baseline ;
- nettoyer les fichiers temporaires sûrs ;
- vider le cache DNS ;
- activer le profil d'alimentation jeu ;
- détecter BlueStacks ;
- augmenter la priorité du processus BlueStacks lorsqu'il est actif.

Les modifications Kernel expérimentales restent séparées.

## Free Fire / BlueStacks

La documentation actuelle de BlueStacks recommande 4 coeurs CPU pour les applications graphiquement exigeantes telles que Free Fire, ainsi que 4 GB de mémoire ou plus, le mode High Performance et le High Frame Rate. Pour Free Fire MAX, la documentation actuelle décrit une configuration 4 coeurs + 4 GB + 120 FPS pour le mode 120 FPS.

Références officielles :

- [BlueStacks — Free Fire sur PC](https://support.bluestacks.com/hc/fr-fr/articles/360059239591-Free-Fire-sur-PC-avec-BlueStacks-5)
- [BlueStacks — allocation CPU et RAM](https://support.bluestacks.com/hc/en-us/articles/360057205611-How-to-allocate-more-CPU-cores-and-memory-RAM-to-BlueStacks-5)
- [BlueStacks — Free Fire MAX](https://support.bluestacks.com/hc/fr-fr/articles/43864024050829-Free-Fire-MAX-sur-PC-avec-BlueStacks-5)

Point de départ KXM :

```text
CPU BlueStacks       4 coeurs
Mémoire               4 GB
Mode                 High Performance
High Frame Rate      Activé si supporté
FPS                  120 recommandé selon le jeu
240 FPS              plafond optionnel, pas une garantie
```

BlueStacks documente actuellement des réglages élevés jusqu'à 240 FPS pour certains jeux compatibles. Le FPS réel dépend toutefois du jeu, du matériel, de la configuration de l'émulateur et de l'écran. Voir le [guide BlueStacks High FPS](https://support.bluestacks.com/hc/fr-fr/articles/38637938620685-Comment-activer-un-FPS-%C3%A9lev%C3%A9-sur-BlueStacks-5).

## Fonctionnalités principales

- ⚡ GAME READY
- 🧠 détection matérielle intelligente
- 🎮 profils Recommended / Competitive
- 💾 baseline et restauration
- 🔍 vérifications de conflits et dépendances
- 📊 benchmark et Verify
- 🌐 outils réseau
- ⚡ Maximum FPS Power Plan
- 🧪 laboratoire expérimental séparé
- 🌍 anglais / arabe / français

## Politique de sécurité

Le profil normal de KXM ne désactive pas volontairement :

- Microsoft Defender par défaut ;
- Windows Update par défaut ;
- le Pagefile ;
- la compression mémoire ;
- MSI Mode de façon aveugle ;
- HPET/timer tweaks sans raison spécifique ;
- Edge / WebView2 ;
- de grandes quantités de services Windows sans validation.

KXM ne modifie pas les fichiers du jeu, n'injecte pas de DLL et ne contourne pas les systèmes anti-triche.

## Workflow recommandé

```text
1. Lancer KXM en administrateur
        ↓
2. Audit matériel
        ↓
3. Examiner la recommandation
        ↓
4. Vérifier la baseline
        ↓
5. Prévisualiser les changements
        ↓
6. Appliquer le profil
        ↓
7. Redémarrer si nécessaire
        ↓
8. Benchmark / Verify
        ↓
9. Conserver le résultat ou restaurer l'original
```

Pour une utilisation quotidienne :

```text
GAME READY → lancer BlueStacks → jouer
```

## PC anciens / 8 GB + HDD

Sur une machine avec **8 GB de RAM et/ou un HDD**, KXM évite les stratégies agressives qui cherchent uniquement à afficher plus de RAM libre.

Le Pagefile reste géré par Windows et SysMain n'est pas désactivé aveuglément sur ces configurations.

## Langues

- English
- العربية — RTL
- Français

L'arabe est traité comme une langue de premier niveau dans l'interface et non comme du texte ajouté à une vieille console.

## Statut du projet

**v24 est une Community Release Candidate.**

La branche publique `main` est volontairement maintenue propre afin d'éviter qu'un utilisateur lance un ancien moteur de développement.

Avant une version Production, KXM doit être validé sur plusieurs configurations Windows pour PowerShell 5.1, la GUI, la détection du matériel, la restauration et la gestion des profils.

## Contribuer

Les issues, pull requests, rapports de compatibilité et résultats de benchmark sont les bienvenus.

Merci d'indiquer, lors d'un rapport : version/build Windows, CPU, RAM, GPU, type de stockage, version BlueStacks, profil KXM et logs pertinents.

Ne partagez pas de mots de passe, tokens ou données privées.

## Licence

Projet publié sous [MIT License](LICENSE).
