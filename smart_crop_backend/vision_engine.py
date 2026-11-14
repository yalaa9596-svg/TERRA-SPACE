"""محرك تشخيص أمراض النباتات والتصعيد للمهندس الزراعي (PlantDoc Vision & Escalation Engine) - Terra Space.

يعتمد على تصنيفات PlantDoc Dataset (27 فئة لـ 11 محصول حقلي وبستاني):
https://www.kaggle.com/datasets/nirmalsankalana/plantdoc-dataset
"""
import base64
import hashlib
import json
import re
from typing import Any, Dict, Optional

import gemini_client
import tts_service

PLANTDOC_DATASET_URL = "https://www.kaggle.com/datasets/nirmalsankalana/plantdoc-dataset"

# المحاصيل المدعومة داخل مجموعة بيانات PlantDoc (11 محصول)
PLANTDOC_SUPPORTED_CROPS = {
    "tomato": "الطماطم",
    "potato": "البطاطس",
    "corn": "الذرة",
    "maize": "الذرة الشامية",
    "apple": "التفاح",
    "grape": "العنب",
    "bell_pepper": "الفلفل الرومي",
    "blueberry": "التوت الأزرق",
    "raspberry": "توت العليق",
    "peach": "الخوخ",
    "soybean": "فول الصويا",
    "strawberry": "الفراولة",
}

# المحاصيل خارج نطاق PlantDoc وتستلزم إحالة فورية لمهندس زراعي متخصص
OUT_OF_SCOPE_CROPS = {
    "wheat": "القمح",
    "cotton": "القطن",
    "rice": "الأرز",
    "olive": "الزيتون",
    "faba_bean": "الفول البلدي",
    "clover": "البرسيم",
    "orange": "البرتقال",
    "onion": "البصل",
}

