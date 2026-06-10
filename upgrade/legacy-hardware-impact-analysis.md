# تحليل أثر العتاد القديم على تطوير تطبيق مراقبة macOS

**تاريخ التحليل:** 10 يونيو 2026  
**المراجع:** 
- `upgrade/architecture-analysis.md` — المتطلبات المعمارية
- `upgrade/developing_swift_applications_for_mac_os_using_legacy_hardware.MD` — بيئة التطوير

---

## 1. خلاصة الموقف

**المشكلة:** لبناء تطبيق SwiftUI يتحكم بـ SMC ويقرأ ANE ويوفر REST API، نحتاج Xcode حديث + macOS حديث. العتاد المتاح لا يفي بالغرض منفرداً.

**الحل:** معمارية موزعة ثلاثية الأبعاد — كتابة الكود على HP Z800 (Linux) عبر OpenCode TUI + وكلاء ذكاء اصطناعي، تصريف سحابي عبر GitHub Actions (macOS 14 runner + Xcode 16 + Swift 6)، اختبار محلي على MacBook Air 7,2 (إما Catalina مباشرة أو عبر OCLP).

---

## 2. توزيع المتطلبات حسب مصدر التنفيذ

### 2.1 مصفوفة التوزيع

| المكون | أين يُكتب؟ | أين يُصرف؟ | أين يُختبر؟ |
|--------|-----------|-----------|------------|
| **SwiftUI MenuBarExtra + واجهة المستخدم** | OpenCode (Z800) | GitHub Actions | MacBook Air (OCLP) |
| **SMC Helper Tool (قراءة/كتابة)** | OpenCode (Z800) | GitHub Actions | MacBook Air (OCLP) |
| **قاعدة SQLite التاريخية** | OpenCode (Z800) | GitHub Actions | MacBook Air (Catalina) |
| **REST API (Vapor / Hummingbird)** | OpenCode (Z800) | GitHub Actions | MacBook Air |
| **استدعاءات Groq API** | مكتوبة حالياً (Python) | تُشغل محلياً | MacBook Air (Catalina) |
| **قراءة `IOReport` لتتبع ANE** | OpenCode (Z800) | GitHub Actions | MacBook Air (OCLP) |

### 2.2 دورة التطوير

