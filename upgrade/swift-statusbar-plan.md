# خطة تطوير Mac Monitor بإصدار StatusBar (Swift) — دون ترقية الجهاز

**التاريخ:** 10 يونيو 2026  
**الهدف:** إصدار متطور من Mac Monitor كتطبيق Swift أصلي في شريط القوائم، يعمل على macOS 10.15 Catalina دون الحاجة لـ OCLP أو أجهزة أحدث.

---

## 1. لماذا NSStatusBar وليس MenuBarExtra؟

| المعيار | MenuBarExtra | NSStatusBar |
|----------|--------------|-------------|
| أدنى إصدار macOS | 13 (Ventura) | 10.0 (Cheetah) |
| متوفر على Catalina؟ | ❌ | ✅ |
| يعمل على MacBook Air 7,2؟ | ❌ (يتطلب OCLP) | ✅ (حالياً) |
| نمط الواجهة | `.window` (نافذة منبثقة) | `popUpStatusItem` (نافذة مخصصة) |
| التحكم في التصميم | محدود (SwiftUI window) | كامل (NSView + SwiftUI) |

**الخلاصة:** `NSStatusBar` هو الخيار الوحيد القابل للتطبيق على Catalina، ويمنحنا تحريراً كاملاً في تصميم الواجهة المنبثقة.

---

## 2. الميزات المستهدفة حسب الأولوية

### 2.1 مصفوفة الأولويات (على Catalina)

| الأولوية | الميزة | تعقيد Swift | جاهز من Python؟ | ملاحظات |
|----------|--------|-------------|-----------------|---------|
| **P0** | NSStatusBar أيقونة + CPU/MEM实时 | 🟢 منخفض | لا | العمود الفقري |
| **P0** | Batch Groq API للوصف | 🟡 متوسط | ✅ نعم | نقله من Python |
| **P0** | فرز حسب CPU+MEM مع فلترة | 🟢 منخفض | ✅ نعم | منطق موجود |
| **P0** | قتل عملية (kill PID) | 🟢 منخفض | ✅ نعم | `kill(pid, SIGKILL)` |
| **P1** | شجرة العمليات (Parent→Child) | 🟡 متوسط | لا | قراءة ppid |
| **P1** | SQLite سجل تاريخي | 🟡 متوسط | ✅ جزئياً | تصميم جديد |
| **P1** | قراءة SMC Sensors (حرارة + مراوح) | 🔴 عالي | لا | IOKit + SMC |
| **P2** | تتبع الشبكة لكل عملية | 🟡 متوسط | لا | تشغيل nettop |
| **P2** | تصنيف العمليات (USER/BG/SYSTEM) | 🟢 منخفض | ✅ نعم | نقل المنطق |

---

## 3. المعمارية التقنية

### 3.1 الهيكل العام

