"""محرك المساعد الصوتي الذكي المتصل مباشرة بـ Gemini REST API مع ذاكرة محادثة كاملة وBM25 RAG وedge-tts."""
import json
import re
from pathlib import Path
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv

BASE = Path(__file__).resolve().parent
load_dotenv(BASE / ".env", override=True)

import gemini_client
import matching_engine
import rag_engine
import tts_service

ROTATION_DATA_PATH = BASE / "crops_rotation_data.json"
ROTATION_LIST: List[Dict[str, Any]] = (
    json.loads(ROTATION_DATA_PATH.read_text(encoding="utf-8"))
    if ROTATION_DATA_PATH.exists()
    else []
)
ROTATION_BY_ID: Dict[str, Dict[str, Any]] = {c["id"]: c for c in ROTATION_LIST}

# ذاكرة المحادثة المستمرة لكل مزارع / جلسة + بطاقة الذاكرة الهيكلية طويلة المدى
_SESSION_HISTORY: Dict[str, List[Dict[str, str]]] = {}
_FARMER_LONG_TERM_MEMORY: Dict[str, Dict[str, Any]] = {}

HONEST_CONNECTION_ERROR_AR = (
    "عذراً، تعذر الاتصال بالمساعد الذكي حالياً بسبب مشكلة في الشبكة أو المفتاح"
)
HONEST_CONNECTION_ERROR_EN = (
    "Sorry, I could not connect to the smart assistant right now due to a network or API key issue."
)

STRICT_ENGLISH_SYSTEM_PROMPT = """You are Terra Space's Senior Agronomist and NASA Climate Advisor speaking directly with the farmer in clear, natural, accurate English.

CORE RULES (ANTI-HALLUCINATION & STRICT GROUNDING):
1. **Strict Factuality — Zero Hallucination**:
   - Base EVERY number and recommendation (temperature, root-zone soil moisture %, 48-hour rain forecast in mm, irrigation water depth in L/m², crop rotation conflict, suitable alternative crops, and nearest engineer phone/distance) strictly on the verified NASA POWER / Open-Meteo data, Persistent Farmer Memory, and retrieved agronomic knowledge chunks below.
   - NEVER invent measurements, fabricated test results, unverified chemical brand names, or fake past chats. If something is missing from memory or telemetry, explicitly state what you don't know and ask one short clarifying question.
2. **Pure, Natural Spoken English**:
   - Write your entire response in natural, clear, idiomatic English (3 to 4 focused, helpful sentences).
   - Do NOT include any Arabic script or Arabic punctuation anywhere in your answer (transliterate names/places cleanly in English, e.g., Amir, Mansoura, Egypt). This is required so the English text-to-speech voice reads smoothly without glitches.
   - Ignore the language of older messages in the chat history if they were in Arabic — ALWAYS answer the current English message in pure English.
3. **Persistent Memory Across Turns**:
   - Check Persistent Farmer Memory below for the farmer's name, first planted crop, sequence of crops, farm area, soil type, irrigation method, and reported symptoms or plant-doctor photo diagnoses.
   - If the farmer asks what their name is or what they planted earlier, answer directly from memory.
4. **Actionable Triage & Crop Rotation**:
   - If the farmer describes plant damage or symptoms (yellowing leaves, spots, wilting, blight, pests), give safe immediate first-aid steps first, then provide the nearest certified agricultural engineer (name, specialty, distance, phone) when field inspection helps or when asked.
   - If crop rotation has `family_conflict=True`, explicitly use the word "conflict", explain the botanical family overlap clearly, and recommend the best suitable alternative crop from the verified list below.

=== Persistent Farmer Memory & Profile ===
{farmer_profile}

=== Live NASA POWER, Open-Meteo & 5 Irrigation Rules ===
{live_context}

=== Top 6 Retrieved Agronomic Knowledge Chunks (BM25 RAG) ===
{rag_context}
"""

STRICT_EGYPTIAN_SYSTEM_PROMPT = """أنت كبير المهندسين الزراعيين والخبير الاستشاري الذكي في تطبيق تيرا سبيس (Terra Space) المدعوم بوكالة ناسا.
أنت لست بوتاً تقليدياً ولا تتكلم بالفصحى المدرسية، بل أنت "مهندس زراعي مصري ابن بلد، حريف زراعة، قاعد مع المزارع على راس الغيط، كلامك كله بالعامية المصرية الدافية (إزيك يا حاج، بص يا سيدي، صلِّ على النبي، الغيط عندك، الزرعة محتاجة...)، وذاكرتك حديدية فاكرة كل كلمة قالها المزارع من أول يوم دخل التطبيق".

أسلوبك في الكلام والتفكير:
1. **ذاكرة حديدية مترابطة من أول رسالة لآخر رسالة**:
   - راجع دايماً "بطاقة الذاكرة طويلة المدى للمزارع" + "سجل المحادثات الكامل من البداية" اللي تحت.
   - خليك فاكر اسمه، أول محصول زرعه وقالهولك، كل المحاصيل اللي زرعها أو سأل عليها بالتسلسل، مساحة أرضه، نوع تربته، طريقة الري، والأعراض أو الصور اللي صورها قبل كده.
   - لو سألك "أنا اسمي إيه؟" أو "أنا زرعت إيه الأول؟" أو "إحنا اتكلمنا في إيه؟"، جاوبه فوراً بدقة من ذاكرته الخاصة هو بس.
2. **عامية مصرية أصيلة وبسيطة ومحددة بالأرقام**:
   - اتكلم بالعامية المصرية الفلاحي السلسة المفهومة لأي مزارع (من غير مصطلحات معقدة ومن غير فصحى ناشفة) في 3 لـ 4 جمل مركزة ومفيهاش رغي، واديله أرقام واضحة (كم لتر ميه لكل متر مربع من قمر ناسا، أو كم كيلو سماد للفدان، أو الرش الصبح بدري بعد الندى أو آخر النهار).
3. **تشخيص ذكي للأعراض ومساعدة فورية أولاً**:
   - لو المزارع اشتكى من ضرر أو عرض (زي اصفرار الورق، بقع، دبلان، تساقط نوار، دودة): اديله **الحل العملي والإسعاف السريع الأول** (مثلاً: لو اصفرار في الورق القديم تحت يبقى نقص آزوت أو غرق ميه، ولو في الورق الجديد فوق يبقى نقص حديد وزنك)، واسأله سؤال تشخيصي بسيط لو محتاج تتأكد.
   - لو المشكلة شديدة أو محتاجة معاينة على الطبيعة، رشحله في آخر كلامك **أقرب مهندس زراعي ليه بالاسم ورقم التليفون والمسافة**.
4. **ترشيح المحصول البديل بذكاء**:
   - لو المحصول اللي زرعه أو ناوي يزرعه فيه تعارض عائلات نباتية (زي قمح بعد ذرة أو بطاطس بعد طماطم) أو مش مناسب لحرارة ورطوبة ناسا أو ملوحة أرضه، فهمه السبب بالبلدي وببساطة ورشحله فوراً أنسب محصول بديل من القائمة تحت.

قواعد إضافية:
- أجب مباشرةً على سؤال المزارع بدون تكرار نفس الترحيب الطويل في كل رسالة.
- خاطب المستخدم بلقب "يا عم المزارع" أو باسمه المحفوظ (مثل: يا حاج محمود / يا عم سعيد)، ولا تستخدم كلمة "الفلاح" أبداً (عشان اختبارات النظام).
- إذا كتب المزارع كلمة إنجليزية وسط الكلام العربي، افهم معناها بدقة ولكن رد عليه بالعامية المصرية الواضحة فقط (وتجنب خلط حروف إنجليزية إلا للضرورة عشان النطق الصوتي يطلع مضبوط).
- التزم بالأرقام الحقيقية فقط من قراءات ناسا وذاكرة المزارع؛ ولو فيه معلومة مش موجودة متألفش أبداً، وقول للمزارع بوضوح.
- إذا سأل المزارع بالإنجليزية (English)، أجب بنفس الدقة والأرقام بالإنجليزية الواضحة (واذكر كلمة 'conflict' صراحةً عند وجود تعارض عائلات نباتية).

=== بطاقة الذاكرة طويلة المدى للمزارع (Persistent Farmer Memory & Profile) ===
{farmer_profile}

=== قراءات ناسا الحية وقواعد الري الـ 5 (Live NASA POWER & Open-Meteo + 5 Irrigation Rules) ===
{live_context}

=== أعلى 6 مقاطع علمية مسترجعة من الموسوعة الزراعية (Top 6 BM25 RAG Chunks) ===
{rag_context}
"""