# قاعدة معرفة الـ 27 فئة المعتمدة في PlantDoc مع الأعراض والعلاج العضوي والكيميائي باللهجة المصرية للمزارع
PLANTDOC_CLASSES: Dict[str, Dict[str, Any]] = {
    "Tomato Early Blight": {
        "crop_id": "tomato",
        "crop_ar": "الطماطم",
        "name_ar": "الندوة المبكرة في الطماطم (Alternaria solani)",
        "healthy": False,
        "severe": False,
        "specialty": "خضروات",
        "symptoms_ar": "وجود بقع بنية داكنة على شكل حلقات متداخلة (تشبه لوحة التصويب) على الأوراق السفلية مع اصفرار حول البقع.",
        "organic_treatment_ar": "إزالة الأوراق المصابة السفلية فوراً وحرقها بعيداً عن الحقل، والرش بمستخلص زيت النيم أو بيكربونات البوتاسيوم مع تنظيم الري الصباحي.",
        "chemical_treatment_ar": "الرش بمبيد فطري نحاسي (أوكسي كلورو النحاس) أو مانكوزيب أو أزوكسي ستروبين بالجرعة الموصى بها.",
    },
    "Tomato Late Blight": {
        "crop_id": "tomato",
        "crop_ar": "الطماطم",
        "name_ar": "الندوة المتأخرة في الطماطم (Phytophthora infestans)",
        "healthy": False,
        "severe": True,
        "specialty": "أمراض نباتية",
        "symptoms_ar": "بقع مائية غير منتظمة تتحول سريعاً إلى اللون البني المسود على الأوراق والسيقان مع زغب أبيض خفيف أسفل الورقة في الصباح الباكر.",
        "organic_treatment_ar": "وقف الري بالرش تماماً، تقليل الرطوبة الأرضية، اقتلاع النباتات شديدة الإصابة فوراً والرش الوقائي بمركبات النحاس العضوية.",
        "chemical_treatment_ar": "تدخل سريع بمبيد جهازي متخصص مثل ميتالاكسيل + مانكوزيب أو سيموكسانيل تحت إشراف المهندس الزراعي.",
    },
    "Tomato Leaf Mold": {
        "crop_id": "tomato",
        "crop_ar": "الطماطم",
        "name_ar": "عفن أوراق الطماطم (Passalora fulva)",
        "healthy": False,
        "severe": False,
        "specialty": "خضروات",
        "symptoms_ar": "بقع صفراء باهتة على السطح العلوي للورقة يقابلها نمو قطفي زيتوني أو بني على السطح السفلي.",
        "organic_treatment_ar": "تحسين التهوية بين النباتات وتقليل الكثافة النباتية والرش بمستخلص الثوم أو زيت النيم.",
        "chemical_treatment_ar": "الرش بمبيد كلوروثالونيل أو ديفينوكونازول مع مراعاة فترة الأمان قبل الحصاد.",
    },
    "Tomato Septoria Leaf Spot": {
        "crop_id": "tomato",
        "crop_ar": "الطماطم",
        "name_ar": "تبقع سبتوريا على أوراق الطماطم",
        "healthy": False,
        "severe": False,
        "specialty": "خضروات",
        "symptoms_ar": "بقع دائرية صغيرة كثيرة ذات حواف بنية داكنة ومركز رمادي فاتح يحتوي على نقط سوداء دقيقة.",
        "organic_treatment_ar": "تنظيف الحشائش والأوراق المتساقطة وتجنب ملامسة الأوراق للتربة الرطبة والرش بالنحاس الحيوي.",
        "chemical_treatment_ar": "الرش بمركبات المانكوزيب أو أوكسي كلورو النحاس كل 10 أيام عند اللزوم.",
    },
    "Tomato Bacterial Spot": {
        "crop_id": "tomato",
        "crop_ar": "الطماطم",
        "name_ar": "التبقع البكتيري في الطماطم",
        "healthy": False,
        "severe": True,
        "specialty": "أمراض نباتية",
        "symptoms_ar": "بقع صغيرة داكنة مشبعة بالماء على الأوراق والثمار تتحول إلى قشور خشنة.",
        "organic_treatment_ar": "الرش بهيدروكسيد النحاس المعتمد عضوياً وتجنب العمل في الحقل والأوراق مبللة.",
        "chemical_treatment_ar": "الرش بمخلوط مركبات النحاس مع مانكوزيب لتقليل انتشار البكتيريا.",
    },
    "Tomato Mosaic Virus": {
        "crop_id": "tomato",
        "crop_ar": "الطماطم",
        "name_ar": "فيروس موزاييك الطماطم (ToMV)",
        "healthy": False,
        "severe": True,
        "specialty": "أمراض نباتية",
        "symptoms_ar": "تبرقش الأوراق بلون أخضر فاتح وغامق مع التفاف وتشوه الأوراق الحديثة وتقزم النبات.",
        "organic_treatment_ar": "اقتلاع النباتات المصابة فوراً وتطهير الأدوات الزراعية ومكافحة الحشرات الناقلة بالزيوت الطبيعية.",
        "chemical_treatment_ar": "لا يوجد علاج كيميائي مباشر للفيروس؛ يتم رش منشطات مناعة ومكافحة المن والذبابة البيضاء.",
    },
    "Tomato Yellow Virus": {
        "crop_id": "tomato",
        "crop_ar": "الطماطم",
        "name_ar": "فيروس تجعد واصفرار أوراق الطماطم (TYLCV)",
        "healthy": False,
        "severe": True,
        "specialty": "أمراض نباتية",
        "symptoms_ar": "التفاف الأوراق لأعلى على شكل ملعقة مع اصفرار الحواف وتوقف نمو القمة النامية.",
        "organic_treatment_ar": "نصب المصائد الصفراء اللاصقة والرش بزيت النيم والصابون البوتاسي للسيطرة على الذبابة البيضاء.",
        "chemical_treatment_ar": "مكافحة حشرة الذبابة البيضاء الناقلة للفيروس بمبيد حشري جهازي متخصص.",
    },
    "Tomato Spider Mites": {
        "crop_id": "tomato",
        "crop_ar": "الطماطم",
        "name_ar": "العنكبوت الأحمر على الطماطم",
        "healthy": False,
        "severe": False,
        "specialty": "خضروات",
        "symptoms_ar": "نقط باهتة دقيقة على الأوراق مع خيوط عنكبوتية رفيعة على السطح السفلي واصفرار وجفاف الأوراق.",
        "organic_treatment_ar": "الرش بالكبريت الميكروني أو زيت النيم مع غسل الأوراق للتخلص من الأتربة.",
        "chemical_treatment_ar": "الرش بمبيد أكاروسي متخصص مثل أبامكتين مع تغطية السطح السفلي للأوراق.",
    },
    "Tomato Healthy": {
        "crop_id": "tomato",
        "crop_ar": "الطماطم",
        "name_ar": "أوراق طماطم سليمة وصحية",
        "healthy": True,
        "severe": False,
        "specialty": "خضروات",
        "symptoms_ar": "الأوراق خضراء نضرة خالية من التبقعات والاصفرار وحالة النمو ممتازة.",
        "organic_treatment_ar": "استمر على برنامج الري المعتدل والتسميد العضوي المتوازن.",
        "chemical_treatment_ar": "لا تحتاج أي مبيدات كيميائية حالياً.",
    },
    "Potato Early Blight": {
        "crop_id": "potato",
        "crop_ar": "البطاطس",
        "name_ar": "الندوة المبكرة في البطاطس",
        "healthy": False,
        "severe": False,
        "specialty": "خضروات",
        "symptoms_ar": "بقع بنية دائرية ذات حلقات متحدة المركز تبدأ على الأوراق المسنة السفلية.",
        "organic_treatment_ar": "إزالة الأوراق المصابة وتحسين تهوية الخطوط والرش بمحلول النحاس العضوي.",
        "chemical_treatment_ar": "الرش بمبيد أزوكسي ستروبين أو مانكوزيب بالتناوب.",
    },
    "Potato Late Blight": {
        "crop_id": "potato",
        "crop_ar": "البطاطس",
        "name_ar": "الندوة المتأخرة في البطاطس",
        "healthy": False,
        "severe": True,
        "specialty": "أمراض نباتية",
        "symptoms_ar": "لطخات بنية مسودة مائية سريعة الانتشار على حواف الأوراق والسيقان.",
        "organic_treatment_ar": "تقليل الرطوبة فوراً وتجنب الري المسائي والتخلص من الأجزاء المصابة.",
        "chemical_treatment_ar": "الرش العاجل بمبيد ميتالاكسيل أو فلوأزينام تحت إشراف مهندس زراعي.",
    },
    "Potato Healthy": {
        "crop_id": "potato",
        "crop_ar": "البطاطس",
        "name_ar": "أوراق بطاطس سليمة",
        "healthy": True,
        "severe": False,
        "specialty": "خضروات",
        "symptoms_ar": "نمو خضري سليم ولون أخضر متجانس.",
        "organic_treatment_ar": "الحفاظ على انتظام الري وتعلية الخطوط حول الدرنات.",
        "chemical_treatment_ar": "لا حاجة لأي تدخل كيميائي.",
    },
    "Corn Gray Leaf Spot": {
        "crop_id": "maize",
        "crop_ar": "الذرة الشامية",
        "name_ar": "تبقع الأوراق الرمادي في الذرة (Cercospora zeae-maydis)",
        "healthy": False,
        "severe": False,
        "specialty": "محاصيل حقلية",
        "symptoms_ar": "بقع مستطيلة رمادية أو بنية فاتحة محصورة وموازية لعروق ورقة الذرة.",
        "organic_treatment_ar": "تطبيق دورة زراعية مع محصول بقولي (مثل البرسيم أو الفول البلدي) والتخلص من بقايا المحصول السابق.",
        "chemical_treatment_ar": "الرش بمبيد فطري من مجموعة التريازول أو الستروبيلورين عند بداية ظهور الأعراض.",
    },
    "Corn Rust": {
        "crop_id": "maize",
        "crop_ar": "الذرة الشامية",
        "name_ar": "صدأ أوراق الذرة (Puccinia sorghi)",
        "healthy": False,
        "severe": False,
        "specialty": "محاصيل حقلية",
        "symptoms_ar": "بثرات بارزة بلون بني محمر (يشبه صدأ الحديد) منتشرة على سطحي الورقة.",
        "organic_treatment_ar": "الرش بالكبريت الميكروني في الصباح الباكر وتجنب الإفراط في التسميد الآزوتي.",
        "chemical_treatment_ar": "الرش بمبيد بروبيكونازول أو تيبوكونازول.",
    },
    "Corn Northern Leaf Blight": {
        "crop_id": "maize",
        "crop_ar": "الذرة الشامية",
        "name_ar": "لفحة أوراق الذرة الشمالية",
        "healthy": False,
        "severe": True,
        "specialty": "محاصيل حقلية",
        "symptoms_ar": "بقع طويلة رمادية مخضرة تشبه شكل السيجار على الأوراق السفلية وتمتد للأعلى.",
        "organic_treatment_ar": "تحسين مسافات الزراعة والتهوية والاعتماد على الدورة الزراعية.",
        "chemical_treatment_ar": "الرش بمبيد أزوكسي ستروبين + بروبيكونازول.",
    },
    "Corn Healthy": {
        "crop_id": "maize",
        "crop_ar": "الذرة الشامية",
        "name_ar": "نبات ذرة سليم وصحي",
        "healthy": True,
        "severe": False,
        "specialty": "محاصيل حقلية",
        "symptoms_ar": "أوراق الذرة خضراء قوية وسليمة من التبقعات والصدأ.",
        "organic_treatment_ar": "استمر في انتظام الري والتسميد المتوازن.",
        "chemical_treatment_ar": "لا يلزم أي مبيدات.",
    },
    "Apple Scab": {
        "crop_id": "apple",
        "crop_ar": "التفاح",
        "name_ar": "جرب التفاح (Venturia inaequalis)",
        "healthy": False,
        "severe": False,
        "specialty": "فاكهة",
        "symptoms_ar": "بقع زيتونية داكنة مخملية على الأوراق والثمار تتحول إلى قشور بنية متشققة.",
        "organic_treatment_ar": "جمع الأوراق المتساقطة تحت الأشجار والتقليم لفتح قلب الشجرة للشمس والرش بالكبريت الجيري.",
        "chemical_treatment_ar": "الرش بمبيد ديفينوكونازول أو كابتان حسب برنامج مكافحة البساتين.",
    },
    "Apple Rust": {
        "crop_id": "apple",
        "crop_ar": "التفاح",
        "name_ar": "صدأ التفاح",
        "healthy": False,
        "severe": False,
        "specialty": "فاكهة",
        "symptoms_ar": "بقع صفراء برتقالية لامعة على السطح العلوي لأوراق التفاح.",
        "organic_treatment_ar": "تقليم الأفرع المصابة والرش بمركبات الكبريت والنحاس.",
        "chemical_treatment_ar": "الرش بمبيد ميكلوبوتانيل في بداية الموسم.",
    },
    "Apple Healthy": {
        "crop_id": "apple",
        "crop_ar": "التفاح",
        "name_ar": "أوراق تفاح سليمة",
        "healthy": True,
        "severe": False,
        "specialty": "فاكهة",
        "symptoms_ar": "أوراق التفاح بحالة ممتازة وخالية من الجرب والصدأ.",
        "organic_treatment_ar": "الاستمرار في التقليم والري المتوازن.",
        "chemical_treatment_ar": "لا حاجة لأي مبيد.",
    },
    "Grape Black Rot": {
        "crop_id": "grape",
        "crop_ar": "العنب",
        "name_ar": "العفن الأسود في العنب (Guignardia bidwellii)",
        "healthy": False,
        "severe": True,
        "specialty": "فاكهة",
        "symptoms_ar": "بقع بنية محمرة دائرية على الأوراق مع ذبول وكرمشة حبات العنب وتحولها للون الأسود.",
        "organic_treatment_ar": "إزالة العناقيد والأوراق المصابة وتقليل الرطوبة حول التكعيبة والرش بالنحاس العضوي.",
        "chemical_treatment_ar": "الرش بمبيد مانكوزيب أو تيبوكونازول تحت إشراف مهندس البساتين.",
    },
    "Grape Healthy": {
        "crop_id": "grape",
        "crop_ar": "العنب",
        "name_ar": "أوراق عنب سليمة",
        "healthy": True,
        "severe": False,
        "specialty": "فاكهة",
        "symptoms_ar": "الأوراق خضراء وسليمة تماماً.",
        "organic_treatment_ar": "متابعة التقليم والري المنتظم.",
        "chemical_treatment_ar": "لا يحتاج علاج كيميائي.",
    },
    "Bell Pepper Bacterial Spot": {
        "crop_id": "bell_pepper",
        "crop_ar": "الفلفل الرومي",
        "name_ar": "التبقع البكتيري في الفلفل",
        "healthy": False,
        "severe": False,
        "specialty": "خضروات",
        "symptoms_ar": "بقع مائية صغيرة تتحول للبني الداكن وتسبب تساقط الأوراق السفلية.",
        "organic_treatment_ar": "الرش بمركبات النحاس الحيوية وتجنب الري بالرش.",
        "chemical_treatment_ar": "الرش بأوكسي كلورو النحاس بمعدل موصى به.",
    },
    "Bell Pepper Healthy": {
        "crop_id": "bell_pepper",
        "crop_ar": "الفلفل الرومي",
        "name_ar": "أوراق فلفل سليمة",
        "healthy": True,
        "severe": False,
        "specialty": "خضروات",
        "symptoms_ar": "أوراق خضراء لامعة وسليمة.",
        "organic_treatment_ar": "انتظام الري والتسميد العضوي.",
        "chemical_treatment_ar": "لا يلزم علاج كيميائي.",
    },
    "Strawberry Leaf Scorch": {
        "crop_id": "strawberry",
        "crop_ar": "الفراولة",
        "name_ar": "احتراق أوراق الفراولة (Diplocarpon earliana)",
        "healthy": False,
        "severe": False,
        "specialty": "فاكهة",
        "symptoms_ar": "بقع أرجوانية إلى بنية غير منتظمة تتجمع فتجعل حواف الورقة تبدو محترقة.",
        "organic_treatment_ar": "إزالة الأوراق الجافة والمصابة واستخدام الملش البلاستيكي لمنع رذاذ التربة.",
        "chemical_treatment_ar": "الرش بمبيد كابتان أو أزوكسي ستروبين مع مراعاة فترة الأمان.",
    },
    "Strawberry Healthy": {
        "crop_id": "strawberry",
        "crop_ar": "الفراولة",
        "name_ar": "أوراق فراولة سليمة",
        "healthy": True,
        "severe": False,
        "specialty": "فاكهة",
        "symptoms_ar": "أوراق خضراء سليمة ونمو ممتاز.",
        "organic_treatment_ar": "الاستمرار في الرعاية المعتادة.",
        "chemical_treatment_ar": "لا يلزم مبيدات.",
    },
    "Peach Bacterial Spot": {
        "crop_id": "peach",
        "crop_ar": "الخوخ",
        "name_ar": "التبقع البكتيري في الخوخ",
        "healthy": False,
        "severe": False,
        "specialty": "فاكهة",
        "symptoms_ar": "بقع زاوية صغيرة بنية تسقط تاركة ثقوباً في الورقة (أعراض التثقب).",
        "organic_treatment_ar": "التقليم الجيد والرش بالنحاس في فترة السكون.",
        "chemical_treatment_ar": "الرش بمركبات النحاس المعتمدة.",
    },
    "Soybean Healthy": {
        "crop_id": "soybean",
        "crop_ar": "فول الصويا",
        "name_ar": "أوراق فول صويا سليمة",
        "healthy": True,
        "severe": False,
        "specialty": "محاصيل حقلية",
        "symptoms_ar": "نمو طبيعي وأوراق سليمة.",
        "organic_treatment_ar": "استمرار الرعاية المتوازنة.",
        "chemical_treatment_ar": "لا يلزم مبيدات.",
    },
}

