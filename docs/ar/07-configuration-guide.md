# دليل الإعدادات

كل الإعدادات موجودة في `modules/config.py`. التغييرات تصبح سارية فوراً عند التشغيل التالي — لا خطوة بناء أو ترجمة.

## الثوابت

```python
class Config:
    DB_DIR = Path(".") / "data"
    DB_PATH = DB_DIR / "process_cache.db"
    GROQ_MODEL = "llama-3.1-8b-instant"
    GROQ_MAX_CONCURRENT = 5
    GROQ_DELAY_BETWEEN = 0.4
    GROQ_MAX_RETRIES = 2
    SNAPSHOT_MAX_PER_CATEGORY = 50
    UI_REFRESH_INTERVAL = 0.5
    WHATIS_TIMEOUT = 10
```

### `DB_DIR` / `DB_PATH`
موقع قاعدة بيانات SQLite. القيمة الافتراضية هي `data/process_cache.db` في مجلد المشروع. غيّرها لاستخدام موقع مختلف:
```python
DB_DIR = Path.home() / ".mac-monitor-groq"  # في مجلد المنزل
```

### `GROQ_MODEL`
نموذج Groq المستخدم لتوليد الأوصاف.

| النموذج | السرعة | الجودة | حدود المستوى المجاني |
|-------|-------|---------|------------------|
| `llama-3.1-8b-instant` | ⚡ الأسرع | جيدة | 14,400 طلب/يوم، 500K رمز/يوم |
| `llama-3.3-70b-versatile` | سريع | أفضل | 1,000 طلب/يوم، 100K رمز/يوم |
| `qwen/qwen3-32b` | سريع | أفضل | 60 RPM، 1,000 طلب/يوم |

المقايضة: النموذج 8B يعالج 14,400 طلب/يوم لكنه أحياناً يهلوس (مثلاً يخلط بين Code Helper و Xcode). النموذج 70B أكثر دقة لكن محدود بـ 1,000 طلب/يوم.

### `GROQ_DELAY_BETWEEN`
الحد الأدنى للثواني بين استدعاءات Groq API. يتحكم في تحديد المعدل:
- `0.4` = 150 طلب/دقيقة (قد يصل إلى حد Groq البالغ 30 RPM)
- `2.0` = 30 طلب/دقيقة (آمن، متوافق مع المستوى المجاني)
- `0.0` = أسرع ما يمكن (سيحصل على أخطاء 429)

### `GROQ_MAX_CONCURRENT`
غير مستخدم حالياً (الحل الخلفي يعالج تسلسلياً). محجوز للتنفيذ المتوازي في المستقبل.

### `SNAPSHOT_MAX_PER_CATEGORY`
كم عدد العمليات المعروضة لكل فئة. الافتراضي: 50 لكل قسم = 150 إجمالاً. قلّل إلى 10-20 لعرض مدمج:
```python
SNAPSHOT_MAX_PER_CATEGORY = 15  # أظهر فقط أفضل 15 لكل قسم
```

### `WHATIS_TIMEOUT`
الحد الأقصى للثواني لانتظار استدعاء `whatis` واحد. الافتراضي: 10 ثوانٍ. بعض أسماء الخدمات ذات نتائج صفحات دليل كثيرة (مثل `launchd`) قد تستغرق 8+ ثوانٍ. زد إلى 30 للأجهزة البطيئة جداً، أو قلّل إلى 3 إذا وجدت الانتظار غير مقبول:
```python
WHATIS_TIMEOUT = 3  # تجاوز whatis إذا استغرق أكثر من 3ث
```

### `UI_REFRESH_INTERVAL`
غير مستخدم مباشرة حالياً (الحلقة الرئيسية تستخدم `select.select` بمهلة 0.3 ثانية). محجوز لوظيفة التحديث التلقائي المستقبلية.

## HARDCODED_OVERRIDES

قاموس يصلح هلوسات AI المعروفة. أضف إدخالات هنا عندما تلاحظ أن عملية تحصل باستمرار على وصف خاطئ من Groq.