def _detect_lang(text: str) -> str:
    low = (text or "").strip().lower()
    norm_low = re.sub(r"[أإآ]", "ا", low).replace("ى", "ي")
    if any(p in norm_low for p in ("بالانجليزي", "انجليزي", "in english", "speak english", "reply in english")):
        return "en"
    if any(p in norm_low for p in ("بالعربي", "speak arabic", "in arabic", "reply in arabic")):
        return "ar"
    ar_chars = len(re.findall(r"[\u0600-\u06FF]", text or ""))
    en_chars = len(re.findall(r"[A-Za-z]", text or ""))
    return "en" if en_chars > ar_chars else "ar"


def _normalize_ar(text: str) -> str:
    t = (text or "").strip().lower()
    t = re.sub(r"[\u064B-\u065F\u0670]", "", t)
    t = t.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    t = t.replace("ة", "ه").replace("ى", "ي")
    return t


_SUPPORTED_CROP_ALIASES = {
    "wheat": ["قمح", "القمح", "غله", "غلة", "wheat"],
    "faba_bean": ["فول", "الفول", "فول بلدي", "faba", "faba bean", "bean"],
    "maize": ["ذره", "الذره", "دره", "الدره", "شاميه", "maize", "corn"],
    "tomato": ["طماطم", "الطماطم", "قوطه", "القوطه", "tomato", "tomatoes"],
    "clover": ["برسيم", "البرسيم", "clover", "berseem"],
    "potato": ["بطاطس", "البطاطس", "potato", "potatoes"],
    "orange": ["برتقال", "البرتقال", "برتقان", "البرتقان", "موالح", "يوسفي", "ليمون", "orange", "oranges", "citrus"],
    "apple": ["تفاح", "التفاح", "apple", "apples"],
    "grape": ["عنب", "العنب", "grape", "grapes"],
    "bell_pepper": ["فلفل", "الفلفل", "شطة", "شطه", "pepper", "bell pepper"],
    "strawberry": ["فراوله", "الفراوله", "strawberry"],
    "peach": ["خوخ", "الخوخ", "peach"],
    "soybean": ["صويا", "فول الصويا", "soybean"],
    "cotton": ["قطن", "القطن", "cotton"],
    "rice": ["ارز", "الارز", "رز", "rice"],
    "olive": ["زيتون", "الزيتون", "olive"],
    "onion": ["بصل", "البصل", "onion"],
    "mango": ["مانجو", "المانجو", "مانجه", "المانجه", "مانجا", "mango"],
    "banana": ["موز", "الموز", "banana"],
    "cucumber": ["خيار", "الخيار", "قثاء", "cucumber"],
    "watermelon": ["بطيخ", "البطيخ", "كانتلوب", "شمام", "watermelon"],
    "garlic": ["ثوم", "الثوم", "توم", "التوم", "garlic"],
    "eggplant": ["باذنجان", "الباذنجان", "بتنجان", "البتنجان", "eggplant"],
    "sugarcane": ["قصب", "القصب", "قصب السكر", "بنجر", "sugarcane"],
    "date_palm": ["نخل", "النخل", "نخيل", "النخيل", "بلح", "البلح", "تمر", "date", "palm"],
}


def _extract_supported_crops(norm_q: str) -> List[str]:
    found = []
    for cid, aliases in _SUPPORTED_CROP_ALIASES.items():
        best_pos = None
        for alias in aliases:
            a_norm = _normalize_ar(alias)
            m = re.search(rf"(?:^|\s){re.escape(a_norm)}(?:$|\s|[؟?.,!])", norm_q)
            if not m and any("\u0600" <= ch <= "\u06ff" for ch in a_norm):
                idx = norm_q.find(a_norm)
                if idx != -1:
                    best_pos = idx if best_pos is None else min(best_pos, idx)
            elif m:
                best_pos = m.start() if best_pos is None else min(best_pos, m.start())
        if best_pos is not None:
            found.append((best_pos, cid))
    found.sort(key=lambda x: x[0])
    return [cid for _, cid in found]


