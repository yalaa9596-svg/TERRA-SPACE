"""محرك الاسترجاع المحلي BM25 RAG فوق ملفات المعرفة وبيانات المحاصيل وأمراض PlantDoc."""
import json
import re
from pathlib import Path
from typing import Any, Dict, List

from rank_bm25 import BM25Okapi

import vision_engine

BASE_DIR = Path(__file__).parent
KB_DIR = BASE_DIR / "knowledge_base"
ROTATION_PATH = BASE_DIR / "crops_rotation_data.json"


def _normalize_text(text: str) -> str:
    t = (text or "").strip().lower()
    t = re.sub(r"[\u064B-\u065F\u0670]", "", t)
    t = t.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    t = t.replace("ة", "ه").replace("ى", "ي")
    return t


_EGYPTIAN_FARMER_SYNONYMS: Dict[str, List[str]] = {
    "قوطه": ["طماطم", "باذنجانيه"],
    "غله": ["قمح", "نجيليه", "سنابل"],
    "دره": ["ذره", "شاميه", "نجيليه"],
    "برتقان": ["برتقال", "موالح", "تصمغ"],
    "شحط": ["جفاف", "عطش", "ري", "رطوبه"],
    "عطش": ["جفاف", "ري", "رطوبه", "لتر"],
    "شراقي": ["جفاف", "عطش", "ري"],
    "مطبله": ["غرق", "اختناق", "جذور", "صرف"],
    "لطعه": ["ندوه", "متاخره", "مبكره", "بقع"],
    "شياط": ["ندوه", "احتراق", "حواف", "بوتاسيوم"],
    "صفرار": ["اصفرار", "نيتروجين", "حديد", "ازوت"],
    "اصفرار": ["نيتروجين", "حديد", "زنك", "ازوت", "اوراق"],
    "بياض": ["دقيقي", "زغبي", "فطري", "كبريت"],
    "ملح": ["ملوحه", "قلويه", "شعير", "بنجر"],
    "سبخ": ["ملوحه", "صرف", "تربه"],
    "دوده": ["حشد", "قطن", "ثاقبات", "بلعوم"],
    "نواره": ["تزهير", "عقد", "كالسيوم", "بورون"],
    "ساقط": ["تساقط", "ازهار", "عقد", "كالسيوم"],
    "سوسه": ["عنكبوت", "اكاروس", "حشرات"],
    "corn": ["maize", "ذره", "شاميه", "نجيليه"],
    "wheat": ["قمح", "غله", "سنابل", "نجيليه"],
    "tomato": ["طماطم", "قوطه", "باذنجانيه"],
    "potato": ["بطاطس", "باذنجانيه"],
    "clover": ["برسيم", "نيتروجين", "بقوليه"],
    "grape": ["عنب", "عنبيات", "بياض"],
    "mango": ["مانجو", "تزهير"],
    "orange": ["برتقال", "موالح", "تصمغ"],
    "water": ["irrigate", "irrigation", "moisture", "ري", "جفاف", "رطوبه"],
    "irrigate": ["irrigation", "water", "moisture", "ري", "لتر"],
    "yellow": ["yellowing", "nitrogen", "iron", "chlorosis", "اصفرار", "نيتروجين", "حديد"],
    "blight": ["spots", "fungal", "rot", "ندوه", "بقع"],
    "conflict": ["rotation", "family", "دوره", "تعارض"],
}


def _tokenize(text: str) -> List[str]:
    norm = _normalize_text(text)
    tokens = re.findall(r"[\u0600-\u06FFa-z0-9_]+", norm)
    # إزالة أداة التعريف "ال" + توسيع المرادفات العامية للمزارع المصري لرفع دقة الاسترجاع
    expanded: List[str] = []
    for tok in tokens:
        expanded.append(tok)
        bare = tok[2:] if (len(tok) > 3 and tok.startswith("ال")) else tok
        if bare != tok:
            expanded.append(bare)
        for syn in _EGYPTIAN_FARMER_SYNONYMS.get(bare, []):
            expanded.append(_normalize_text(syn))
    return expanded


