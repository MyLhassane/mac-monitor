# التقاط وتصنيف العمليات

وحدتان تتعاملان مع خط أنابيب البيانات الأولي: `ProcessSnapshot` تلتقط بيانات العملية الخام من النظام، و`ProcessClassifier` تسند كل عملية إلى واحدة من ثلاث فئات أمان.

## ProcessSnapshot — `modules/snapshot.py`

### ماذا تفعل

تشغّل أمر `ps` في macOS وتحلل مخرجاته إلى قائمة من القواميس.

```python
# الأمر الفعلي:
ps -A -o pid,%cpu,%mem,comm
```

| العلم | المعنى |
|------|---------|
| `-A` | جميع العمليات (وليس فقط المتصلة بالطرفية) |
| `-o pid,%cpu,%mem,comm` | تنسيق مخرجات مخصص: PID، CPU%، MEM%، مسار الأمر |

### منطق التحليل

```python
out = subprocess.check_output("ps -A -o pid,%cpu,%mem,comm", shell=True, text=True)
lines = out.strip().split("\n")[1:]  # تخطي الرأس
```

يُقسّم كل سطر على **المسافات مع maxsplit=3** لأن `comm` (مسار الأمر) قد يحتوي على مسافات:

```python
parts = line.split(None, 3)
# parts[0] = PID (int)
# parts[1] = CPU% (float)
# parts[2] = MEM% (float)
# parts[3] = مسار الأمر (string)
```

### القيمة المُعادة

```python
[
    {
        "pid": 1234,          # int — رقم العملية
        "cpu": 12.5,          # float — نسبة استخدام CPU
        "mem": 3.2,           # float — نسبة استخدام الذاكرة
        "cmd": "/usr/bin/python3",  # string — مسار الأمر الكامل
        "name": "python3",    # string — الاسم الأساسي للمسار
        "desc": None,         # str أو None — سيُملأ لاحقاً
        "category": None,     # str — سيُملأ بواسطة المصنف
        "source": None,       # str — مصدر الوصف
        "resolved": False,    # bool — هل الوصف موجود؟
    },
    ...
]
```

### لماذا `comm` وليس `args`؟

`ps -o comm` يعطي مسار الملف التنفيذي (مثلاً `/Applications/Firefox.app/Contents/MacOS/firefox`). `ps -o args` يعطي سطر الأوامر الكامل مع الوسائط، والذي يختلف بشكل كبير وليس مفيداً للتصنيف. الاسم الأساسي لـ `comm` هو اسم العملية (مثلاً `firefox`).

### حالة الحافة: المسارات المقتطعة

يقطع `ps` في macOS المسارات الأطول من ~256 حرفاً. في هذه الحالات، يستخدم البرنامج القيمة المقتطعة. الاسم الأساسي عادةً ما يكون صحيحاً.

---

## ProcessClassifier — `modules/classifier.py`

### ماذا تفعل

تُسند كل عملية إلى واحدة من ثلاث فئات بناءً على اسمها ومسار الأمر. تحدد الفئة:

| الفئة | اللون | قابل للقتل؟ | المعنى |
|----------|-------|-----------|---------|
| `USER_APP` | 🟢 أخضر | نعم | تطبيقات قام المستخدم بتشغيلها |
| `BACKGROUND_SERVICE` | 🟡 أصفر | نعم (بحذر) | خدمات النظام، المساعدون، الوكلاء |
| `SYSTEM_CORE` | 🔴 أحمر | **لا** | عمليات النواة، خدمات النظام المحمية |

### قواعد التصنيف (حسب الأولوية)

```python
@classmethod
def classify(cls, name, cmd):
```

| الأولوية | القاعدة | مثال | الفئة |
|----------|------|---------|----------|
| 1 | إذا كان الاسم في `Config.KNOWN_CLASSES` | `kernel_task`, `launchd`, `WindowServer` | كما هو محدد |
| 2 | إذا كان `cmd` يحتوي على `.app/` | `Finder.app/.../Finder` | `USER_APP` |
| 3 | إذا كان الاسم يبدأ بـ `com.apple.` | `com.apple.geod` | `BACKGROUND_SERVICE` |
| 4 | إذا كان الاسم ينتهي بـ `d` (daemon) ولا يحتوي على `Helper` | `syslogd`, `configd`, `notifyd` | `BACKGROUND_SERVICE` |
| 5 | إذا كان الاسم تطبيقاً معروفاً للمستخدم | `Finder`, `Dock`, `Terminal`, `Activity Monitor` | `USER_APP` |
| 6 | إذا كان `cmd` داخل `/usr/libexec/` | `/usr/libexec/secinitd` | `BACKGROUND_SERVICE` |
| 7 | كل شيء آخر | `Python`, `node`, `Code` | `USER_APP` |

