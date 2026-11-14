"""منطق Terra Space (تطبيق تيرا سبيس الزراعي الذكي):
داتا ناسا (NASA POWER)، ملاءمة المحصول، الدورة الزراعية، محرك الري ذو الـ 5 حالات،
الـ Haversine Matching، تشخيص PlantDoc، والستوري الصوتية للمزارع.

الملف ده مفيهوش FastAPI، يعني ينفع يتجرّب لوحده (python test_core.py).
"""
import datetime as dt
import json
from pathlib import Path

import matching_engine
import nasa_engine
import vision_engine
import voice_assistant_engine

BASE = Path(__file__).parent
CROPS = {c["id"]: c for c in json.loads((BASE / "crops.json").read_text(encoding="utf-8"))}
ENGINEERS = matching_engine.DEFAULT_ENGINEERS

ROTATION_FILE = BASE / "crops_rotation_data.json"
ROTATION_CROPS = {
    c["id"]: c for c in json.loads(ROTATION_FILE.read_text(encoding="utf-8"))
} if ROTATION_FILE.exists() else {}

WATER_NEED_MM = {
    "Low": 2.5,
    "Low-Medium": 3.0,
    "Medium": 4.0,
    "High": 5.5,
}

for cid, rcrop in ROTATION_CROPS.items():
    t_min = float(rcrop["optimal_temp"]["min"])
    t_max = float(rcrop["optimal_temp"]["max"])
    rh_min = float(rcrop["optimal_humidity"]["min"])
    rh_max = float(rcrop["optimal_humidity"]["max"])
    existing = CROPS.get(cid, {})
    CROPS[cid] = {
        **existing,
        "id": cid,
        "name_ar": rcrop["name_ar"],
        "name_en": rcrop["name_en"],
        "emoji": rcrop["icon"],
        "icon": rcrop["icon"],
        "voice": existing.get("voice", f"أنا {rcrop['name_ar']}"),
        "temp_opt": [t_min, t_max],
        "temp_abs": existing.get("temp_abs", [max(-2.0, t_min - 12.0), t_max + 9.0]),
        "rh_opt": [rh_min, rh_max],
        "soil_wet_min": float(rcrop["soil_moisture_min"]),
        "soil_moisture_min": float(rcrop["soil_moisture_min"]),
        "water_mm_day": existing.get("water_mm_day", WATER_NEED_MM.get(rcrop["water_need"], 4.0)),
        "family": rcrop["family"],
        "season": rcrop["season"],
        "water_need": rcrop["water_need"],
        "nitrogen_role": rcrop["nitrogen_role"],
        "optimal_temp": rcrop["optimal_temp"],
        "optimal_humidity": rcrop["optimal_humidity"],
        "bad_preceding_families": rcrop["bad_preceding_families"],
        "recommended_next_crops": rcrop["recommended_next_crops"],
        "voice_dialogue": rcrop["voice_dialogue"],
    }


# ---------------------------------------------------------------- الداتا (NASA POWER + Open-Meteo)

def fetch_power(lat, lon, days=35):
    """بيجيب آخر `days` يوم من NASA POWER للمزارع."""
    return nasa_engine.fetch_nasa_daily(lat, lon, days=days)


def fetch_climatology(lat, lon):
    """بيجيب معدلات المناخ الزراعي من NASA POWER Climatology API."""
    return nasa_engine.fetch_nasa_climatology(lat, lon)


def fetch_forecast(lat, lon):
    """توقعات 3 أيام + الارتفاع عن سطح البحر من Open-Meteo."""
    return nasa_engine.fetch_open_meteo_forecast(lat, lon)


def _mean(xs):
    return sum(xs) / len(xs) if xs else None


def summarize(power, days=30):
    """بيلخّص آخر `days` يوم صالحين في أرقام بسيطة."""
    dates = sorted(power.get("T2M", {}))[-days:]
    if not dates:
        raise ValueError("no climate data")

    def vals(key):
        return [power[key][d] for d in dates if d in power.get(key, {})]

    tmax, tmin = vals("T2M_MAX"), vals("T2M_MIN")
    return {
        "days": len(dates),
        "t_avg": _mean(vals("T2M")),
        "t_max": max(tmax) if tmax else None,
        "t_min": min(tmin) if tmin else None,
        "rain_total": sum(vals("PRECTOTCORR")),
        "rh_avg": _mean(vals("RH2M")),
        "soil_avg": _mean(vals("GWETROOT")),
    }