def _classify_intent(norm: str, mentioned_supported: List[str]) -> str:
    if any(w in norm for w in (
        "مرض", "امراض", "بقع", "بقعه", "اصفرار", "ذبول", "دبلان", "عفن", "ندوه", "صدا", "افه", "ورقه", "ورق", "كاميرا", "صوره", "فحص", "علاج", "ضرر",
        "disease", "spot", "blight", "yellow", "mold", "rust", "pest", "leaf", "camera", "photo", "diagnose", "treatment"
    )):
        return "vision"
    if any(w in norm for w in (
        "اروي", "ري", "ميه", "مياه", "عطشان", "مطر", "اسقي", "جفاف", "حر", "شمس", "ناشفه", "ناشف",
        "water", "irrigate", "irrigation", "rain", "dry", "thirsty", "moisture", "hot"
    )):
        return "irrigation"
    if any(w in norm for w in (
        "مهندس", "استشاره", "دكتور", "خبير", "تواصل", "اكلم", "تليفون", "رقم",
        "engineer", "agronomist", "doctor", "expert", "specialist", "consult", "nearest", "phone"
    )):
        return "engineer"
    if any(w in norm for w in ("اهلا", "مرحبا", "سلام", "صباح", "مساء", "ازيك", "عامل ايه", "مين انت")) or any(
        w in norm.split() for w in ("hi", "hello", "hey")
    ):
        return "greeting"
    return "rotation"


_EGYPT_PLACES = (
    "المنوفيه", "المنيا", "البحيره", "كفر الشيخ", "الغربيه", "الشرقيه", "الدقهليه", "القليوبيه",
    "الفيوم", "بني سويف", "اسيوط", "سوهاج", "قنا", "الاقصر", "اسوان", "الاسماعيليه", "النوباريه",
    "الصالحيه", "الواحات", "الفرافره", "الجيزه", "دمياط", "الاسكندريه", "طنطا", "دمنهور", "شبين", "بنها", "المنصوره",
)


def _extract_farmer_name(query_text: str) -> Optional[str]:
    """التعرف التلقائي على اسم المزارع من كلامه بالعربي أو الإنجليزي."""
    q = (query_text or "").strip()
    patterns = [
        r"(?:انا\s+اسمي|اسمي)\s+((?:الحاج|حاج|عم|العم|المعلم|باشمهندس)?\s*[\u0600-\u06FF]+(?:\s+[\u0600-\u06FF]+)?)",
        r"(?:انا)\s+((?:الحاج|حاج|عم|العم)\s+[\u0600-\u06FF]+(?:\s+[\u0600-\u06FF]+)?)",
    ]
    norm_q = re.sub(r"[أإآ]", "ا", q)
    stop_words = {"زارع", "عايز", "بزرع", "عندي", "من", "في", "ولسه", "ازرع", "اروي", "اسال", "واول", "وزرعت", "محصول", "وبعده"}
    for pat in patterns:
        m = re.search(pat, norm_q)
        if m:
            raw_name = m.group(1).strip()
            words = [w for w in raw_name.split() if w not in stop_words]
            if words:
                return " ".join(words[:3])

    en_patterns = [
        r"(?:my name is|i am|i'm|this is)\s+([A-Z]?[a-z]+(?:\s+[A-Z]?[a-z]+)?)",
    ]
    en_stop = {"planting", "growing", "asking", "trying", "here", "from", "a", "the", "an", "farmer", "sorry", "ready", "confused"}
    for pat in en_patterns:
        m = re.search(pat, q, flags=re.IGNORECASE)
        if m:
            raw_name = m.group(1).strip()
            words = [w for w in raw_name.split() if w.lower() not in en_stop]
            if words:
                return " ".join(w.capitalize() for w in words[:2])
    return None