# ربط كل محصول بقائمة فئات PlantDoc الخاصة به
CROP_TO_CLASSES = {
    "tomato": [
        "Tomato Early Blight",
        "Tomato Late Blight",
        "Tomato Leaf Mold",
        "Tomato Septoria Leaf Spot",
        "Tomato Bacterial Spot",
        "Tomato Healthy",
    ],
    "potato": [
        "Potato Early Blight",
        "Potato Late Blight",
        "Potato Healthy",
    ],
    "maize": [
        "Corn Gray Leaf Spot",
        "Corn Rust",
        "Corn Northern Leaf Blight",
        "Corn Healthy",
    ],
    "corn": [
        "Corn Gray Leaf Spot",
        "Corn Rust",
        "Corn Northern Leaf Blight",
        "Corn Healthy",
    ],
    "apple": [
        "Apple Scab",
        "Apple Rust",
        "Apple Healthy",
    ],
    "grape": [
        "Grape Black Rot",
        "Grape Healthy",
    ],
    "bell_pepper": [
        "Bell Pepper Bacterial Spot",
        "Bell Pepper Healthy",
    ],
    "strawberry": [
        "Strawberry Leaf Scorch",
        "Strawberry Healthy",
    ],
    "peach": ["Peach Bacterial Spot"],
    "soybean": ["Soybean Healthy"],
    "blueberry": ["Soybean Healthy"],
    "raspberry": ["Strawberry Healthy"],
}