# ---------------------------------------------------------------- ملاءمة المحصول للمزارع

def _band(value, lo, hi, full, slope):
    """درجة كاملة جوه النطاق، وبتنقص بمقدار `slope` لكل وحدة بعيدة عنه."""
    if value is None:
        return full / 2
    if lo <= value <= hi:
        return float(full)
    dist = lo - value if value < lo else value - hi
    return max(0.0, full - dist * slope)


def suitability(crop, clim):
    lo, hi = crop["temp_opt"]
    abs_lo, abs_hi = crop["temp_abs"]
    rlo, rhi = crop["rh_opt"]

    t, tmax, tmin, rh = clim["t_avg"], clim["t_max"], clim["t_min"], clim["rh_avg"]

    heat_pts = 25.0 if tmax is None or tmax <= abs_hi else max(0.0, 25 - (tmax - abs_hi) * 5)
    cold_pts = 20.0 if tmin is None or tmin >= abs_lo else max(0.0, 20 - (abs_lo - tmin) * 5)

    checks = [
        {"key": "temp", "max": 40, "pts": _band(t, lo, hi, 40, 6), "value": t},
        {"key": "heat", "max": 25, "pts": heat_pts, "value": tmax},
        {"key": "cold", "max": 20, "pts": cold_pts, "value": tmin},
        {"key": "humidity", "max": 15, "pts": _band(rh, rlo, rhi, 15, 0.5), "value": rh},
    ]
    for c in checks:
        c["pts"] = round(c["pts"], 1)
        c["ok"] = c["pts"] >= 0.8 * c["max"]

    score = round(sum(c["pts"] for c in checks))
    level = "yes" if score >= 75 else "maybe" if score >= 50 else "no"
    verdict = {"yes": "مناسب", "maybe": "مناسب بشروط", "no": "غير مناسب"}[level]
    return {"score": score, "level": level, "verdict": verdict, "checks": checks}


def story_check(crop, result, clim):
    """المحصول بيكلّم المزارع بصيغة المتكلم. بنرجّع سطور (للترجمة) ونص كامل (للصوت)."""
    voice, emoji = crop["voice"], crop["emoji"]
    lo, hi = crop["temp_opt"]
    abs_lo, abs_hi = crop["temp_abs"]
    rlo, rhi = crop["rh_opt"]
    by = {c["key"]: c for c in result["checks"]}

    lines = [f"{voice} {emoji}"]
    opening = {
        "yes": "يا أخي المزارع، بصراحة أرضك ومناخها مناسبين ليا، ازرعني وأنا هطلّعلك خير!",
        "maybe": "يا أخي المزارع، أقدر أعيش عندك، بس بشروط، خليني أقولك إيه اللي هيفرق.",
        "no": "للأسف يا عزيزي المزارع مش هرتاح عندك دلوقتي، وهقولك ليه.",
    }[result["level"]]
    lines.append(opening)

    t = clim["t_avg"]
    if by["temp"]["ok"]:
        lines.append(f"الحرارة عندك حوالي {t:.0f} درجة، وده بالظبط اللي بحبه.")
    elif t < lo:
        lines.append(f"الحرارة عندك حوالي {t:.0f} درجة، وأنا بحب من {lo} لـ {hi}، فالجو أبرد من اللي أرتاح فيه.")
    else:
        lines.append(f"الحرارة عندك حوالي {t:.0f} درجة، وأنا بحب من {lo} لـ {hi}، فالجو أحر من اللي أرتاح فيه.")

    if by["heat"]["ok"]:
        lines.append("ومفيش موجات حر هتأذيني.")
    else:
        lines.append(f"وأعلى حرارة وصلت {clim['t_max']:.0f} درجة، وأنا مش بتحمل فوق {abs_hi}.")

    if by["cold"]["ok"]:
        lines.append("ولا فيه برد يتعبني.")
    else:
        lines.append(f"وأقل حرارة نزلت {clim['t_min']:.0f} درجة، وأنا مش بتحمل تحت {abs_lo}.")

    rh = clim["rh_avg"]
    if rh is not None:
        if by["humidity"]["ok"]:
            lines.append("والرطوبة مناسبة ليا.")
        else:
            lines.append(f"والرطوبة عندك {rh:.0f}% وأنا بحب من {rlo} لـ {rhi}%.")

    if "voice_dialogue" in crop:
        diag = crop["voice_dialogue"]["suitable" if result["level"] == "yes" else "unsuitable"]
        lines.append(diag)

    if result["level"] != "yes":
        if not by["heat"]["ok"] or (not by["temp"]["ok"] and t > hi):
            lines.append("نصيحتي للمزارع: ازرعني في موسم أبرد، أو وفّرلي ظل وري منتظم.")
        elif not by["cold"]["ok"] or (not by["temp"]["ok"] and t < lo):
            lines.append("نصيحتي للمزارع: استنى لحد ما الجو يدفى، أو غطّيني بالليل.")
        else:
            lines.append("نصيحتي للمزارع: كلّم مهندس زراعي قريب منك عبر تيرا سبيس قبل ما تزرع.")

    return {"lines": lines, "text": " ".join(lines)}