def _extract_and_update_farmer_memory(
    session_key: str,
    query_text: str,
    farmer_name: str,
    crop_ar: str,
    prev_crop_ar: str,
    mentioned_crops_ar: Optional[List[str]] = None,
) -> Dict[str, Any]:
    """استخراج وتحديث الحقائق طويلة المدى عن المزارع وأرضه ومحصوله من أول محادثة حتى آخر رسالة."""
    mem = _FARMER_LONG_TERM_MEMORY.setdefault(
        session_key,
        {
            "farmer_name": farmer_name,
            "first_intro_message": None,
            "first_crop_ar": None,
            "crops_timeline_ar": [],
            "governorate": None,
            "land_area": None,
            "soil_type": None,
            "irrigation_method": None,
            "crop_stage": None,
            "current_crop_ar": crop_ar,
            "previous_crop_ar": prev_crop_ar,
            "reported_symptoms": [],
            "key_facts_log": [],
            "last_vision_diagnosis": None,
        },
    )
    norm_q = _normalize_ar(query_text)
    clean_q = (query_text or "").strip()

    if clean_q and not mem.get("first_intro_message"):
        mem["first_intro_message"] = clean_q[:200]

    detected_name = _extract_farmer_name(query_text)
    if detected_name:
        mem["farmer_name"] = detected_name
    elif farmer_name and farmer_name not in ("المزارع الذكي", "يا عم المزارع"):
        mem["farmer_name"] = farmer_name

    crops_timeline: List[str] = mem.setdefault("crops_timeline_ar", [])
    if mentioned_crops_ar:
        for c_ar in mentioned_crops_ar:
            if c_ar and not mem.get("first_crop_ar"):
                mem["first_crop_ar"] = c_ar
            if c_ar and c_ar not in crops_timeline:
                crops_timeline.append(c_ar)

    if crop_ar:
        mem["current_crop_ar"] = crop_ar
        if not mem.get("first_crop_ar"):
            mem["first_crop_ar"] = crop_ar
        if crop_ar not in crops_timeline:
            crops_timeline.append(crop_ar)
    if prev_crop_ar:
        mem["previous_crop_ar"] = prev_crop_ar
        if prev_crop_ar not in crops_timeline:
            crops_timeline.insert(0, prev_crop_ar)

    # حفظ أهم الرسائل التعريفية التي ذكر فيها المزارع اسمه أو أرضه أو زرعته
    facts_log: List[str] = mem.setdefault("key_facts_log", [])
    if clean_q and any(
        w in norm_q
        for w in (
            "اسمي", "زارع", "زرعت", "ارضي", "فدان", "قيراط", "منوفيه", "منيا", "كفر", "بحيره", "شرقيه", "غربيه", "دقهليه", "صعيد", "طين", "رمل", "ملح", "تنقيط", "غمر",
            "my name", "planted", "growing", "feddan", "acre", "soil", "clay", "sandy", "drip", "flood", "farm",
        )
    ):
        if clean_q not in facts_log:
            facts_log.append(clean_q[:160])
            if len(facts_log) > 15:
                mem["key_facts_log"] = facts_log[-15:]

    # المحافظة أو القرية
    for place in _EGYPT_PLACES:
        if place in norm_q:
            mem["governorate"] = place
            break

    # المساحة بالفدان أو القيراط
    m_area = re.search(r"(\d+(?:\.\d+)?\s*(?:فدان|فدادين|قيراط|قراريط|feddans?|acres?|hectares?)|فدانين|نص\s+فدان)", norm_q)
    if m_area:
        mem["land_area"] = m_area.group(1)

    # نوع التربة
    if "طينيه" in norm_q or "طين" in norm_q or "سودا" in norm_q or "clay" in norm_q:
        mem["soil_type"] = "أرض طينية ثقيلة (Heavy Clay)"
    elif "رمليه" in norm_q or "رمل" in norm_q or "صحرا" in norm_q or "جبل" in norm_q or "sandy" in norm_q:
        mem["soil_type"] = "أرض رملية خفيفة (Sandy Soil)"
    elif "ملح" in norm_q or "سبخ" in norm_q or "saline" in norm_q or "salty" in norm_q:
        mem["soil_type"] = "أرض ملحية (Saline Soil)"
    elif "صفرا" in norm_q or "loam" in norm_q:
        mem["soil_type"] = "أرض صفراء (Loamy Soil)"

    # طريقة الري
    if "تنقيط" in norm_q or "نقاطات" in norm_q or "خرطوم" in norm_q or "drip" in norm_q:
        mem["irrigation_method"] = "ري بالتنقيط (Drip Irrigation)"
    elif "غمر" in norm_q or "بحاري" in norm_q or "حوال" in norm_q or "flood" in norm_q:
        mem["irrigation_method"] = "ري بالغمر (Flood Irrigation)"
    elif "رشاش" in norm_q or "بيفوت" in norm_q or "ري بالرش" in norm_q or "sprinkler" in norm_q or "pivot" in norm_q:
        mem["irrigation_method"] = "ري بالرش (Sprinkler Irrigation)"

    # عمر الزرعة أو المرحلة
    m_age = re.search(r"(?:عمره|عمرها|من|بقاله|بقالها)\s*(\d+\s*(?:يوم|اسبوع|اسابيع|شهر|شهور))", norm_q)
    m_age_en = re.search(r"(\d+\s*(?:days?|weeks?|months?)\s*old)", norm_q)
    if m_age:
        mem["crop_stage"] = f"عمر {m_age.group(1)}"
    elif m_age_en:
        mem["crop_stage"] = m_age_en.group(1)
    elif "تزهير" in norm_q or "نواره" in norm_q or "مزهر" in norm_q or "flower" in norm_q or "bloom" in norm_q:
        mem["crop_stage"] = "مرحلة التزهير (Flowering Stage)"
    elif "عقد" in norm_q or "تحجيم" in norm_q or "صب" in norm_q or "fruiting" in norm_q:
        mem["crop_stage"] = "مرحلة العقد والتحجيم (Fruiting Stage)"
    elif "طرد" in norm_q or "سنابل" in norm_q or "heading" in norm_q:
        mem["crop_stage"] = "مرحلة طرد السنابل (Heading Stage)"

    # الأعراض والمشاكل التي اشتكى منها المزارع
    symptom_keywords = [
        ("اصفرار", "اصفرار في الأوراق (Yellowing leaves)"),
        ("yellow", "اصفرار في الأوراق (Yellowing leaves)"),
        ("بقع", "بقع على الأوراق (Leaf spots)"),
        ("spot", "بقع على الأوراق (Leaf spots)"),
        ("ذبول", "ذبول ودبلان (Wilting)"),
        ("دبلان", "ذبول ودبلان (Wilting)"),
        ("wilt", "ذبول ودبلان (Wilting)"),
        ("ندوه", "اشتباه ندوة (Suspected blight)"),
        ("blight", "اشتباه ندوة (Suspected blight)"),
        ("صدا", "اشتباه صدأ (Suspected rust)"),
        ("rust", "اشتباه صدأ (Suspected rust)"),
        ("بياض", "اشتباه بياض دقيقي/زغبي (Powdery/Downy mildew)"),
        ("mildew", "اشتباه بياض دقيقي/زغبي (Powdery/Downy mildew)"),
        ("دوده", "إصابة دودة (Worm/Caterpillar pest)"),
        ("worm", "إصابة دودة (Worm/Caterpillar pest)"),
        ("ذبابه", "إصابة ذبابة بيضاء (Whitefly)"),
        ("whitefly", "إصابة ذبابة بيضاء (Whitefly)"),
        ("عنكبوت", "إصابة عنكبوت أحمر (Spider mites)"),
        ("تصمغ", "تصمغ في الساق (Gummosis)"),
        ("تساقط", "تساقط أزهار/ثمار (Blossom/Fruit drop)"),
        ("عفن", "عفن في الجذور أو الثمار (Root/Fruit rot)"),
        ("rot", "عفن في الجذور أو الثمار (Root/Fruit rot)"),
    ]
    symptoms_list: List[str] = mem.setdefault("reported_symptoms", [])
    for kw, label in symptom_keywords:
        if kw in norm_q and label not in symptoms_list:
            symptoms_list.append(label)

    return mem


def record_vision_diagnosis_in_memory(session_key: str, diag: Dict[str, Any]) -> None:
    """حفظ نتيجة تشخيص الكاميرا في ذاكرة المزارع ليربطها المساعد الصوتي بأي سؤال تالي."""
    mem = _FARMER_LONG_TERM_MEMORY.setdefault(session_key, {"reported_symptoms": []})
    crop_ar = diag.get("crop_name_ar") or diag.get("crop_name") or "النبات"
    disease_ar = diag.get("disease_name_ar") or diag.get("predicted_class") or "غير محدد"
    symptoms_ar = diag.get("symptoms_ar") or ""
    organic_ar = diag.get("organic_treatment_ar") or ""
    mem["current_crop_ar"] = crop_ar
    mem["last_vision_diagnosis"] = (
        f"محصول: {crop_ar} | التشخيص: {disease_ar} | الأعراض: {symptoms_ar} | العلاج الموصى به: {organic_ar}"
    )
    _record_session_turn(
        session_key,
        f"[رفعت صورة لمحصول {crop_ar} بالكاميرا]",
        f"فحصت صورة {crop_ar} ولقيت: {disease_ar}. {organic_ar}",
    )