def _chunk_markdown(path: Path) -> List[Dict[str, Any]]:
    content = path.read_text(encoding="utf-8")
    sections = re.split(r"(?=^##\s+)", content, flags=re.MULTILINE)
    chunks: List[Dict[str, Any]] = []
    for idx, sec in enumerate(sections):
        text = sec.strip()
        if not text:
            continue
        first_line = text.splitlines()[0].lstrip("#").strip()
        chunks.append(
            {
                "id": f"{path.stem}_{idx}",
                "source": path.name,
                "title": first_line,
                "text": text,
            }
        )
    return chunks


def _build_corpus() -> List[Dict[str, Any]]:
    chunks: List[Dict[str, Any]] = []
    if KB_DIR.exists():
        for md_path in sorted(KB_DIR.glob("*.md")):
            chunks.extend(_chunk_markdown(md_path))

    if ROTATION_PATH.exists():
        try:
            crops = json.loads(ROTATION_PATH.read_text(encoding="utf-8"))
            for c in crops:
                opt_t = c.get("optimal_temp", {})
                opt_h = c.get("optimal_humidity", {})
                text = (
                    f"بيانات المحصول الرسمية ({c.get('name_ar')} / {c.get('name_en')}): "
                    f"العائلة {c.get('family')}، الموسم {c.get('season')}، "
                    f"الاحتياج المائي {c.get('water_need')}، دور النيتروجين {c.get('nitrogen_role')}. "
                    f"الحرارة المثالية {opt_t.get('min')}-{opt_t.get('max')}°C، "
                    f"الرطوبة {opt_h.get('min')}-{opt_h.get('max')}%، "
                    f"أقل رطوبة جذور GWETROOT: {c.get('soil_moisture_min')}. "
                    f"عائلات ممنوع الزراعة بعدها: {', '.join(c.get('bad_preceding_families', []))}. "
                    f"المحاصيل الموصى بها بعده: {', '.join(c.get('recommended_next_crops', []))}."
                )
                chunks.append(
                    {
                        "id": f"crop_{c.get('id')}",
                        "source": "crops_rotation_data.json",
                        "title": f"{c.get('name_ar')} ({c.get('name_en')})",
                        "text": text,
                    }
                )
        except Exception:
            pass

    for cls_name, meta in vision_engine.PLANTDOC_CLASSES.items():
        text = (
            f"مرض النبات {cls_name} ({meta.get('name_ar')}) على محصول {meta.get('crop_ar')}: "
            f"الأعراض: {meta.get('symptoms_ar')} "
            f"العلاج العضوي: {meta.get('organic_treatment_ar')} "
            f"العلاج الكيميائي: {meta.get('chemical_treatment_ar')} "
            f"شديد الخطورة: {'نعم' if meta.get('severe') else 'لا'}."
        )
        chunks.append(
            {
                "id": f"plantdoc_{cls_name.lower().replace(' ', '_')}",
                "source": "PlantDoc_27_Classes",
                "title": f"{cls_name} - {meta.get('name_ar')}",
                "text": text,
            }
        )
    return chunks


_CORPUS: List[Dict[str, Any]] = _build_corpus()
_TOKENIZED_CORPUS: List[List[str]] = [_tokenize(c["text"] + " " + c["title"]) for c in _CORPUS]
_BM25 = BM25Okapi(_TOKENIZED_CORPUS) if _TOKENIZED_CORPUS else None


def retrieve_top_k(query: str, k: int = 4) -> List[Dict[str, Any]]:
    """استرجاع أعلى K مقاطع معرفة ذات صلة بسؤال المزارع عبر rank-bm25."""
    if not _BM25 or not _CORPUS:
        return []
    q_tokens = _tokenize(query)
    if not q_tokens:
        return _CORPUS[:k]

    scores = _BM25.get_scores(q_tokens)
    ranked_indices = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)[:k]
    results: List[Dict[str, Any]] = []
    for idx in ranked_indices:
        item = dict(_CORPUS[idx])
        item["score"] = round(float(scores[idx]), 4)
        results.append(item)
    return results