```
┌──────────────────────────────────────────────────────────────────────┐
│                       Mac Monitor (Catalina)                        │
│                                                                      │
│  ┌─────────────────────────────────────────┐                        │
│  │  NSStatusBarButton (أيقونة شريط القوائم) │                        │
│  │  ● CPU% + MEM% نص مصغر                     │                        │
│  │  ● لون أحمر/أصفر/أخضر حسب الضغط           │                        │
│  └────────────────┬────────────────────────┘                        │
│                   │ click                                              │
│                   ▼                                                  │
│  ┌─────────────────────────────────────────┐                        │
│  │  NSWindow + Popover (نافذة منبثقة)        │                        │
│  │  ┌─────────────────────────────────────┐ │                        │
│  │  │ علامة تبويب: العمليات النشطة         │ │                        │
│  │  │ ● جدول مع شجرة قابلة للطي            │ │                        │
│  │  │ ● بحث/فلترة                          │ │                        │
│  │  │ ● وصف تلقائي + Groq                  │ │                        │
│  │  ├─────────────────────────────────────┤ │                        │
│  │  │ علامة تبويب: الحرارة والمراوح        │ │                        │
│  │  │ ● CPU: 45°C ● GPU: 38°C ● FAN: 0RPM│ │                        │
│  │  ├─────────────────────────────────────┤ │                        │
│  │  │ علامة تبويب: الشبكة                  │ │                        │
│  │  │ ● ↑ 1.2MB/s ● ↓ 3.5MB/s            │ │                        │
│  │  ├─────────────────────────────────────┤ │                        │
│  │  │ علامة تبويب: السجل التاريخي          │ │                        │
│  │  │ ● رسوم بيانية (آخر ساعة/يوم/أسبوع)   │ │                        │
│  │  └─────────────────────────────────────┘ │                        │
│  └─────────────────────────────────────────┘                        │
│                                                                      │
│  ┌─────────────────────────────────────────┐                        │
│  │  خلفية: مؤقت دوري (كل 2-5 ثوانٍ)          │                        │
│  │  ● SnapshotManager ← ps -A              │                        │
│  │  ● SMCReader ← IOKit                     │                        │
│  │  ● NetworkMonitor ← nettop               │                        │
│  │  ● StorageEngine ← SQLite                │                        │
│  └─────────────────────────────────────────┘                        │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.2 هيكل حزمة Swift

```
MacMonitor/
├── Package.swift
├── Sources/
│   ├── MacMonitorApp.swift          ← @main + NSApplicationDelegate
│   ├── StatusBar/
│   │   ├── StatusBarController.swift  ← NSStatusBar + NSStatusItem
│   │   └── StatusBarIcon.swift        ← رسم الأيقونة ديناميكياً
│   ├── Views/
│   │   ├── PopoverContentView.swift ← NSView + علامات التبويب
│   │   ├── ProcessTableView.swift   ← NSTableView + NSMenu
│   │   ├── ThermalView.swift        ← مقاييس الحرارة والمراوح
│   │   ├── NetworkView.swift        ← سرعة الرفع والتنزيل
│   │   └── HistoryChartView.swift   ← رسوم بيانية تاريخية
│   ├── Models/
│   │   ├── ProcessInfo.swift        ← PID, CPU, MEM, Category, Description
│   │   ├── ThermalSnapshot.swift    ← temps, fan rpms
│   │   └── NetworkSample.swift      ← bytes in/out per interface
│   ├── Services/
│   │   ├── SnapshotManager.swift    ← ps + sysctl + تصنيف
│   │   ├── SMCReader.swift          ← IOKit + SMC keys (قراءة فقط)
│   │   ├── GroqBatcher.swift        ← URLSession + batch API
│   │   ├── DatabaseManager.swift    ← SQLite (GRDB)
│   │   └── NetworkMonitor.swift     ← نصوص nettop الطرفية
│   ├── Utils/
│   │   ├── ProcessClassifier.swift  ← USER_APP / BACKGROUND / SYSTEM
│   │   ├── ProcessTree.swift        ← تجميع ppid
│   │   └── Constants.swift          ← SMC keys, API URLs
│   └── Resources/
│       └── Assets.xcassets
└── Tests/
    └── MacMonitorTests/
```

### 3.3 NSStatusBar الأساس

```swift
import Cocoa

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        guard let button = statusItem.button else { return }
        button.title = "⟳ 0.0"  // ⟳ + CPU%
        button.action = #selector(togglePopover)
        button.target = self

        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.contentViewController = MainViewController()
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }

    func updateIcon(cpu: Double) {
        statusItem.button?.title = String(format: "⟳ %.1f", cpu)
        // تغيير اللون حسب الضغط
        statusItem.button?.attributedTitle = ...
    }
}
```

### 3.4 قراءة SMC للقراءة فقط (حرارة + مراوح)

**المفاتيح المطلوبة — قراءة فقط (RPM + درجات حرارة):**

```swift
struct SMCKey {
    static let cpuTemp    = "TC0P"   // CPU proximity
    static let gpuTemp    = "TG0P"   // GPU proximity  
    static let socTemp    = "Tp09"   // SoC temperature (Apple Silicon)
    static let fanSpeed0  = "F0Ac"   // Fan 1 actual speed
    static let fanSpeed1  = "F1Ac"   // Fan 2 actual speed
    static let fanNum     = "FNum"   // Number of fans
}
```

**ملاحظة:** على MacBook Air 7,2 (Intel i5)، المفاتيح المتاحة هي:
- `TC0P`, `TCXC`, `TG0P`, `TGDD` ← درجات حرارة
- `F0Ac` ← مروحة واحدة فقط (MacBook Air بمروحة واحدة)
- `FNum` ← عدد المراوح

**ستتم القراءة فقط — لا كتابة.** هذا يعني عدم الحاجة لـ Privileged Helper Tool أو صلاحيات جذر لقراءة الحرارة (قراءة IOKit SMC تعمل بصلاحيات المستخدم العادي).

```swift
import IOKit