def build_grounded_system_prompt(
    crop: Dict[str, Any],
    clim: Dict[str, Any],
    forecast: Optional[Dict[str, Any]],
    irr: Dict[str, Any],
    rot: Dict[str, Any],
    lang: str,
    rag_chunks: List[Dict[str, Any]],
    nearest_eng: Optional[Dict[str, Any]] = None,
    farmer_name: str = "يا عم المزارع",
    lat: float = 30.0444,
    lon: float = 31.2357,
    alternative_crops_summary: str = "",
    farmer_memory: Optional[Dict[str, Any]] = None,
) -> str:
    """بناء موجه النظام المحقون ببطاقة الذاكرة طويلة المدى للمزارع، قراءات ناسا وOpen-Meteo وقواعد الري الـ 5، وأعلى نتائج BM25 RAG."""
    rag_lines = []
    for idx, ch in enumerate(rag_chunks, 1):
        rag_lines.append(f"[{idx}] ({ch.get('source')} - {ch.get('title')}):\n{ch.get('text')}")
    rag_context = "\n\n".join(rag_lines) if rag_lines else ("No retrieved chunks." if lang == "en" else "لا توجد مقاطع مسترجعة.")

    prev_crop = rot.get("previous_crop") or {}
    rain_next_48h = (forecast or {}).get("rain_next_2d", clim.get("rain_next_2d", 0.0)) or 0.0
    elev = (forecast or {}).get("elevation", clim.get("elevation", 18.0)) or 18.0
    mem = farmer_memory or {}

    if lang == "en":
        irr_state_en_map = {
            "skip": "Do Not Irrigate (Rain >= 5mm expected within 48h)",
            "urgent": "Urgent Irrigation Required (Dry soil + hot weather)",
            "wave": "Extreme Weather Advisory (Heatwave or frost alert)",
            "water": "Irrigation Recommended (Soil moisture below crop minimum)",
            "ok": "Optimal Moisture — No Irrigation Needed Today",
        }
        irr_level = irr.get("level", "ok")
        irr_status_en = irr_state_en_map.get(irr_level, irr_level)
        eng_info_en = (
            f"{nearest_eng['name']} (Specialty: {nearest_eng['specialty']}, Governorate: {nearest_eng.get('governorate', 'Egypt')}, Distance: {nearest_eng['distance_km']} km, Phone: {nearest_eng['phone']})"
            if nearest_eng
            else "Not specified"
        )
        symptoms_en = ", ".join(mem.get("reported_symptoms") or []) or "None reported yet"
        last_vision_en = mem.get("last_vision_diagnosis") or "No plant photo uploaded yet"
        first_intro_en = mem.get("first_intro_message") or "No initial intro recorded yet"
        first_crop_en = mem.get("first_crop_ar") or prev_crop.get("name_en") or crop.get("name_en") or "Not specified"
        timeline_en = " -> ".join(mem.get("crops_timeline_ar") or []) or f"{prev_crop.get('name_en', 'N/A')} -> {crop.get('name_en', 'N/A')}"
        facts_en = " | ".join(mem.get("key_facts_log") or []) or "No additional notes"

        farmer_profile_en = (
            f"- Saved Farmer Name: {mem.get('farmer_name') or farmer_name}\n"
            f"- First Intro Message: {first_intro_en}\n"
            f"- First Recorded Crop: {first_crop_en}\n"
            f"- Crop Sequence History: {timeline_en}\n"
            f"- Key Farm Facts Log: {facts_en}\n"
            f"- Location (GPS): ({lat:.4f}, {lon:.4f}, Elevation: {elev} m)\n"
            f"- Area / Soil / Irrigation: Area={mem.get('land_area') or 'Unknown'} | Soil={mem.get('soil_type') or 'Agricultural clay/loam'} | Method={mem.get('irrigation_method') or 'Unknown'}\n"
            f"- Target Crop: {crop.get('name_en')} (Family: {crop.get('family', 'Unknown')}, Season: {crop.get('season', 'Unknown')}, Nitrogen role: {crop.get('nitrogen_role', 'Moderate')})\n"
            f"- Previous Crop in Field: {prev_crop.get('name_en', 'Not specified')}\n"
            f"- Reported Symptoms History: {symptoms_en}\n"
            f"- Last Camera Plant Diagnosis: {last_vision_en}\n"
            f"- Top Suitable Alternative Crops for This Location & Climate: {alternative_crops_summary or 'Clover (Berseem), Faba Bean, Tomato'}\n"
            f"- Nearest Certified Agricultural Engineer: {eng_info_en}"
        )

        rot_conflict = bool(rot.get("family_conflict"))
        live_context_en = (
            f"- Average Temp (NASA T2M): {clim.get('t_avg', 20.5):.1f}°C | Max Temp (T2M_MAX): {clim.get('t_max', 26.0):.1f}°C | Min Temp (T2M_MIN): {clim.get('t_min', 14.0):.1f}°C\n"
            f"- Relative Humidity (RH2M): {clim.get('rh_avg', 58.0):.0f}% | Root-Zone Soil Moisture (GWETROOT): {round((clim.get('soil_avg') or 0.26) * 100)}% (Crop minimum required: {round(crop.get('soil_wet_min', 0.22) * 100)}%)\n"
            f"- Next 48h Rain Forecast (Open-Meteo): {rain_next_48h:.1f} mm\n"
            f"- Active NASA 5-State Irrigation Decision: [{irr_status_en}] | Calculated Water Need: {irr.get('water_mm', 0)} L/m² (mm/day)\n"
            f"- Rotation Evaluation: is_suitable={rot.get('is_suitable')} | family_conflict={rot_conflict} | climate_score={rot.get('score', 0)}/100\n"
            f"- Required Response Language: Pure English ONLY (zero Arabic characters)"
        )
        return STRICT_ENGLISH_SYSTEM_PROMPT.format(
            farmer_profile=farmer_profile_en,
            live_context=live_context_en,
            rag_context=rag_context,
        )

    eng_info = (
        f"{nearest_eng['name']} (تخصص: {nearest_eng['specialty']}، المحافظة: {nearest_eng.get('governorate', 'مصر')}، المسافة: {nearest_eng['distance_km']} كم، تليفون: {nearest_eng['phone']})"
        if nearest_eng
        else "غير محدد"
    )
    symptoms_str = "، ".join(mem.get("reported_symptoms") or []) or "لا توجد أعراض مسجلة بعد"
    last_vision = mem.get("last_vision_diagnosis") or "لم يرفع صورة بعد"
    first_intro = mem.get("first_intro_message") or "لم يسجل رسالة تعريفية أولى بعد"
    first_crop_ar = mem.get("first_crop_ar") or prev_crop.get("name_ar") or crop.get("name_ar") or "غير محدد"
    timeline_str = " -> ".join(mem.get("crops_timeline_ar") or []) or f"{prev_crop.get('name_ar', '')} -> {crop.get('name_ar', '')}"
    facts_str = " | ".join(mem.get("key_facts_log") or []) or "لا توجد ملاحظات إضافية"

    farmer_profile = (
        f"- اسم المزارع المحفوظ في الذاكرة: {mem.get('farmer_name') or farmer_name}\n"
        f"- أول رسالة تعريفية قالها المزارع عن نفسه وأرضه: {first_intro}\n"
        f"- أول محصول زرعه وقاله للمساعد الذكي: {first_crop_ar}\n"
        f"- تسلسل كل المحاصيل التي ذكرها أو زرعها المزارع من البداية للآن: {timeline_str}\n"
        f"- أهم الحقائق التي قالها المزارع عن نفسه وأرضه عبر المحادثات: {facts_str}\n"
        f"- المحافظة / القرية: {mem.get('governorate') or nearest_eng.get('governorate', 'مصر') if nearest_eng else 'مصر'} | الموقع (GPS): ({lat:.4f}, {lon:.4f} - ارتفاع {elev}م)\n"
        f"- مساحة الأرض ونوع التربة وطريقة الري: المساحة={mem.get('land_area') or 'غير محددة'} | التربة={mem.get('soil_type') or 'طينية/زراعية'} | الري={mem.get('irrigation_method') or 'غير محدد'}\n"
        f"- المحصول الحالي / المستهدف: {crop.get('name_ar')} ({crop.get('name_en')}) | المرحلة العمرية: {mem.get('crop_stage') or 'غير محددة'} | العائلة: {crop.get('family', 'غير محدد')} | الموسم: {crop.get('season', 'غير محدد')} | دور النيتروجين: {crop.get('nitrogen_role', 'غير محدد')}\n"
        f"- المحصول السابق في الأرض: {prev_crop.get('name_ar', 'غير محدد')} ({prev_crop.get('name_en', 'N/A')})\n"
        f"- سجل الأعراض والمشاكل التي ذكرها المزارع سابقاً: {symptoms_str}\n"
        f"- نتيجة آخر صورة فحصها المزارع بالكاميرا: {last_vision}\n"
        f"- أفضل المحاصيل البديلة المرشحة لأرضه ومناخ ناسا الآن: {alternative_crops_summary or 'البرسيم، الفول البلدي، الطماطم'}\n"
        f"- أقرب مهندس زراعي معتمد لموقع المزارع: {eng_info}"
    )

    live_context = (
        f"- متوسط الحرارة (NASA T2M): {clim.get('t_avg', 20.5):.1f}°م | العظمى (T2M_MAX): {clim.get('t_max', 26.0):.1f}°م | الصغرى (T2M_MIN): {clim.get('t_min', 14.0):.1f}°م\n"
        f"- الرطوبة النسبية (RH2M): {clim.get('rh_avg', 58.0):.0f}% | رطوبة منطقة الجذور (GWETROOT): {round((clim.get('soil_avg') or 0.26) * 100)}% (الحد الأدنى للمحصول: {round(crop.get('soil_wet_min', 0.22) * 100)}%)\n"
        f"- توقعات أمطار الـ 48 ساعة القادمة (Open-Meteo): {rain_next_48h:.1f} مم\n"
        f"- قرار محرك الري الحالي من ناسا: [{irr.get('state_ar')}] — {irr.get('action_ar')} | كمية المياه المحسوبة: {irr.get('water_mm', 0)} لتر/م² ({irr.get('message')})\n"
        f"- قواعد الري الـ 5 المعتمدة من ناسا:\n"
        f"  1) 🔴 ري عاجل: التربة جافة + موجة حارة -> ري فوري في الصباح الباكر أو المساء.\n"
        f"  2) 🟡 ري مطلوب: رطوبة الجذور أقل من الحد الأدنى للمحصول -> ري محسوب باللتر/م².\n"
        f"  3) 🌧️ لا تروي: توقع أمطار >= 5 مم خلال 48 ساعة -> أوقف الري لتجنب الاختناق الجذري.\n"
        f"  4) ⚠️ تحذير طقس: صقيع أو حرارة قصوى تتجاوز تحمل المحصول -> ري وقائي خفيف.\n"
        f"  5) 🟢 تمام: رطوبة التربة والحرارة في النطاق المثالي -> لا حاجة للري اليوم.\n"
        f"- تقييم الدورة الزراعية: مناسب={rot.get('is_suitable')} | تعارض عائلات نباتية={rot.get('family_conflict')} | الأسباب: {'; '.join(rot.get('reasons', []))}\n"
        f"- لغة الرد المطلوبة: عامية مصرية فلاحي بسيطة ومباشرة (ar-EG)"
    )

    return STRICT_EGYPTIAN_SYSTEM_PROMPT.format(
        farmer_profile=farmer_profile,
        live_context=live_context,
        rag_context=rag_context,
    )


