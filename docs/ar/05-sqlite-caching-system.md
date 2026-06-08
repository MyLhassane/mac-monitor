# نظام التخزين المؤقت SQLite

تمنع الذاكرة المؤقتة استدعاءات API المتكررة وعمليات whatis البطيئة عبر الجلسات. إنها قاعدة بيانات SQLite بجدول واحد مخزنة في `data/process_cache.db`.

## المخطط

```sql
CREATE TABLE process_cache (
    name        TEXT PRIMARY KEY,  -- اسم العملية (مثلاً "WindowServer")
    description TEXT,              -- وصف نصي عادي
    category    TEXT,              -- USER_APP / BACKGROUND_SERVICE / SYSTEM_CORE
    source      TEXT,              -- cache / hardcoded / whatis / path / groq / fallback
    first_seen  TEXT,              -- طابع زمني ISO8601 لأول ظهور
    last_seen   TEXT,              -- طابع زمني ISO8601 لآخر ظهور
    times_seen  INTEGER DEFAULT 1 -- كم مرة تم التقاط هذه العملية
);
```

### مبررات الأعمدة

**`name` كمفتاح أساسي**: أسماء العمليات هي معرفات فريدة عبر النظام. ملفان تنفيذيان مختلفان لن يكون لهما نفس الاسم الأساسي — إذا حدث، لكانا غير قابلين للتمييز في مخرجات `ps` على أي حال.

**`description`**: يخزن مخرجات أي محرك حلّها (ذاكرة، ثابتة، whatis، مسار، groq، أو احتياط). لا يتم إجراء أي تطبيع — ما تراه هو ما تم حله.

**`category`**: مخزنة بجانب الوصف حتى لا يحتاج البرنامج إلى إعادة تصنيف العمليات المخزنة. هذا أيضاً يسمح بالتجاوزات اليدوية: إذا غيرت فئة عملية في `KNOWN_CLASSES`، ستعكسها الذاكرة.

**`source`**: يتتبع أي محرك أنتج الوصف. يُستخدم بواسطة `resolve_immediate` ليقرر ما إذا كان يثق في القيمة المخزنة. حالياً فقط `source != "groq"` يتم فحصه (نعيد دائماً حل أوصاف groq كل جلسة لأنها من API سحابي وقد تغيرت). يمكن تحسين هذا الاستدلال.

**`first_seen / last_seen / times_seen`**: مقاييس الاستخدام تمكن من:
- تحديد العمليات الدائمة مقابل العابرة
- احتمال انتهاء صلاحية الإدخالات نادرة الظهور (غير مطبّق)
- تصحيح ما يعمل على النظام مع مرور الوقت

## طريقة `set()` — دلالات UPSERT

```python
def set(self, name, description, category, source):
    now = datetime.now().isoformat()
    conn = sqlite3.connect(str(Config.DB_PATH))
    c = conn.cursor()
    c.execute("""
        INSERT INTO process_cache (name, description, category, source, first_seen, last_seen, times_seen)
        VALUES (?, ?, ?, ?, ?, ?, 1)
        ON CONFLICT(name) DO UPDATE SET
            description = excluded.description,
            category = excluded.category,
            source = excluded.source,
            last_seen = excluded.last_seen,
            times_seen = times_seen + 1
    """, (name, description, category, source, now, now))
    conn.commit()
    conn.close()
```

هذا يستخدم صيغة `ON CONFLICT ... DO UPDATE` (UPSERT) في SQLite، المدعومة منذ SQLite 3.24.0 (2018). في الإدراج الأول:
- `first_seen` = الوقت الحالي
- `times_seen` = 1

في التحديثات اللاحقة:
- `description`, `category`, `source` تُستبدل
- `last_seen` يُحدّث
- `times_seen` يزداد

هذا يعني أن العملية التي تظهر عبر جلسات عديدة تبني عدد `times_seen`، وهو مفيد لفهم ما إذا كان شيء ما هو خدمة دائمة أو سكربت لمرة واحدة.

## طريقة `get()`

```python
def get(self, name):
    c.execute("SELECT description, category, source FROM process_cache WHERE name = ?", (name,))
    row = c.fetchone()
    if row:
        return {"description": row[0], "category": row[1], "source": row[2]}
    return None
```

تعيد قاموساً بثلاثة حقول، أو `None` إذا لم يكن اسم العملية في الذاكرة. المُستدعي (`resolve_immediate`) يستخدم حقل `source` ليقرر مقدار الثقة في القيمة:

```python
cached = self.cache.get(name)
if cached and cached["source"] != "groq":
    return cached["description"], category, cached["source"]
```

**لماذا نتخطى إدخالات الذاكرة المصدرة من groq؟** الفكرة هي أن أوصاف Groq قد تتحسن بمرور الوقت (تحديثات النموذج، تعليمات أفضل). بإعادة حل إدخالات groq كل جلسة، يمكن للبرنامج التقاط التحسينات. أوصاف الذاكرة/whatis/المسار حتمية ولن تتغير.

**النتيجة**: في كل جلسة، العمليات التي تم حلها سابقاً بواسطة groq ستظهر لفترة وجيزة "⏳ جارٍ الحل..." في العرض الأول، ثم تحصل على وصفها المخزن. هذا يخلق وميضاً بسيطاً لحوالي 350 عملية في التشغيل الثاني.

**التحسين المحتمل**: إضافة فحص "التقادم" — فقط أعد حل إدخالات groq الأقدم من N يوماً. هذا سيجعل تجربة التشغيل الثاني فورية بالكامل.

## موقع قاعدة البيانات

```python
DB_DIR = Path(".") / "data"
DB_PATH = DB_DIR / "process_cache.db"
```

قاعدة البيانات موجودة في مجلد `data/` داخل المشروع.

## الفحص اليدوي

```bash
# رؤية جميع الأوصاف المخزنة
sqlite3 data/process_cache.db "SELECT name, source, substr(description,1,40) FROM process_cache ORDER BY times_seen DESC LIMIT 20;"

# العد حسب المصدر
sqlite3 data/process_cache.db "SELECT source, COUNT(*) FROM process_cache GROUP BY source;"

# البحث عن العمليات ذات أعلى times_seen
sqlite3 data/process_cache.db "SELECT name, times_seen FROM process_cache ORDER BY times_seen DESC LIMIT 10;"

# مسح الذاكرة
rm data/process_cache.db
```

## حجم الذاكرة

| المقياس | القيمة النموذجية |
|--------|---------------|
| إجمالي الإدخالات | 300-600 |
| متوسط طول الوصف | 36 حرفاً |
| حجم قاعدة البيانات | ~40-80 كيلوبايت |
| معدل النمو | ~10 إدخالات جديدة في اليوم |

SQLite يتعامل مع هذا المقياس بسهولة. لا حاجة لـ VACUUM أو صيانة.