### مبررات القواعد

**القاعدة 1 — KNOWN_CLASSES**: قائمة منسقة يدوياً في `config.py` للعمليات التي لا لبس في تصنيفها. `kernel_task` يجب ألا يكون قابلاً للقتل أبداً؛ `amfid` (Apple Mobile File Integrity) هي خدمة أمنية خلفية.

**القاعدة 2 — `.app/` في المسار**: أي ملف تنفيذي داخل حزمة `.app` هو مكون تطبيق مواجه للمستخدم. هذا يلتقط كلاً من الملفات التنفيذية الرئيسية (`Finder`, `Firefox`) والمساعدين (`Code Helper (Renderer)`, `Brave Browser Helper`).

**القاعدة 3 — بادئة `com.apple.`**: كل وكلاء خلفية Apple يستخدمون اصطلاح التسمية هذا (`com.apple.geod`, `com.apple.dock.extra`).

**القاعدة 4 — اللاحقة `d`**: اصطلاح تسمية تقليدي لخدمات Unix. `syslogd`, `configd`, `notifyd`. استثناء `Helper` يمنع `Code Helper` من التصنيف كخدمة (كان سيحدث لو كانت القاعدة مجرد `name.endswith("d")`).

**القاعدة 5 — تطبيقات المستخدم المعروفة**: قائمة بيضاء صغيرة للعمليات التي ينتهي اسمها بـ `d` (مثل `Finder`... انتظر، `Finder` لا ينتهي بـ `d`). هذا يلتقط بشكل أساسي العمليات التي لا يحتوي مسارها على `.app/` لكنها بوضوح تطبيقات مستخدم.

**القاعدة 6 — `/usr/libexec/`**: الملفات التنفيذية المساعدة الداخلية لـ macOS. دائماً خدمات خلفية.

**القاعدة 7 — الافتراضي**: أي شيء لا يطابق أي قاعدة يُفترض أنه تطبيق مستخدم. هذا افتراضي متحفظ — أفضل إظهاره كقابل للقتل (أخضر) من قفله ضد الإنهاء.

### لماذا لا مصنف تعلم آلة؟

مصنف قائم على القواعد تم اختياره للأسباب التالية:
1. **صفر تبعيات** — لا إطار عمل تعلم آلي، لا تحميل نموذج
2. **حتمي** — نفس العملية تحصل دائماً على نفس الفئة
3. **قابل للتدقيق** — أي شخص يمكنه قراءة الدالة ذات الـ 14 سطراً وفهم سبب تصنيف عملية بطريقة معينة
4. **أداء** — يستغرق ميكروثوانٍ، لا ملي ثوانٍ

### أمثلة على التصنيف

| العملية | `cmd` | الفئة | القاعدة |
|---------|-------|----------|------|
| `kernel_task` | `(kernel)` | `SYSTEM_CORE` | 1 (KNOWN_CLASSES) |
| `launchd` | `/sbin/launchd` | `SYSTEM_CORE` | 1 (KNOWN_CLASSES) |
| `Finder` | `/System/.../Finder.app/...` | `USER_APP` | 2 (`.app/`) |
| `Code Helper (Renderer)` | `/Applications/VS Code.app/...` | `USER_APP` | 2 (`.app/`) |
| `configd` | `/usr/libexec/configd` | `BACKGROUND_SERVICE` | 4 (تنتهي بـ `d`) |
| `com.apple.geod` | `/usr/libexec/geod` | `BACKGROUND_SERVICE` | 3 (`com.apple.`) |
| `Python` | `/usr/bin/python3` | `USER_APP` | 7 (افتراضي) |
| `syslogd` | `/usr/sbin/syslogd` | `BACKGROUND_SERVICE` | 4 (تنتهي بـ `d`) |