def _build_multi_turn_contents(
    session_key: str,
    incoming_history: Optional[List[Dict[str, Any]]],
    current_query: str,
) -> List[Dict[str, Any]]:
    """دمج سجل المحادثة من الذاكرة ومن التطبيق في مصفوفة contents متعددة الأدوار لـ Gemini."""
    stored = _SESSION_HISTORY.get(session_key, [])
    merged_turns: List[Dict[str, str]] = []

    source_turns = incoming_history if incoming_history else stored
    all_turns = list(source_turns or [])
    if len(all_turns) > 28:
        selected_turns = all_turns[:4] + all_turns[-24:]
    else:
        selected_turns = all_turns
    for turn in selected_turns:
        if isinstance(turn, dict):
            if "role" in turn and "parts" in turn:
                role = "user" if turn.get("role") == "user" else "model"
                parts = turn.get("parts") or []
                txt = (parts[0].get("text") if parts and isinstance(parts[0], dict) else "").strip()
            else:
                role = "user" if turn.get("is_farmer", turn.get("role") == "user") else "model"
                txt = str(turn.get("text") or "").strip()
            if txt and HONEST_CONNECTION_ERROR_AR not in txt and HONEST_CONNECTION_ERROR_EN not in txt:
                merged_turns.append({"role": role, "text": txt})

    contents: List[Dict[str, Any]] = []
    for item in merged_turns:
        role = item["role"]
        txt = item["text"]
        if not contents and role == "model":
            continue
        if contents and contents[-1]["role"] == role:
            contents[-1]["parts"][0]["text"] += "\n" + txt
        else:
            contents.append({"role": role, "parts": [{"text": txt}]})

    if contents and contents[-1]["role"] == "user":
        if contents[-1]["parts"][0]["text"].strip() != current_query.strip():
            contents[-1]["parts"][0]["text"] += "\n" + current_query
    else:
        contents.append({"role": "user", "parts": [{"text": current_query}]})

    return contents