```
┌─────────────────────────────────────────────────────────────────┐
│  HP Z800 (Linux) — 128GB RAM → OpenCode + Ollama/Gemini        │
│  ● كتابة الكود عبر وكلاء AI ● تحليل معماري ● مراجعة           │
└──────────────────────────┬──────────────────────────────────────┘
                           │ git push
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  GitHub Actions (macOS-14 runner, Xcode 16, Swift 6)           │
│  ● swift build --arch x86_64 --arch arm64                       │
│  ● توقيع بشهادة (اختياري)                                       │
│  ● إنتاج Universal Binary                                       │
└──────────────────────────┬──────────────────────────────────────┘
                           │ download artifact
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  MacBook Air 7,2 (Intel i5, 8GB) → xattr -d quarantine         │
│  ● اختبار تشغيلي ● اختبار الواجهة ● اجتياز Gatekeeper          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. كل متطلب معماري × تحديات العتاد القديم

### 3.1 التحكم بالمراوح عبر SMC (Privileged Helper Tool)

| البعد | التحليل |
|-------|---------|
| **المتطلب** | أداة مساعدة بصلاحيات جذر تتواصل عبر XPC مع التطبيق الرئيسي |
| **التحدي** | Helper Tool يتطلب توقيع بشهادة مطور (Developer ID) لتجاوز Gatekeeper |
| **حل GitHub Actions** | استخراج الشهادة بصيغة `.p12` → Base64 → GitHub Secret → فك التشفير أثناء البناء |
| **اختبار محلي** | بدون شهادة: `xattr -d com.apple.quarantine` + `sudo` يدوي يكفي للاختبار |
| **التوزيع النهائي** | خارج App Store (لأن Sandbox ممنوع للـ Helper) → توزيع مباشر مع Notarization |

**مخاطرة:** شهادة المطور المدفوعة (99$/year) ضرورية للنشر الرسمي، لكنها غير مطلوبة للتطوير والاختبار المحلي.

### 3.2 تتبع محرك ANE عبر IOReport

| البعد | التحليل |
|-------|---------|
| **المتطلب** | استدعاء إطار `IOReport` الخاص غير الموثق |
| **التحدي** | `IOReport` متاح فقط في macOS 12+ (يتطلب OCLP على MacBook Air) |
| **حل GitHub Actions** | التصريف يستهدف `--arch x86_64` ← المخرجات متوافقة مع Intel |
| **اختبار محلي** | OCLP + macOS 14+ ضروري لاختبار IOReport (Catalina لا يدعمه) |
| **بديل احتياطي** | إذا تعذر OCLP → اختبار ANE مؤجل حتى توفر جهاز Apple Silicon حقيقي |

**مخاطرة:** `IOReport` غير موثق وقد يتغير بين إصدارات macOS → حاجة لصيانة مستمرة.

### 3.3 قاعدة SQLite التاريخية

| البعد | التحليل |
|-------|---------|
| **المتطلب** | قراءة دورية للعمليات → تخزين في SQLite → استعراض رسومي |
| **التحدي** | لا تحديات خاصة — SQLite متوافق مع Catalina وحتى Linux |
| **الحل** | Swift + GRDB أو SQLite.swift — تعمل على أي إصدار macOS |
| **اختبار محلي** | يمكن اختباره كاملاً على MacBook Air (Catalina) دون OCLP |

**حالة:** 🟢 لا توجد عقبات تقنية.

### 3.4 REST API (خادم ويب محلي)

| البعد | التحليل |
|-------|---------|
| **المتطلب** | خادم HTTP خفيف داخل التطبيق — Vapor أو Hummingbird |
| **التحدي** | Vapor يتطلب Swift 5.7+ ونظام macOS 12+ (لـ Swift Concurrency) |
| **حل GitHub Actions** | التصريف على macos-14 → Swift 6 → توافق مع x86_64 |
| **اختبار محلي** | OCLP مطلوب لاختبار REST API (Concurrency لا يعمل على Catalina/Xcode 12.4) |
| **بديل احتياطي** | استخدام `Network.framework` مباشرة بدون Vapor يقلص متطلبات النظام |

**حالة:** 🟡 يتطلب OCLP لاختبار الميزات الحديثة (async/await, actors).

### 3.5 SwiftUI MenuBarExtra

| البعد | التحليل |
|-------|---------|
| **المتطلب** | `MenuBarExtra` (متاح من macOS 13+) + `LSUIElement` |
| **التحدي** | MacBook Air على Catalina لا يدعم `MenuBarExtra` |
| **حل GitHub Actions** | تصريف بـ `@available(macOS 13, *)` → يعمل على Sonoma+ فقط |
| **اختبار محلي** | OCLP + macOS 14 ضروري |
| **بديل احتياطي** | استخدام `NSStatusBar` القديم (API متاح من macOS 10.0) للتوافق مع Catalina |

**حالة:** 🔴 الحل الأنيق (`MenuBarExtra`) يتطلب macOS 13+.

### 3.6 إدارة البطارية (SMC keys للشحن)

| البعد | التحليل |
|-------|---------|
| **المتطلب** | كتابة مفاتيح SMC لتحديد الشحن — نفس بنية الـ Helper Daemon |
| **التحدي** | جهاز MacBook Air ملحوم — أي تلف في البطارية بسبب خطأ برمجي يعني تلف الجهاز بالكامل |
| **اختبار محلي** | ممكن على MacBook Air نفسه (بطارية قابلة للاستبدال؟ لا، ملحومة) |
| **مخاطرة** | ⚠️ التجربة على العتاد الوحيد المتاح محفوفة بالمخاطر |
| **توصية** | اختبار SMC keys للبطارية → شراء MacBook مستعمل رخيص (2015-2017) كجهاز تجارب |

**حالة:** 🔴 مخاطرة عالية — يُوصى بجهاز اختبار منفصل.

---

## 4. تحليل خيار OCLP

### هل نرقّي MacBook Air إلى Sonoma/Sequoia عبر OCLP؟

| المعيار | مع Catalina (البقاء) | مع OCLP (الترقية) |
|---------|--------------------|--------------------|
| **اختبار SwiftUI/MenuBarExtra** | ❌ لا يدعم | ✅ يدعم (macOS 14+) |
| **اختبار IOReport/ANE** | ❌ لا يدعم | ✅ يدعم |
| **اختبار REST API (async/await)** | ❌ لا يدعم | ✅ يدعم |
| **اختبار SMC Helper Tool** | ✅ يدعم (يتطلب sudo) | ✅ يدعم |
| **اختبار SQLite** | ✅ يدعم | ✅ يدعم |
| **استقرار النظام** | ✅ ممتاز | ⚠️ مقبول |
| **استهلاك الموارد** | ✅ منخفض | ⚠️ مرتفع (8GB تعاني) |
| **تثبيت Xcode محلي** | ❌ Xcode 12.4 أقصى حد | ✅ ممكن |

**الخلاصة:** OCLP مطلوب لاختبار معظم الميزات الجديدة. لكن الأفضل استخدامه فقط للاختبار، مع الاحتفاظ بقسم Catalina كخيار احتياطي (Dual boot).

### إستراتيجية الترقية المقترحة

```
┌─────────────────────────────────────────────────────┐
│ الخيار الموصى به: Dual Boot عبر OCLP                │
│                                                     │
│  ● القسم A: macOS Catalina (الرسمي)                 │
│    — اختبار SQLite / أدوات سطر الأوامر / Groq API   │
│                                                     │
│  ● القسم B: macOS Sequoia عبر OCLP                  │
│    — اختبار SwiftUI / MenuBarExtra / IOReport       │
│    — اختبار REST API مع async/await                  │
│    — تعطيل المؤثرات الرسومية لتوفير الذاكرة         │
└─────────────────────────────────────────────────────┘
```

---

## 5. توزيع الميزات × الجدوى على العتاد الحالي

| الميزة | الجهد | تعقيد العتاد | الجدوى | يعتمد على OCLP؟ |
|--------|-------|-------------|--------|----------------|
| Batch Groq API (موجود) | 🟢 منخفض | 🟢 لا يوجد | ✅ جاهز | لا |
| Sort by CPU/MEM (موجود) | 🟢 منخفض | 🟢 لا يوجد | ✅ جاهز | لا |
| Python → Swift port | 🟡 متوسط | 🟢 لا يوجد | ✅ قابل | لا |
| Process Tree View | 🟡 متوسط | 🟢 لا يوجد | ✅ قابل | لا |
| SQLite التاريخية | 🟡 متوسط | 🟢 لا يوجد | ✅ قابل | لا |
| REST API + Dashboard | 🔴 عالي | 🟡 متوسط | ⚠️ | نعم (async/await) |
| SMC Fan Control | 🔴 عالي | 🔴 عالي | ⚠️ يتطلب شهادة | لا |
| ANE Monitoring | 🔴 عالي | 🔴 عالي | ⚠️ يتطلب OCLP | نعم |
| Battery Management | 🔴 عالي | 🔴 خطر تلف | ⚠️ جهاز منفصل | لا |
| Per-App Volume | 🟡 متوسط | 🟢 لا يوجد | ✅ قابل | لا |

---

## 6. خريطة طريق التطوير المقترحة

### المرحلة 1 — البنية التحتية (2-4 أسابيع)
```
● تثبيت OpenCode على HP Z800 مع Ollama (qwen2.5-coder)
● إعداد GitHub Actions pipeline للتصريف (macOS-14, Swift 6)
● إعداد OCLP + Sequoia على MacBook Air (Dual Boot)
● Port موجود من Python → Swift CLI tool أساسي
```

### المرحلة 2 — جوهر المراقبة (2-3 أسابيع)
```
● Snapshot + Classification + Batch Groq في Swift
● SQLite local storage + historical queries
● Process Tree View (ppid-based aggregation)
● Sort by CPU/MEM + filtering
```

### المرحلة 3 — واجهة المستخدم (2-3 أسابيع)
```
● MenuBarExtra مع أيقونة CPU/Hit
● MainDashboardView مع جداول ورسوم
● Swift Charts للرسوم البيانية
● دعم RTL كامل (للعربية)
```

### المرحلة 4 — التحكم النشط + المتقدم (4-6 أسابيع)
```
● SMC Helper Tool (Daemon + XPC)
● Fan curve editor UI
● IOReport → ANE estimation
● REST API (Hummingbird)
● Web dashboard (HTML/JS خفيف)
```

### المرحلة 5 — البطارية + النشر (2-3 أسابيع)
```
● Charge limiter + Sailing Mode + Calibration
● Notarization + توزيع
● وثائق + فيديو توضيحي
```

---

## 7. التوصيات النهائية

| الرقم | التوصية | المبرر |
|-------|---------|--------|
| 1 | **ابق على Python للمرحلة الحالية** | Groq + snapshot + SQLite يعملون بكفاءة على MacBook Air (Catalina) بدون أي تعقيد |
| 2 | **ابدأ بـ Swift فقط عند الحاجة لواجهة MenuBar** | `MenuBarExtra` + `NSStatusBar` يتطلبان macOS 13+. أنجز التحكم بالعتاد Swift كأداة CLI أولاً |
| 3 | **استخدم OpenCode على Z800** + **GitHub Actions للتصريف** | أقوى توليفة: كتابة مريحة مع 128GB RAM → بناء سحابي مجاني |
| 4 | **OCLP ضروري لاختبار UI + ANE** | Dual boot يمنعك من فقدان Catalina المستقر |
| 5 | **اشتر جهاز Mac مستعمل (200-300$) كجهاز تجارب للبطارية** | لا تخاطر بالجهاز الوحيد لاختبار SMC keys |
| 6 | **أنجز الميزات التي لا تحتاج OCLP أولاً** | SQLite, Process Tree, Batch Groq, Per-App Volume → كلها تعمل على Catalina |
| 7 | **لا تشترِ شهادة مطور حتى مرحلة النشر** | الاختبار المحلي لا يحتاجها (`xattr` + `sudo` كافيان) |

---

## 8. مصفوفة القرار الحاسمة

```
السؤال: هل ننتظر جهاز Apple Silicon أم نبدأ بـ Swift الآن على العتاد الحالي؟

الإجابة: ابدأ الآن — لكن ابدأ بـ CLI tools (بدون UI).
        
        • الـ CLI tools تعمل على Catalina مباشرة
        • الـ GitHub Actions ينتج Universal Binary (x86_64 + arm64)
        • الـ Swift Package Manager لا يتطلب Xcode GUI
        • OCLP متاح ومجاني لاختبار الـ UI لاحقاً
        
        التأخير الوحيد: اختبار MenuBarExtra + IOReport (يتطلب OCLP)
```

---

*تم إعداد هذا التقرير بناءً على تحليل مقارن بين المتطلبات المعمارية لتطبيق مراقبة macOS وإمكانيات العتاد القديم المتاح، مع خطة تنفيذ مرحلية واقعية.*