# ---------------------------------------------------------------- الدورة الزراعية (Crop Rotation Explorer)

def _family_code(family_str):
    if not family_str:
        return ""
    return family_str.split("(")[0].strip()


def evaluate_rotation(target_crop_id, previous_crop_id, clim):
    """تقييم الدورة الزراعية وملاءمة المناخ والتربة من بيانات NASA POWER للمزارع."""
    if target_crop_id not in ROTATION_CROPS and target_crop_id not in CROPS:
        CROPS[target_crop_id] = {
            "id": target_crop_id,
            "name_ar": str(target_crop_id),
            "name_en": str(target_crop_id),
            "emoji": "🌱",
            "icon": "🌱",
            "voice": f"أنا محصول {target_crop_id}",
            "temp_opt": [16.0, 30.0],
            "temp_abs": [4.0, 40.0],
            "rh_opt": [40.0, 75.0],
            "soil_wet_min": 0.25,
            "soil_moisture_min": 0.25,
            "water_mm_day": 4.5,
            "family": "محصول مضاف للمزارع",
            "season": "موسمي",
            "nitrogen_role": "معتدل الاستهلاك",
            "bad_preceding_families": [],
            "recommended_next_crops": ["clover", "faba_bean"],
        }

    target = ROTATION_CROPS.get(target_crop_id) or CROPS[target_crop_id]
    prev = (ROTATION_CROPS.get(previous_crop_id) or CROPS.get(previous_crop_id)) if previous_crop_id else None

    suit = suitability(CROPS[target_crop_id], clim)

    prev_family_code = _family_code(prev.get("family", "")) if prev else ""
    bad_families = target.get("bad_preceding_families", [])
    family_conflict = bool(prev_family_code and any(bf.lower() in prev_family_code.lower() for bf in bad_families))

    is_recommended_after_prev = bool(
        prev and target_crop_id in prev.get("recommended_next_crops", [])
    )

    soil_val = clim.get("soil_avg")
    soil_min = target.get("soil_moisture_min", target.get("soil_wet_min", 0.20))
    soil_ok = True if soil_val is None else (soil_val >= soil_min)

    rotation_score = suit["score"]
    reasons = []

    if family_conflict:
        rotation_score = max(0, rotation_score - 35)
        reasons.append(
            f"تحذير دورة زراعية للمزارع: زراعة {target['name_ar']} بعد {prev['name_ar']} ({prev.get('family', '')}) "
            f"يجهد التربة ويزيد خطر الآفات المشتركة."
        )
    elif is_recommended_after_prev:
        rotation_score = min(100, rotation_score + 15)
        reasons.append(
            f"تعاقب ممتاز للمزارع: {target['name_ar']} خيار مثالي بعد {prev['name_ar']} لتجديد توازن التربة."
        )
    elif prev:
        reasons.append(f"تعاقب مقبول بعد {prev['name_ar']} مع مراعاة التسميد المتوازن.")

    if not soil_ok and soil_val is not None:
        rotation_score = max(0, rotation_score - 10)
        reasons.append(
            f"رطوبة التربة الحالية ({soil_val:.2f}) أقل من الحد الأدنى الموصى به ({soil_min:.2f})."
        )
    elif soil_val is not None:
        reasons.append(f"رطوبة التربة من قمر ناسا ({soil_val:.2f}) مناسبة جداً للمحصول.")

    is_suitable = (rotation_score >= 65) and (not family_conflict)
    level = "yes" if is_suitable and rotation_score >= 75 else "maybe" if is_suitable else "no"
    verdict = {"yes": "مناسب جداً للدورة والمناخ", "maybe": "مناسب بشروط", "no": "غير مناسب حالياً"}[level]

    dialogue_dict = target.get("voice_dialogue", {})
    voice_text = dialogue_dict.get("suitable" if is_suitable else "unsuitable") or story_check(CROPS[target_crop_id], suit, clim)["text"]

    next_crops_details = [
        {
            "id": nid,
            "name_ar": ROTATION_CROPS[nid]["name_ar"],
            "name_en": ROTATION_CROPS[nid]["name_en"],
            "icon": ROTATION_CROPS[nid]["icon"],
            "family": ROTATION_CROPS[nid]["family"],
            "nitrogen_role": ROTATION_CROPS[nid]["nitrogen_role"],
        }
        for nid in target.get("recommended_next_crops", [])
        if nid in ROTATION_CROPS
    ]

    return {
        "target_crop": target,
        "previous_crop": prev,
        "is_suitable": is_suitable,
        "score": rotation_score,
        "climate_score": suit["score"],
        "level": level,
        "verdict": verdict,
        "family_conflict": family_conflict,
        "is_recommended_sequence": is_recommended_after_prev,
        "soil_ok": soil_ok,
        "reasons": reasons,
        "voice_dialogue": voice_text,
        "recommended_next_crops": next_crops_details,
        "checks": suit["checks"],
        "climate": clim,
    }


