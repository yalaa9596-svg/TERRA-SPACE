"""محرك مطابقة المهندسين الزراعيين الجغرافي (Haversine Matching Engine) - Terra Space.

يحسب المسافة الدقيقة بالكيلومتر بين إحداثيات المزارع وإحداثيات المهندس الزراعي،
مع إعطاء الأولوية للتخصص المطلوب وترتيب النتائج تصاعدياً حسب المسافة.
"""
import json
import math
from pathlib import Path
from typing import Any, Dict, List, Optional

BASE = Path(__file__).parent
ENGINEERS_FILE = BASE / "engineers.json"

DEFAULT_ENGINEERS: List[Dict[str, Any]] = (
    json.loads(ENGINEERS_FILE.read_text(encoding="utf-8"))
    if ENGINEERS_FILE.exists()
    else []
)

# إضافة سنوات خبرة افتراضية للمهندسين الـ 15 المعتمدين
for idx, eng in enumerate(DEFAULT_ENGINEERS):
    if "years_of_exp" not in eng:
        eng["years_of_exp"] = 5 + (idx % 11)


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """حساب المسافة بين نقطتين على سطح الأرض بالكيلومتر باستخدام معادلة Haversine."""
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = p2 - p1
    dl = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2.0) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2.0) ** 2
    return 2.0 * r * math.asin(math.sqrt(a))


def infer_specialty_for_crop(crop_id: Optional[str], issue_type: Optional[str] = None) -> Optional[str]:
    """استنتاج التخصص الزراعي الأنسب بناءً على نوع المحصول أو المشكلة."""
    if issue_type == "disease":
        return "أمراض نباتية"
    if issue_type == "irrigation":
        return "ري وتربة"
    cid = (crop_id or "").lower()
    if cid in ("wheat", "maize", "corn", "faba_bean", "clover", "cotton", "rice", "soybean"):
        return "محاصيل حقلية"
    if cid in ("tomato", "potato", "onion", "bell_pepper"):
        return "خضروات"
    if cid in ("apple", "orange", "grape", "olive", "strawberry", "peach", "blueberry", "raspberry"):
        return "فاكهة"
    return None


def match_engineers(
    farmer_lat: float,
    farmer_lon: float,
    engineers: Optional[List[Dict[str, Any]]] = None,
    specialty: Optional[str] = None,
    k: int = 3,
) -> List[Dict[str, Any]]:
    """ترتيب المهندسين الزراعيين حسب التخصص أولاً ثم المسافة الجغرافية الأقرب للمزارع."""
    source = engineers if engineers is not None else DEFAULT_ENGINEERS
    if not source:
        return []

    pool = source
    if specialty:
        matched = [e for e in source if e.get("specialty") == specialty]
        if matched:
            pool = matched

    ranked = sorted(
        (
            {
                **e,
                "years_of_exp": e.get("years_of_exp", 7),
                "distance_km": round(
                    haversine_km(farmer_lat, farmer_lon, float(e["lat"]), float(e["lon"])),
                    1,
                ),
            }
            for e in pool
        ),
        key=lambda item: item["distance_km"],
    )
    return ranked[:k]