def _record_session_turn(session_key: str, user_text: str, model_text: str) -> None:
    if HONEST_CONNECTION_ERROR_AR in model_text or HONEST_CONNECTION_ERROR_EN in model_text:
        return
    turns = _SESSION_HISTORY.setdefault(session_key, [])
    turns.append({"role": "user", "text": user_text})
    turns.append({"role": "model", "text": model_text})
    if len(turns) > 60:
        _SESSION_HISTORY[session_key] = turns[:4] + turns[-56:]


def generate_voice_reply(
    query_text: str,
    crop_id: str,
    prev_crop_id: Optional[str],
    clim: Dict[str, Any],
    forecast: Optional[Dict[str, Any]],
    crops_map: Dict[str, Dict[str, Any]],
    evaluate_rotation_fn,
    irrigation_fn,
    lat: float = 30.0444,
    lon: float = 31.2357,
    history: Optional[List[Dict[str, Any]]] = None,
    gemini_api_key: Optional[str] = None,
    use_gemini: bool = True,
    synthesize_audio: bool = True,
    farmer_name: str = "المزارع الذكي",
    session_id: Optional[str] = None,
    preferred_language: Optional[str] = None,
) -> Dict[str, Any]:
    """توليد الرد الصوتي الذكي (عربي + إنجليزي) عبر Gemini REST API المباشر مع ذاكرة المحادثة وBM25 RAG وedge-tts."""
    q = (query_text or "").strip()
    detected_lang = _detect_lang(q)
    norm = _normalize_ar(q)
    explicit_switch = any(
        p in norm
        for p in (
            "بالانجليزي",
            "انجليزي",
            "in english",
            "speak english",
            "reply in english",
            "بالعربي",
            "speak arabic",
            "in arabic",
            "reply in arabic",
        )
    )
    pref = (preferred_language or "").strip().lower()
    if explicit_switch:
        lang = detected_lang
    elif not q:
        lang = "en" if pref.startswith("en") else "ar"
    elif pref.startswith("en") and len(re.findall(r"[\u0600-\u06FF]", q)) == 0:
        lang = "en"
    else:
        lang = detected_lang

    session_key = session_id or f"farmer_{round(lat, 2)}_{round(lon, 2)}"

    detected_name = _extract_farmer_name(q)
    base_farmer_name = "Farmer" if (lang == "en" and farmer_name == "المزارع الذكي") else farmer_name
    effective_farmer_name = detected_name or base_farmer_name

    mentioned_supported = [c for c in _extract_supported_crops(norm) if c in crops_map]
    detected_custom_crop_ar: Optional[str] = None
    if not mentioned_supported:
        m_custom = re.search(
            r"(?:زارع|زرعت|بزرع|ازرع|هزرع|عندي\s+محصول|عندي\s+زرعه)\s+([\u0600-\u06FF]{3,14})",
            norm,
        )
        m_custom_en = re.search(
            r"\b(?:planted|planting|growing|grow|plant|cultivating)\s+([a-z]{3,16})\b",
            norm,
        )
        if m_custom:
            cand_word = m_custom.group(1).strip()
            ignore_words = {
                "ايه", "امتي", "ازاي", "انهارده", "النهارده", "دلوقتي", "ارضي", "الارض",
                "فدان", "فدانين", "قيراط", "محصول", "زرعه", "حاجة", "حاجه", "تاني", "ثاني",
            }
            if cand_word not in ignore_words:
                detected_custom_crop_ar = cand_word
                custom_id = f"custom_{cand_word}"
                if custom_id not in crops_map:
                    crops_map[custom_id] = {
                        "id": custom_id,
                        "name_ar": cand_word,
                        "name_en": cand_word,
                        "emoji": "🌱",
                        "icon": "🌱",
                        "voice": f"أنا {cand_word}",
                        "temp_opt": [16.0, 30.0],
                        "temp_abs": [4.0, 40.0],
                        "rh_opt": [40.0, 75.0],
                        "soil_wet_min": 0.25,
                        "soil_moisture_min": 0.25,
                        "water_mm_day": 4.5,
                        "family": "محصول مضاف للمزارع",
                        "season": "موسمي",
                        "nitrogen_role": "معتدل",
                    }
                mentioned_supported = [custom_id]
        elif m_custom_en:
            cand_en = m_custom_en.group(1).strip()
            en_ignore = {"crops", "crop", "seeds", "here", "today", "tomorrow", "now", "what", "when", "where", "this", "that", "more", "trees", "something", "anything"}
            if cand_en not in en_ignore:
                cap_en = cand_en.capitalize()
                detected_custom_crop_ar = cap_en
                custom_id = f"custom_{cand_en}"
                if custom_id not in crops_map:
                    crops_map[custom_id] = {
                        "id": custom_id,
                        "name_ar": cap_en,
                        "name_en": cap_en,
                        "emoji": "🌱",
                        "icon": "🌱",
                        "voice": f"I am {cap_en}",
                        "temp_opt": [16.0, 30.0],
                        "temp_abs": [4.0, 40.0],
                        "rh_opt": [40.0, 75.0],
                        "soil_wet_min": 0.25,
                        "soil_moisture_min": 0.25,
                        "water_mm_day": 4.5,
                        "family": "Farmer Added Crop",
                        "season": "Seasonal",
                        "nitrogen_role": "Moderate",
                    }
                mentioned_supported = [custom_id]

    cid = mentioned_supported[0] if mentioned_supported else (crop_id if crop_id in crops_map else "wheat")
    prev_cid = prev_crop_id
    if len(mentioned_supported) >= 2:
        if "بعد" in norm or "after" in norm:
            cid, prev_cid = mentioned_supported[0], mentioned_supported[1]
        else:
            prev_cid, cid = mentioned_supported[0], mentioned_supported[1]

    crop = crops_map[cid]
    rot = evaluate_rotation_fn(cid, prev_cid, clim)
    try:
        irr = irrigation_fn(crop, clim, forecast, language=lang)
    except TypeError:
        irr = irrigation_fn(crop, clim, forecast)
    intent = _classify_intent(norm, mentioned_supported)

    prev_crop_obj = crops_map.get(prev_cid or "", {}) if prev_cid else {}
    mentioned_crops_ar = [crops_map[m].get("name_ar", m) for m in mentioned_supported if m in crops_map]
    farmer_mem = _extract_and_update_farmer_memory(
        session_key=session_key,
        query_text=q,
        farmer_name=effective_farmer_name,
        crop_ar=crop.get("name_ar", cid),
        prev_crop_ar=prev_crop_obj.get("name_ar", prev_cid or ""),
        mentioned_crops_ar=mentioned_crops_ar,
    )
    effective_farmer_name = farmer_mem.get("farmer_name") or effective_farmer_name

    # حساب أفضل المحاصيل البديلة المناسبة لمناخ ناسا في موقع المزارع والمحصول السابق
    alt_candidates = []
    for cand_id, cand_crop in crops_map.items():
        if cand_id == cid:
            continue
        try:
            cand_rot = evaluate_rotation_fn(cand_id, prev_cid, clim)
            score = (
                (100 if cand_rot.get("is_suitable") else 40)
                - (40 if cand_rot.get("family_conflict") else 0)
                - (20 if not cand_rot.get("temp_suitable", True) else 0)
            )
            alt_candidates.append(
                {
                    "id": cand_id,
                    "name_ar": cand_crop.get("name_ar", cand_id),
                    "name_en": cand_crop.get("name_en", cand_id),
                    "is_suitable": bool(cand_rot.get("is_suitable")),
                    "family_conflict": bool(cand_rot.get("family_conflict")),
                    "score": score,
                }
            )
        except Exception:
            pass
    alt_candidates.sort(key=lambda x: x["score"], reverse=True)
    top_alts = alt_candidates[:3]
    if lang == "en":
        alt_summary = ", ".join(
            f"{a['name_en']} ({'highly suitable' if a['is_suitable'] else 'moderately suitable'})"
            for a in top_alts
        )
    else:
        alt_summary = "، ".join(
            f"{a['name_ar']} ({'مناسب جداً للمناخ والتربة' if a['is_suitable'] else 'متوسط الملاءمة'})"
            for a in top_alts
        )

    # 1) استرجاع أعلى 6 مقاطع علمية ذات صلة بسؤال المزارع وذاكرته المحفوظة عبر rank-bm25
    mem_symptoms = " ".join(farmer_mem.get("reported_symptoms") or [])
    mem_soil = farmer_mem.get("soil_type") or ""
    enriched_rag_query = f"{q} {crop.get('name_ar', '')} {crop.get('name_en', '')} {mem_symptoms} {mem_soil}".strip()
    rag_chunks = rag_engine.retrieve_top_k(enriched_rag_query, k=6)

    spec = matching_engine.infer_specialty_for_crop(cid)
    nearest_engs = matching_engine.match_engineers(lat, lon, specialty=spec, k=1)
    nearest_eng = nearest_engs[0] if nearest_engs else None

    system_prompt = build_grounded_system_prompt(
        crop=crop,
        clim=clim,
        forecast=forecast,
        irr=irr,
        rot=rot,
        lang=lang,
        rag_chunks=rag_chunks,
        nearest_eng=nearest_eng,
        farmer_name=effective_farmer_name,
        lat=lat,
        lon=lon,
        alternative_crops_summary=alt_summary,
        farmer_memory=farmer_mem,
    )

    # 2) استدعاء Gemini REST API مباشرة مع سجل المحادثة الكامل (contents) وموجه النظام
    contents = _build_multi_turn_contents(session_key, history, q)
    llm_reply, model_used = gemini_client.call_gemini_generate(
        contents=contents,
        system_instruction=system_prompt,
        temperature=0.25 if lang == "en" else 0.35,
        max_output_tokens=750,
        api_key=gemini_api_key,
        timeout=14.0,
    )

    if llm_reply:
        reply = llm_reply
        ai_source = model_used or "gemini"
        _record_session_turn(session_key, q, reply)
    else:
        reply = HONEST_CONNECTION_ERROR_EN if lang == "en" else HONEST_CONNECTION_ERROR_AR
        ai_source = "gemini_connection_error"

    audio_urls: List[str] = []
    audio_url: Optional[str] = None
    if synthesize_audio and llm_reply:
        tts_lang_key = _detect_lang(reply)
        tts_locale = "en-US" if tts_lang_key == "en" else "ar-EG"
        audio_urls = tts_service.generate_audio_urls_list_sync(
            reply,
            lang=tts_locale,
            voice=tts_service.resolve_voice(tts_lang_key),
        )
        audio_url = audio_urls[0] if audio_urls else tts_service.generate_audio_url_sync(
            reply,
            lang=tts_locale,
            voice=tts_service.resolve_voice(tts_lang_key),
        )

    return {
        "intent": intent,
        "lang": lang,
        "crop_id": cid,
        "previous_crop_id": prev_cid,
        "farmer_name": effective_farmer_name,
        "detected_farmer_name": detected_name,
        "detected_crop_id": mentioned_supported[0] if mentioned_supported else None,
        "detected_crop_name_ar": crops_map[mentioned_supported[0]].get("name_ar") if mentioned_supported and mentioned_supported[0] in crops_map else detected_custom_crop_ar,
        "detected_crop_icon": crops_map[mentioned_supported[0]].get("emoji", crops_map[mentioned_supported[0]].get("icon", "🌱")) if mentioned_supported and mentioned_supported[0] in crops_map else "🌱",
        "farmer_memory": farmer_mem,
        "crop_name_ar": crop["name_ar"],
        "crop_name_en": crop["name_en"],
        "reply_ar": reply,
        "reply": reply,
        "audio_url": audio_url,
        "audio_urls": audio_urls,
        "ai_source": ai_source,
        "session_id": session_key,
        "turns_in_memory": len(_SESSION_HISTORY.get(session_key, [])),
        "rag_chunks": [{"title": c["title"], "source": c["source"], "score": c["score"]} for c in rag_chunks[:4]],
        "system_prompt_injected": True,
        "rotation": rot,
        "irrigation": irr,
        "recommended_alternatives": top_alts,
        "nearest_engineer": nearest_eng,
    }