class SMCReader {
    private var conn: io_connect_t = 0

    func open() -> Bool {
        let service = IOServiceGetMatchingService(
            kIOMasterPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != 0 else { return false }
        return IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS
    }

    func readTemperature(_ key: String) -> Double? {
        // SMCReadKey via IOKit
        // تحويل القيمة الخام من النظام الست عشري إلى درجة مئوية
    }
}
```

### 3.5 Batch Groq API من Swift

```swift
struct GroqBatcher {
    let session = URLSession.shared
    let apiKey: String

    func describe(processNames: [String]) async throws -> [String: String] {
        let prompt = """
        You are a macOS expert. Return a JSON object mapping each process name
        to its short technical description (max 8 words).
        Input: \(JSONEncoder().encode(processNames))
        """

        var req = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpMethod = "POST"
        req.httpBody = try JSONEncoder().encode([
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "system", "content": "Respond with valid JSON only."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2,
            "max_tokens": processNames.count * 25,
            "response_format": ["type": "json_object"]
        ])

        let (data, _) = try await session.data(for: req)
        // فك تشفير الرد
    }
}
```

**⚠️ ملاحظة مهمة:** `async/await` متاح من macOS 10.15. عند استخدامه من Swift على Catalina، يجب:
- استهداف macOS 10.15 في `Package.swift` كأدنى إصدار: `platforms: [.macOS(.v10_15)]`
- أو استخدام الـ completion handler التقليدية

---

## 4. توزيع العمل — ما يُنقل من Python وما يُكتب من صفر

### ✅ يُنقل (المنطق موجود في Python):

| المكون | ملف Python | ملف Swift المقابل |
|--------|-----------|------------------|
| التقاط العمليات | `snapshot.py` | `SnapshotManager.swift` |
| تصنيف العمليات | `classifier.py` | `ProcessClassifier.swift` |
| Batch Groq | `groq_provider.py` | `GroqBatcher.swift` |
| SQLite database | `database.py` | `DatabaseManager.swift` |
| Config | `config.py` | `Constants.swift` |

### 🆕 يُكتب من صفر (غير موجود في Python):

| المكون | السبب |
|--------|-------|
| `StatusBarController.swift` | واجهة شريط القوائم (لم تكن موجودة أصلاً) |
| `SMCReader.swift` | قراءة الحرارة والمراوح (ميزة جديدة) |
| `ProcessTree.swift` | تجميع ppid (ميزة جديدة) |
| `NetworkMonitor.swift` | تتبع الشبكة (ميزة جديدة) |
| `PopoverContentView.swift` | واجهة منبثقة (جديدة كلياً) |
| `HistoryChartView.swift` | رسوم بيانية (جديدة) |

---

## 5. خطة التنفيذ المرحلية

### المرحلة 0 — البنية التحتية (قبل الكتابة)
```
● إنشاء مشروع Swift Package Manager جديد
● إعداد GitHub Actions pipeline لتصريف Universal Binary
● إعداد GRDB/SQLite كمكتبة تابعة
● اختبار تشغيل NSStatusBar بسيط على Catalina
```

### المرحلة 1 — الجوهر (نقل المنطق)
```
● SnapshotManager ← ps + تصنيف + فرز
● GroqBatcher ← URLSession + batch API
● ProcessClassifier + ProcessTree
● DatabaseManager ← SQLite
● ربطها جميعاً في StatusBar icon + Popover
```

### المرحلة 2 — قراءة SMC
```
● SMCReader ← IOKit + AppleSMC
● قراءة: TC0P, TG0P, TCXC, F0Ac
● عرض في علامة تبويب ThermalView
● تلوين الأيقونة حسب الحرارة
```

### المرحلة 3 — الشبكة + السجل التاريخي
```
● NetworkMonitor ← تشغيل nettop بشكل دوري
● قراءة: bytes in/out لكل واجهة
● تخزين في SQLite كل N ثانية
● عرض رسوم بيانية (Core Plot أو Swift Charts?)
```

### المرحلة 4 — تحسينات
```
● علامة تبويب شجرة العمليات مع بحث
● وصف Groq يُطلب تلقائياً للعمليات غير المصنفة
● قتل عملية (حق زر → Kill)
● إعدادات: تردد التحديث، Groq API key
```

---

## 6. الاعتبارات الهندسية على Catalina

| التحدي | الحل |
|--------|------|
| `async/await` متاح؟ | ✅ نعم (macOS 10.15 يدعم Swift Concurrency) |
| `URLSession` مع JSON | ✅ متاح بالكامل |
| `IOKit` للـ SMC | ✅ متاح — قراءة لا تحتاج صلاحيات جذر |
| `NSPopover` + `NSStatusBar` | ✅ متاح منذ macOS 10.0 |
| `SwiftUI` داخل `NSView`؟ | ⚠️ `NSHostingView` يعمل لكن SwiftUI على Catalina محدود |
| `GRDB` (SQLite) | ✅ يدعم macOS 10.12+ |
| `nettop` الطرفي | ✅ متاح على كل إصدارات macOS |
| `Secure coding` + Code Signing | ✅ `xattr -d quarantine` يكفي للاختبار |

**توصية الواجهة:** استخدام `AppKit` (NSTableView, NSView) بدلاً من SwiftUI لضمان التوافق التام والاستقرار على Catalina. يمكن إضافة SwiftUI لاحقاً للمكونات البسيطة عبر `NSHostingView`.

---

## 7. مقارنة مع الإصدار الحالي (Python CLI)

| البعد | Python CLI (حالياً) | Swift StatusBar (المستهدف) |
|-------|-------------------|--------------------------|
| **الواجهة** | طباعة طرفية (جدول) | أيقونة شريط قوائم + نافذة منبثقة |
| **التحديث** | يطبع جدولاً جديداً كاملاً | تحديث الذاكرة + أيقونة حية |
| **وصف Groq** | طلب فردي + احتياطي | Batch (طلب واحد لكل فئة) |
| **SMC Sensors** | ❌ لا يوجد | ✅ حرارة CPU/GPU + سرعة المروحة |
| **SQLite** | ✅ موجود | ✅ موجود (أكثر تنظيماً) |
| **شجرة العمليات** | ❌ لا يوجد | ✅ تجميع ppid |
| **شبكة** | ❌ لا يوجد | ✅ nettop + رسوم |
| **التبعيات** | Python + groq + rich | macOS فقط (no dependencies) |
| **الحجم** | ~500KB | ~5MB (Universal Binary) |

---

## 8. خطة الطوارئ (إذا تعطل شيء)

| السيناريو | الحل |
|-----------|------|
| `IOKit` لا يقرأ SMC على جهاز معين | عرض رسالة "جهازك لا يدعم قراءة SMC" + تعطيل علامة التبويب |
| Groq API يتغير | تحديث الـ endpoint — تطبيق Swift يمكن تحديثه عبر GitHub Actions |
| ذاكرة 8GB لا تكفي | تخفيف وتيرة التحديث إلى 10 ثوانٍ بدل 2 |
| `nettop` لا يعمل كخلفية | استخدام `netstat -I` البديل |
| Catalina يرفض تشغيل التطبيق | `xattr -d com.apple.quarantine` |

---

## 9. متى نبدأ؟

```
جاهز للبدء فوراً:
├── ✅ macOS Catalina 10.15 (حالياً على MacBook Air)
├── ✅ Xcode 12.4 (أقصى حد رسمي — لكننا سنستخدم GitHub Actions للتصريف)
├── ✅ GitHub Actions pipeline (جاهز من upgrade/batch_experiment.py)
├── ✅ منطق Python جاهز للنقل
├── ✅ NSStatusBar + NSPopover (موثق بالكامل)
└── ❌ SMCReader يحتاج مكتبة IOKit (نحتاج كتابة واجهة Swift)
```

**البدء المقترح:** إنشاء مشروع Swift Package Manager في مجلد `MacMonitorApp/`، ثم نقل clasifier + snapshot + database إلى Swift، ثم بناء StatusBar حولها.

---

*تم إعداد هذه الخطة بناءً على متطلبات العمل على macOS 10.15 Catalina دون ترقية العتاد، مع الاستفادة القصوى من NSStatusBar و IOKit للقراءة فقط.*