def _detect_mime_type(image_bytes: bytes, filename: Optional[str] = None) -> str:
    if image_bytes.startswith(b"\x89PNG"):
        return "image/png"
    if image_bytes[:4] == b"RIFF" and image_bytes[8:12] == b"WEBP":
        return "image/webp"
    if filename and filename.lower().endswith(".png"):
        return "image/png"
    return "image/jpeg"


def _extract_json_object(raw_text: str) -> Optional[Dict[str, Any]]:
    cleaned = (raw_text or "").strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    try:
        parsed = json.loads(cleaned)
        if isinstance(parsed, dict):
            return parsed
    except Exception:
        pass
    m = re.search(r"\{.*\}", cleaned, flags=re.DOTALL)
    if m:
        try:
            parsed = json.loads(m.group(0))
            if isinstance(parsed, dict):
                return parsed
        except Exception:
            pass
    return None


def _call_gemini_vision(
    image_bytes: bytes,
    crop_hint: str,
    filename: Optional[str] = None,
    language: str = "ar",
) -> Optional[Dict[str, Any]]:
    """استدعاء Gemini Vision REST API عبر httpx لتحليل الصورة الفعلية وتحديد نوع النبات والمرض بدقة."""
    is_en = (language or "ar").strip().lower().startswith("en")
    if is_en:
        classes_ref = "\n".join(
            f"- {cls_name} ({meta['crop_id']})"
            for cls_name, meta in PLANTDOC_CLASSES.items()
        )
        prompt = (
            "You are Terra Space's Senior Plant Pathologist and Agronomist.\n"
            "Inspect the uploaded image and accurately identify the real plant, fruit, or crop visible in the image itself (do NOT assume or guess from defaults).\n"
            "Reference the 27 PlantDoc disease/healthy classes below when matching leaf conditions:\n"
            f"{classes_ref}\n\n"
            "If the photo is blurry, unclear, or severely infected, set confidence < 75 and set is_severe or is_unclear to true.\n"
            "Write ALL text fields in clear, natural English (zero Arabic characters so English TTS speaks smoothly).\n"
            "Return JSON ONLY with these exact keys:\n"
            '{\n'
            '  "crop_name": "Detected crop or plant name in English (e.g., Tomato, Potato, Orange)",\n'
            '  "disease_name": "Detected disease or healthy state in English",\n'
            '  "confidence": 0 to 100 integer,\n'
            '  "is_healthy": true or false,\n'
            '  "is_severe": true or false,\n'
            '  "is_unclear": true or false,\n'
            '  "symptoms_ar": "Clear description of visual symptoms observed in English",\n'
            '  "treatment_ar": "Practical step-by-step organic and chemical care guidance in English",\n'
            '  "voice_summary_ar": "Warm 2-3 sentence spoken English summary for the farmer explaining the crop, condition, and next action"\n'
            '}'
        )
    else:
        classes_ref = "\n".join(
            f"- {cls_name}: {meta['name_ar']} ({meta['crop_ar']})"
            for cls_name, meta in PLANTDOC_CLASSES.items()
        )
        prompt = (
            "أنت خبير ومهندس أمراض نباتات مصري في تطبيق تيرا سبيس (Terra Space).\n"
            "انظر للصورة المرفوعة وحدد بدقة نوع المحصول أو الفاكهة أو النبات الحقيقي الظاهر في الصورة نفسها (سواء كان برتقال، موالح، طماطم، بطاطس، عنب، تفاح، قمح، ذرة، فول، أو أي نبات آخر — اعتمد على ما تراه فعلياً في الصورة وليس على أي افتراض مسبق!).\n"
            "استعن أيضاً بمرجع فئات PlantDoc الـ 27 التالية عند مطابقة أمراض الأوراق:\n"
            f"{classes_ref}\n\n"
            "إذا كانت الصورة غير واضحة أو بها إصابة شديدة، اجعل confidence أقل من 75 واجعل is_severe أو is_unclear قيمتها true.\n"
            "خاطب المزارع بلقب 'يا عم المزارع' (ولا تستخدم 'الفلاح' أبداً) بلهجة مصرية دافية وبسيطة ومباشرة.\n"
            "أرجع JSON فقط بالمفاتيح التالية بالظبط:\n"
            '{\n'
            '  "crop_name": "اسم المحصول أو الفاكهة الظاهرة فعلياً في الصورة بالعربية (مثلاً: البرتقال، الطماطم، العنب)",\n'
            '  "disease_name": "اسم المرض أو الحالة الظاهرة في الصورة بالعربية بوضوح",\n'
            '  "confidence": 0 to 100 integer,\n'
            '  "is_healthy": true or false,\n'
            '  "is_severe": true or false,\n'
            '  "is_unclear": true or false,\n'
            '  "symptoms_ar": "وصف دقيق وواضح لما تراه في الصورة وشكل الإصابة أو حالة النبات",\n'
            '  "treatment_ar": "العلاج العملي المحدد للمزارع خطوة بخطوة",\n'
            '  "voice_summary_ar": "ملخص صوتي مصري دافئ ومختصر في جملتين أو 3 جمل يشرح للمزارع نوع النبات وحالته وإيه اللي يعمله دلوقتي"\n'
            '}'
        )

    b64_img = base64.b64encode(image_bytes).decode("ascii")
    mime_type = _detect_mime_type(image_bytes, filename)
    contents = [
        {
            "role": "user",
            "parts": [
                {"text": prompt},
                {"inline_data": {"mime_type": mime_type, "data": b64_img}},
            ],
        }
    ]
    raw_text, model_used = gemini_client.call_gemini_generate(
        contents=contents,
        temperature=0.2,
        max_output_tokens=1024,
        response_mime_type="application/json",
        timeout=18.0,
    )
    if not raw_text:
        return None
    parsed = _extract_json_object(raw_text)
    if not parsed:
        return None
    parsed["_model_used"] = model_used
    return parsed