# ---------------------------------------------------------------- الريّ (5 حالات)

def irrigation(crop, clim7, forecast=None, language="ar"):
    """قواعد الريّ الخمسة للمزارع عبر محرك nasa_engine."""
    return nasa_engine.evaluate_5state_irrigation(crop, clim7, forecast, language=language)


# ---------------------------------------------------------------- أقرب مهندس زراعي للمزارع

def haversine_km(lat1, lon1, lat2, lon2):
    return matching_engine.haversine_km(lat1, lon1, lat2, lon2)


def nearest_engineers(lat, lon, engineers, k=3, specialty=None):
    """بيرتّب المهندسين بالمسافة للمزارع مع تفضيل التخصص المطابق."""
    return matching_engine.match_engineers(lat, lon, engineers=engineers, specialty=specialty, k=k)


# ---------------------------------------------------------------- المساعد الصوتي التفاعلي المُحكَم بقاعدة البيانات (عربي + إنجليزي) للمزارع


def voice_assistant_reply(
    query_text: str,
    crop_id: str,
    prev_crop_id: str,
    clim: dict,
    forecast: dict = None,
    lat: float = 30.0444,
    lon: float = 31.2357,
    history: list = None,
    gemini_api_key: str = None,
    farmer_name: str = "المزارع الذكي",
    session_id: str = None,
    preferred_language: str = None,
) -> dict:
    """الرد الصوتي المُحكَم ببيانات crops_rotation_data.json وPlantDoc وقواعد ناسا الـ 5 (عربي + إنجليزي)."""
    return voice_assistant_engine.generate_voice_reply(
        query_text=query_text,
        crop_id=crop_id,
        prev_crop_id=prev_crop_id,
        clim=clim,
        forecast=forecast,
        crops_map=CROPS,
        evaluate_rotation_fn=evaluate_rotation,
        irrigation_fn=irrigation,
        lat=lat,
        lon=lon,
        history=history,
        gemini_api_key=gemini_api_key,
        farmer_name=farmer_name,
        session_id=session_id,
        preferred_language=preferred_language,
    )


# ---------------------------------------------------------------- التنبيهات

def notify(phone, text):
    """إشعار المزارع أو المهندس الزراعي."""
    print(f"[NOTIFY -> {phone}] {text}")
    return True