```python
HARDCODED_OVERRIDES = {
    "Code Helper": "عملية مضيف إضافات VS Code",
    "opencode": "مساعد برمجة CLI مدعوم بـ AI",
    "context7-mcp": "خادم MCP موفر للسياق AI",
    ...
}
```

**إضافة تجاوز جديد:**
1. شغّل المراقب وحدد عملية ذات وصف خاطئ
2. أضف إدخالاً: `"اسم_العملية": "الوصف الصحيح"`
3. أعد تشغيل المراقب — التجاوز يسري فوراً

**ملاحظة**: التجاوزات تنطبق أيضاً على نظام التصنيف. إذا كانت العملية تحتاج فئة مختلفة، أضفها إلى `KNOWN_CLASSES` بدلاً من ذلك.

## KNOWN_CLASSES

قاموس يتجاوز المصنف لعمليات محددة.

```python
KNOWN_CLASSES = {
    "kernel_task": "SYSTEM_CORE",
    "launchd": "SYSTEM_CORE",
    "WindowServer": "SYSTEM_CORE",
    ...
    "configd": "BACKGROUND_SERVICE",
    "amfid": "BACKGROUND_SERVICE",
}
```

**متى تضيف إلى KNOWN_CLASSES مقابل ترك القواعد تتعامل معه:**

| السيناريو | الإجراء |
|----------|--------|
| خدمة مصنفة خطأً كـ USER_APP | أضف إلى KNOWN_CLASSES مع فئتك |
| تطبيق مستخدم مصنف خطأً كـ SYSTEM_CORE | أضف إلى KNOWN_CLASSES مع `USER_APP` |
| لست متأكداً من التصنيف | دع القواعد تتعامل معه؛ تحقق من الفئة المعروضة |

**لماذا لا تصنف كل شيء في KNOWN_CLASSES؟** يغطي القاموس حوالي 20 من أشهر العمليات. التغطية الكاملة ستكون غير عملية (أكثر من 300 عملية فريدة على نظام نموذجي). محرك القواعد يتعامل مع الباقي بدقة معقولة.

## التعليمات النظامية لـ Groq API

التعليمات النظامية المرسلة إلى Groq مثبتة في `groq_provider.py`:

```python
"content": "أنت خبير macOS. قدم وصفاً تقنياً قصيراً "
           "(5-8 كلمات) لاسم عملية macOS المحدد. "
           "لا ماركداون، لا اقتباسات، لا علامات ترقيم في النهاية.",
```

**تخصيص التعليمات**: حرّر هذه السلسلة لتغيير النبرة أو الأسلوب أو تنسيق الأوصاف:

```python
# مثال: أوصاف أكثر تفصيلاً
"content": "Describe the macOS process '{name}' in exactly 10 words. Be specific about its role."

# مثال: نبرة عادية
"content": "Explain what this macOS process does in simple terms, max 8 words."

# مثال: أوصاف بالعربية
"content": "اشرح عملية macOS هذه بوصف تقني مختصر (5-8 كلمات)."
```

ملاحظة: تغيير التعليمات يبطل الذاكرة المؤقتة — الأوصاف القديمة وُلّدت بالتعليمات القديمة. احذف `data/process_cache.db` لفرض إعادة التوليد.

## متغيرات البيئة

| المتغير | مطلوب | الوصف |
|----------|----------|-------------|
| `GROQ_API_KEY` | نعم (لوضع AI) | مفتاح Groq API من console.groq.com |

يمكن تعيين المفتاح عبر:
1. ملف `.env` في جذر المشروع (يُحمّل بواسطة `python-dotenv`)
2. متغير بيئة: `export GROQ_API_KEY="gsk_..."`)
3. كلاهما — `.env` له الأسبقية إذا كان موجوداً

## التحقق من الإعدادات

```bash
# اختبر أن الوحدة تُحمّل بدون أخطاء
python3 -c "from modules import Config; print('OK:', Config.DB_PATH)"

# اختبر مع تجاوز محدد
python3 -c "
from modules import ProcessCache, DescriptionResolver
r = DescriptionResolver()
desc, cat, src = r.resolve_immediate('Code Helper', '/dummy/path', 'USER_APP')
print(f'{src}: {desc}')
"
```