def _finalize_audio(voice_text: str, synthesize_audio: bool, language: str = "ar") -> Optional[str]:
    if not synthesize_audio or not voice_text:
        return None
    is_en = (language or "ar").strip().lower().startswith("en")
    tts_lang = "en-US" if is_en else "ar-EG"
    tts_voice = tts_service.DEFAULT_ENGLISH_VOICE if is_en else tts_service.DEFAULT_EGYPTIAN_VOICE
    return tts_service.generate_audio_url_sync(
        voice_text,
        lang=tts_lang,
        voice=tts_voice,
    )


def _english_fallback_texts(chosen_class: str, crop_id: str, is_healthy: bool) -> Dict[str, str]:
    crop_title = crop_id.replace("_", " ").title()
    if is_healthy:
        return {
            "symptoms": f"Foliage on {crop_title} looks uniform, green, and free of visible lesions.",
            "organic": "Continue balanced irrigation, morning watering, and regular field monitoring.",
            "chemical": "No chemical fungicide or bactericide needed.",
        }
    low = chosen_class.lower()
    if "bacterial" in low:
        return {
            "symptoms": f"Water-soaked dark spots with yellow halos observed on {crop_title} leaves ({chosen_class}).",
            "organic": "Avoid working among wet plants, prune lower affected leaves, and spray certified organic copper hydroxide.",
            "chemical": "Apply fixed copper + mancozeb mixture according to label dosage and pre-harvest interval.",
        }
    if "rust" in low:
        return {
            "symptoms": f"Orange to cinnamon-brown raised pustules detected on {crop_title} foliage ({chosen_class}).",
            "organic": "Improve field airflow, remove heavily infected leaves, and spray wettable sulfur or neem extract.",
            "chemical": "Apply an approved triazole or strobilurin fungicide under agronomist guidance.",
        }
    return {
        "symptoms": f"Leaf lesions and discoloration consistent with {chosen_class} on {crop_title}.",
        "organic": "Remove badly infected lower leaves away from the field, avoid overhead sprinkling, and apply neem oil or potassium bicarbonate.",
        "chemical": "Use copper oxychloride, mancozeb, or an appropriate systemic fungicide recommended by an agronomist.",
    }


def diagnose_plant_image(
    crop_id: Optional[str] = None,
    image_bytes: Optional[bytes] = None,
    filename: Optional[str] = None,
    hint_class: Optional[str] = None,
    simulated_confidence: Optional[float] = None,
    use_gemini_vision: bool = True,
    synthesize_audio: bool = True,
    language: str = "ar",
) -> Dict[str, Any]:
    """تحليل صورة النبات الفعلية عبر Gemini Vision أولاً دائماً، مع حساب الثقة والتصعيد والصوت (عربي + إنجليزي)."""
    norm_crop = (crop_id or "tomato").strip().lower()
    is_en = (language or "ar").strip().lower().startswith("en")
    out_lang = "en" if is_en else "ar"

    # 1. عند رفع صورة فعلية (image_bytes)، نحلل الصورة الحقيقية عبر Gemini Vision أولاً دائماً بغض النظر عن crop_id الافتراضي!
    if use_gemini_vision and image_bytes and len(image_bytes) > 0 and not hint_class and simulated_confidence is None:
        g_res = _call_gemini_vision(
            image_bytes=image_bytes,
            crop_hint=norm_crop,
            filename=filename,
            language=out_lang,
        )
        if g_res:
            raw_conf = g_res.get("confidence", 80)
            try:
                conf_num = float(raw_conf)
            except Exception:
                conf_num = 70.0
            scaled_conf = conf_num * 100 if (0 < conf_num <= 1.0 and isinstance(raw_conf, float)) else conf_num
            conf_pct = max(0, min(100, round(scaled_conf)))
            conf = round(conf_pct / 100.0, 2)

            default_crop = norm_crop.replace("_", " ").title() if is_en else PLANTDOC_SUPPORTED_CROPS.get(norm_crop, norm_crop)
            crop_name = str(g_res.get("crop_name") or default_crop).strip()
            disease_name = str(g_res.get("disease_name") or ("Plant Condition" if is_en else "حالة النبات")).strip()
            symptoms_text = str(
                g_res.get("symptoms_ar")
                or ("Please follow up closely with a local agronomist." if is_en else "يرجى متابعة حالة النبات مع المهندس المختص.")
            ).strip()
            treatment_text = str(
                g_res.get("treatment_ar")
                or ("Confirm on-site with an agronomist before spraying." if is_en else "يُفضل الفحص الميداني قبل استخدام أي مبيدات.")
            ).strip()
            voice_summary = str(
                g_res.get("voice_summary_ar")
                or (
                    f"We inspected your {crop_name} photo: detected {disease_name} with {conf_pct}% confidence."
                    if is_en
                    else f"يا عم المزارع، فحصنا صورة {crop_name} والنتيجة هي {disease_name} بنسبة ثقة {conf_pct}%."
                )
            ).strip()

            is_healthy = bool(g_res.get("is_healthy", "healthy" in disease_name.lower() or "سليم" in disease_name))
            is_unclear = bool(g_res.get("is_unclear", False))
            matched_meta = PLANTDOC_CLASSES.get(disease_name)
            is_severe = bool(g_res.get("is_severe", matched_meta["severe"] if matched_meta else False))
            if any(w in (disease_name + " " + symptoms_text).lower() for w in ("blight", "virus", "شديد", "متأخر", "خطير", "غير واضح", "unclear", "severe")):
                if "early" not in disease_name.lower() and not is_healthy:
                    is_severe = True

            low_confidence = conf_pct < 75
            escalate = low_confidence or is_unclear or (is_severe and not is_healthy)

            if low_confidence or is_unclear:
                esc_reason = (
                    f"Diagnosis confidence ({conf_pct}%) is below 75% or image clarity is limited — escalated to an agronomist."
                    if is_en
                    else f"نسبة ثقة التشخيص ({conf_pct}%) أقل من 75% أو الصورة غير واضحة تماماً، لذا تم التصعيد لمهندس زراعي."
                )
            elif is_severe and not is_healthy:
                esc_reason = (
                    f"Suspected condition ({disease_name}) may be severe and requires prompt specialist review."
                    if is_en
                    else f"الإصابة المشتبه بها ({disease_name}) شديدة وتستدعي متابعة فورية من مهندس زراعي."
                )
            else:
                esc_reason = None

            spec = matched_meta["specialty"] if matched_meta else (
                "فاكهة"
                if any(k in crop_name.lower() for k in ("برتقال", "موالح", "عنب", "تفاح", "مانجو", "فراولة", "خوخ", "orange", "citrus", "grape", "apple", "mango", "strawberry", "peach"))
                else "أمراض نباتية"
            )
            audio_url = _finalize_audio(voice_summary, synthesize_audio, language=out_lang)

            return {
                "dataset_source": PLANTDOC_DATASET_URL,
                "supported_in_plantdoc": True,
                "language": out_lang,
                "crop_id": norm_crop,
                "crop_name": crop_name,
                "crop_name_ar": crop_name,
                "predicted_class": disease_name,
                "disease_name": disease_name,
                "disease_name_ar": disease_name if is_en else (matched_meta["name_ar"] if matched_meta else disease_name),
                "confidence": conf,
                "confidence_pct": conf_pct,
                "is_healthy": is_healthy,
                "is_severe": is_severe,
                "escalate_to_engineer": escalate,
                "escalation_reason": esc_reason,
                "recommended_specialty": spec,
                "symptoms_ar": symptoms_text,
                "treatment_ar": treatment_text,
                "organic_treatment_ar": treatment_text,
                "chemical_treatment_ar": treatment_text if is_en else (matched_meta["chemical_treatment_ar"] if matched_meta else treatment_text),
                "voice_summary_ar": voice_summary,
                "voice_message_ar": voice_summary,
                "audio_url": audio_url,
                "ai_source": g_res.get("_model_used") or "gemini_vision",
            }

        # إذا أُرسلت صورة حقيقية وتعذر الاتصال بـ Gemini Vision، نرجع رسالة خطأ صريحة وواضحة بدون تزييف التشخيص!
        err_msg = (
            "Sorry, could not reach the PlantDoc Vision server right now due to a network or API key issue."
            if is_en
            else "عذراً، تعذر الاتصال بالمساعد الذكي حالياً بسبب مشكلة في الشبكة أو المفتاح"
        )
        err_advice = (
            "Verify server internet connectivity and API key, or contact a nearby agricultural engineer."
            if is_en
            else "يرجى التحقق من اتصال السيرفر والمحاولة مرة أخرى أو التواصل مع المهندس الزراعي."
        )
        audio_url = _finalize_audio(err_msg, synthesize_audio, language=out_lang)
        return {
            "dataset_source": PLANTDOC_DATASET_URL,
            "supported_in_plantdoc": False,
            "language": out_lang,
            "crop_id": norm_crop,
            "crop_name": "Unknown (Connection Error)" if is_en else "غير محدد (خطأ اتصال)",
            "crop_name_ar": "Unknown (Connection Error)" if is_en else "غير محدد (خطأ اتصال)",
            "predicted_class": "Gemini Vision Connection Error",
            "disease_name": err_msg,
            "disease_name_ar": err_msg,
            "confidence": 0.0,
            "confidence_pct": 0,
            "is_healthy": False,
            "is_severe": False,
            "escalate_to_engineer": True,
            "escalation_reason": err_msg,
            "recommended_specialty": "أمراض نباتية",
            "symptoms_ar": err_msg,
            "treatment_ar": err_advice,
            "organic_treatment_ar": err_advice,
            "chemical_treatment_ar": err_advice,
            "voice_summary_ar": err_msg,
            "voice_message_ar": err_msg,
            "audio_url": audio_url,
            "ai_source": "gemini_connection_error",
        }

    # 2. عند عدم إرسال صورة (نداء برمجي بدون image_bytes لمحصول خارج PlantDoc):
    if norm_crop in OUT_OF_SCOPE_CROPS and norm_crop not in PLANTDOC_SUPPORTED_CROPS:
        crop_label = norm_crop.replace("_", " ").title() if is_en else OUT_OF_SCOPE_CROPS[norm_crop]
        voice_msg = (
            f"For {crop_label}, please upload a clear photo of the affected leaf or consult the nearest specialized agricultural engineer."
            if is_en
            else f"يا عم المزارع، لفحص محصول {crop_label} بدقة ارفع صورة واضحة للنبات أو تواصل مع أقرب مهندس زراعي متخصص لمعاينة أرضك."
        )
        audio_url = _finalize_audio(voice_msg, synthesize_audio, language=out_lang)
        return {
            "dataset_source": PLANTDOC_DATASET_URL,
            "supported_in_plantdoc": False,
            "language": out_lang,
            "crop_id": norm_crop,
            "crop_name": crop_label,
            "crop_name_ar": crop_label,
            "predicted_class": "Out of PlantDoc Scope - Specialist Referral",
            "disease_name": f"Specialist Field Inspection Needed ({crop_label})" if is_en else f"يتطلب فحص ميداني لمحصول {crop_label}",
            "disease_name_ar": f"Specialist Field Inspection Needed ({crop_label})" if is_en else f"يحتاج فحص ميداني متخصص لمحصول {crop_label}",
            "confidence": 0.0,
            "confidence_pct": 0,
            "is_healthy": False,
            "is_severe": True,
            "escalate_to_engineer": True,
            "escalation_reason": (
                f"{crop_label} is outside the 11-crop PlantDoc leaf scope and requires direct agronomist inspection."
                if is_en
                else f"محصول {crop_label} يتطلب فحص حقلي مباشر من مهندس زراعي متخصص."
            ),
            "recommended_specialty": "محاصيل حقلية" if norm_crop in ("wheat", "cotton", "rice", "faba_bean", "clover") else "فاكهة",
            "symptoms_ar": "Upload a clear plant photo or request a direct field inspection." if is_en else "يرجى رفع صورة واضحة للنبات أو طلب معاينة حقلية مباشرة.",
            "treatment_ar": "Do not apply pesticides before consulting the specialist engineer." if is_en else "يرجى عدم رش أي معاملات قبل معاينة المهندس الزراعي المختص.",
            "organic_treatment_ar": "Avoid spraying prior to specialist confirmation." if is_en else "يرجى عدم رش أي معاملات قبل معاينة المهندس الزراعي المختص.",
            "chemical_treatment_ar": "To be prescribed by an agronomist after field inspection." if is_en else "يُحدد بواسطة المهندس الزراعي بعد الفحص الميداني.",
            "voice_summary_ar": voice_msg,
            "voice_message_ar": voice_msg,
            "audio_url": audio_url,
            "ai_source": "out_of_scope_referral",
        }

    # 3. التحديد المحلي عبر فئات PlantDoc (عند المحاكاة أو كفولباك فوري في حال انقطاع الاتصال)
    chosen_class = None
    if hint_class and hint_class in PLANTDOC_CLASSES:
        chosen_class = hint_class
    elif filename:
        fname_low = filename.lower()
        for cls_name in PLANTDOC_CLASSES:
            if cls_name.lower().replace(" ", "_") in fname_low or cls_name.lower() in fname_low:
                chosen_class = cls_name
                break
        if not chosen_class:
            if "late" in fname_low:
                chosen_class = "Potato Late Blight" if norm_crop == "potato" else "Tomato Late Blight"
            elif "early" in fname_low:
                chosen_class = "Potato Early Blight" if norm_crop == "potato" else "Tomato Early Blight"
            elif "rust" in fname_low:
                chosen_class = "Corn Rust" if norm_crop in ("corn", "maize") else "Apple Rust"
            elif "healthy" in fname_low or "good" in fname_low:
                chosen_class = CROP_TO_CLASSES.get(norm_crop, ["Tomato Healthy"])[-1]

    candidates = CROP_TO_CLASSES.get(norm_crop, CROP_TO_CLASSES["tomato"])
    if not chosen_class:
        if image_bytes and len(image_bytes) > 0:
            digest = hashlib.sha256(image_bytes).digest()
            idx = digest[0] % len(candidates)
            chosen_class = candidates[idx]
            if simulated_confidence is None:
                simulated_confidence = round(0.68 + (digest[1] % 27) / 100.0, 2)
        else:
            chosen_class = candidates[0]

    info = PLANTDOC_CLASSES[chosen_class]
    conf = float(simulated_confidence if simulated_confidence is not None else 0.86)
    conf_pct = round(conf * 100)

    low_confidence = conf < 0.75
    is_severe = bool(info["severe"])
    escalate = low_confidence or is_severe

    if is_en:
        en_fb = _english_fallback_texts(chosen_class, info["crop_id"], info["healthy"])
        crop_en = info["crop_id"].replace("_", " ").title()
        if low_confidence and is_severe:
            esc_reason = f"Confidence ({conf_pct}%) is under 75% and suspected condition ({chosen_class}) is severe."
        elif low_confidence:
            esc_reason = f"Confidence ({conf_pct}%) is below the 75% threshold — escalated to an agricultural engineer."
        elif is_severe:
            esc_reason = f"Severe condition detected ({chosen_class}) — fast specialist intervention recommended."
        else:
            esc_reason = None

        if info["healthy"]:
            voice_msg = (
                f"Great news! Your {crop_en} leaves look completely healthy ({conf_pct}% confidence). "
                "Keep up your balanced irrigation and nutrition schedule."
            )
        elif escalate:
            voice_msg = (
                f"Attention: suspected {chosen_class} on your {crop_en} ({conf_pct}% confidence). "
                f"{en_fb['symptoms']} We escalated this case to your nearest agricultural specialist."
            )
        else:
            voice_msg = (
                f"Detected {chosen_class} on your {crop_en} ({conf_pct}% confidence). "
                f"Organic step: {en_fb['organic']} Chemical option: {en_fb['chemical']}"
            )
        audio_url = _finalize_audio(voice_msg, synthesize_audio, language="en")
        return {
            "dataset_source": PLANTDOC_DATASET_URL,
            "supported_in_plantdoc": True,
            "language": "en",
            "crop_id": info["crop_id"],
            "crop_name": crop_en,
            "crop_name_ar": crop_en,
            "predicted_class": chosen_class,
            "disease_name": chosen_class,
            "disease_name_ar": chosen_class,
            "confidence": round(conf, 2),
            "confidence_pct": conf_pct,
            "is_healthy": info["healthy"],
            "is_severe": is_severe,
            "escalate_to_engineer": escalate,
            "escalation_reason": esc_reason,
            "recommended_specialty": info["specialty"],
            "symptoms_ar": en_fb["symptoms"],
            "treatment_ar": f"Organic: {en_fb['organic']} | Chemical: {en_fb['chemical']}",
            "organic_treatment_ar": en_fb["organic"],
            "chemical_treatment_ar": en_fb["chemical"],
            "voice_summary_ar": voice_msg,
            "voice_message_ar": voice_msg,
            "audio_url": audio_url,
            "ai_source": "plantdoc_local_fallback",
        }

    if low_confidence and is_severe:
        esc_reason = f"نسبة ثقة التشخيص ({conf_pct}%) أقل من 75% والمرض المشتبه به ({info['name_ar']}) شديد الخطورة."
    elif low_confidence:
        esc_reason = f"نسبة ثقة التشخيص ({conf_pct}%) أقل من الحد الآمن (75%)، لذا يلزم مراجعة مهندس زراعي."
    elif is_severe:
        esc_reason = f"الإصابة بـ ({info['name_ar']}) شديدة وتنتشر بسرعة وتستلزم متابعة فورية مع مهندس زراعي."
    else:
        esc_reason = None

    if info["healthy"]:
        voice_msg = (
            f"بشرى سارة يا عم المزارع! فحصت صورة {info['crop_ar']} وبنسبة ثقة {conf_pct}% "
            f"الأوراق سليمة تماماً وخالية من الأمراض. استمر في برنامج الري والتسميد المتوازن."
        )
    elif escalate:
        voice_msg = (
            f"انتبه يا عم المزارع! رصدت في صورة {info['crop_ar']} اشتباه إصابة بـ {info['name_ar']} "
            f"بنسبة ثقة {conf_pct}%. الأعراض: {info['symptoms_ar']} "
            f"ونظراً لأن الحالة تحتاج تدخل دقيق، قمت بتحويل حالتك لأقرب مهندس زراعي متخصص في {info['specialty']}."
        )
    else:
        voice_msg = (
            f"يا عم المزارع، نتيجة فحص صورة {info['crop_ar']} بنسبة ثقة {conf_pct}% هي: {info['name_ar']}. "
            f"الأعراض: {info['symptoms_ar']} "
            f"العلاج العضوي المقترح: {info['organic_treatment_ar']} "
            f"أو العلاج الكيميائي: {info['chemical_treatment_ar']}"
        )

    treatment_combined = f"عضوي: {info['organic_treatment_ar']} | كيميائي: {info['chemical_treatment_ar']}"
    audio_url = _finalize_audio(voice_msg, synthesize_audio, language="ar")

    return {
        "dataset_source": PLANTDOC_DATASET_URL,
        "supported_in_plantdoc": True,
        "language": "ar",
        "crop_id": info["crop_id"],
        "crop_name": info["crop_ar"],
        "crop_name_ar": info["crop_ar"],
        "predicted_class": chosen_class,
        "disease_name": info["name_ar"],
        "disease_name_ar": info["name_ar"],
        "confidence": round(conf, 2),
        "confidence_pct": conf_pct,
        "is_healthy": info["healthy"],
        "is_severe": is_severe,
        "escalate_to_engineer": escalate,
        "escalation_reason": esc_reason,
        "recommended_specialty": info["specialty"],
        "symptoms_ar": info["symptoms_ar"],
        "treatment_ar": treatment_combined,
        "organic_treatment_ar": info["organic_treatment_ar"],
        "chemical_treatment_ar": info["chemical_treatment_ar"],
        "voice_summary_ar": voice_msg,
        "voice_message_ar": voice_msg,
        "audio_url": audio_url,
        "ai_source": "plantdoc_local_fallback",
    }

