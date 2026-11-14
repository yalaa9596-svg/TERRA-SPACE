"""محرك المناخ والري ببيانات أقمار ناسا الصناعية (NASA POWER & Open-Meteo 5-State Engine) - Terra Space.

يدعم:
1. NASA POWER Climatology API + Daily Point API.
2. Open-Meteo Forecast API (الحالي + اليومي لدرجات الحرارة العظمى والصغرى والأمطار).
3. محرك قواعد الري ذو الـ 5 حالات (Irrigation 5-State Rule Engine):
   - ري عاجل (urgent)
   - ري مطلوب (water)
   - لا تروي (skip)
   - موجة حر أو برد (wave)
   - تمام (ok)
"""
import datetime as dt
import json
import urllib.parse
import urllib.request
from typing import Any, Dict, Optional

try:
    import requests
except ImportError:
    requests = None

POWER_CLIMATOLOGY_URL = "https://power.larc.nasa.gov/api/temporal/climatology/point"
POWER_DAILY_URL = "https://power.larc.nasa.gov/api/temporal/daily/point"
POWER_PARAMS = "T2M,T2M_MAX,T2M_MIN,RH2M,GWETROOT,PRECTOTCORR"
FORECAST_URL = "https://api.open-meteo.com/v1/forecast"


def http_get_json(url: str, params: Dict[str, Any], timeout: int = 30) -> Dict[str, Any]:
    if requests is not None:
        r = requests.get(url, params=params, timeout=timeout)
        r.raise_for_status()
        return r.json()
    qs = urllib.parse.urlencode(params)
    req = urllib.request.Request(f"{url}?{qs}", headers={"User-Agent": "TerraSpace/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_nasa_climatology(lat: float, lon: float) -> Dict[str, Any]:
    """جلب البيانات المناخية الزراعية من NASA POWER Climatology API."""
    params = {
        "parameters": POWER_PARAMS,
        "community": "AG",
        "longitude": lon,
        "latitude": lat,
        "format": "JSON",
    }
    raw = http_get_json(POWER_CLIMATOLOGY_URL, params, timeout=8)["properties"]["parameter"]
    return {
        k: {m: v for m, v in vals.items() if v != -999}
        for k, vals in raw.items()
    }


def fetch_nasa_daily(lat: float, lon: float, days: int = 35) -> Dict[str, Any]:
    """جلب البيانات اليومية لآخر `days` يوم من NASA POWER Daily API."""
    end = dt.date.today() - dt.timedelta(days=1)
    start = end - dt.timedelta(days=days)
    params = {
        "parameters": POWER_PARAMS,
        "community": "AG",
        "latitude": lat,
        "longitude": lon,
        "start": start.strftime("%Y%m%d"),
        "end": end.strftime("%Y%m%d"),
        "format": "JSON",
    }
    raw = http_get_json(POWER_DAILY_URL, params, timeout=1.8)["properties"]["parameter"]
    return {
        k: {d: v for d, v in vals.items() if v != -999}
        for k, vals in raw.items()
    }


def fetch_open_meteo_forecast(lat: float, lon: float) -> Optional[Dict[str, Any]]:
    """جلب التوقعات الجوية الحالية واليومية من Open-Meteo كما في التصميم المعتمد."""
    try:
        j = http_get_json(
            FORECAST_URL,
            params={
                "latitude": lat,
                "longitude": lon,
                "current": "temperature_2m,precipitation",
                "daily": "precipitation_sum,temperature_2m_max,temperature_2m_min",
                "forecast_days": 3,
                "timezone": "auto",
            },
            timeout=1.8,
        )
        daily = j.get("daily", {})
        current = j.get("current", {})
        rain = [x or 0.0 for x in daily.get("precipitation_sum", [])]
        tmax = [x for x in daily.get("temperature_2m_max", []) if x is not None]
        tmin = [x for x in daily.get("temperature_2m_min", []) if x is not None]
        return {
            "elevation": j.get("elevation"),
            "current_temp": current.get("temperature_2m"),
            "current_precipitation": current.get("precipitation", 0.0),
            "rain_next_2d": round(sum(rain[:2]), 1),
            "tmax_next_3d": max(tmax) if tmax else None,
            "tmin_next_3d": min(tmin) if tmin else None,
        }
    except Exception:
        return None


def evaluate_5state_irrigation(
    crop: Dict[str, Any],
    clim: Dict[str, Any],
    forecast: Optional[Dict[str, Any]] = None,
    language: str = "ar",
) -> Dict[str, Any]:
    """محرك قواعد الري ذو الـ 5 حالات للمزارع (عربي + إنجليزي وفق NASA POWER & Open-Meteo):
    1. ري عاجل (urgent)
    2. ري مطلوب (water)
    3. لا تروي (skip)
    4. موجة حر أو برد (wave)
    5. تمام (ok)
    """
    is_en = (language or "ar").strip().lower().startswith("en")
    soil = clim.get("soil_avg")
    rain7 = clim.get("rain_total") or 0.0
    tmax = clim.get("t_max")
    tmin = clim.get("t_min")

    rain_next = forecast.get("rain_next_2d") if forecast else None
    fc_tmax = forecast.get("tmax_next_3d") if forecast else None
    fc_tmin = forecast.get("tmin_next_3d") if forecast else None

    soil_min = float(crop.get("soil_wet_min", crop.get("soil_moisture_min", 0.25)))
    opt_lo, opt_hi = crop.get("temp_opt", [15.0, 28.0])
    abs_lo, abs_hi = crop.get("temp_abs", [max(-2.0, opt_lo - 10.0), opt_hi + 8.0])
    base_water_mm = float(crop.get("water_mm_day", 4.6))

    dry = soil is not None and soil < soil_min
    hot = tmax is not None and tmax > (opt_hi + 3.0)
    mm = round(base_water_mm * (1.3 if hot else 1.0), 1)
    suggested_liters = round(mm) if round(mm) > 0 else 6

    check_tmax = fc_tmax if fc_tmax is not None else tmax
    check_tmin = fc_tmin if fc_tmin is not None else tmin
    extreme_heat = check_tmax is not None and check_tmax > abs_hi
    extreme_cold = check_tmin is not None and check_tmin < abs_lo

    voice = crop.get("voice", f"أنا {crop.get('name_ar', 'المحصول')}")
    crop_en = crop.get("name_en", crop.get("id", "Crop"))
    emoji = crop.get("emoji", crop.get("icon", "🌱"))

    # ترتيب القواعد الخمسة المعتمدة
    if rain_next is not None and rain_next >= 5.0:
        level = "skip"
        state_ar = "لا تروي"
        state_en = "Do Not Irrigate"
        action_ar = "متروّيش النهارده ووفّر المياه، في مطر جاي."
        action_en = "Skip irrigation today and save water — rainfall is expected."
        msg_ar = f"{voice} {emoji} يا أخي المزارع، فيه مطر متوقع خلال يومين ({rain_next:.1f} ملم)، متروّيش النهارده ووفّر المياه."
        msg_en = f"For {crop_en} {emoji}: {rain_next:.1f} mm rain is forecasted in the next 48 hours. Skip irrigation today to save water."
    elif dry and hot:
        level = "urgent"
        state_ar = "ري عاجل"
        state_en = "Urgent Irrigation"
        action_ar = f"اروِ النهارده، مع كمية المياه المقترحة (حوالي {suggested_liters} لتر لكل متر مربع)."
        action_en = f"Irrigate today (~{suggested_liters} L/m²) early morning or evening."
        msg_ar = (
            f"{voice} {emoji} الجو حر والتربة ناشفة جداً يا أخي المزارع، مياه النهارده من فضلك! "
            f"حوالي {mm} ملم (يعني {mm} لتر لكل متر مربع)."
        )
        msg_en = (
            f"For {crop_en} {emoji}: High heat and dry root-zone soil detected. "
            f"Irrigate urgently today with about {mm} L/m²."
        )
    elif extreme_heat or extreme_cold:
        level = "wave"
        state_ar = "موجة حر أو برد"
        state_en = "Heat / Cold Wave"
        wave_type = "موجة حر شديدة" if extreme_heat else "موجة برد وصقيع"
        wave_type_en = "severe heat wave" if extreme_heat else "frost or cold wave"
        action_ar = "تحذير موجة طقس مع نصائح التغطية والري."
        action_en = "Weather wave warning — apply protective mulching and adjust watering."
        msg_ar = (
            f"{voice} {emoji} انتبه يا أخي المزارع! يوجد تحذير {wave_type} تتجاوز حدود تحملي، "
            f"انصحك بالتغطية الوقائية وضبط الري لحماية المحصول."
        )
        msg_en = (
            f"For {crop_en} {emoji}: Weather alert! A {wave_type_en} exceeds tolerance limits. "
            f"Use protective mulching and careful irrigation timing."
        )
    elif dry or (hot and rain7 < 5.0):
        level = "water"
        state_ar = "ري مطلوب"
        state_en = "Irrigation Needed"
        action_ar = "التربة ناشفة، محتاجة ري النهارده."
        action_en = "Soil moisture is low — schedule watering today."
        msg_ar = (
            f"{voice} {emoji} التربة محتاجة ري النهارده يا أخي المزارع، "
            f"حوالي {mm} ملم (يعني {mm} لتر لكل متر مربع)."
        )
        msg_en = (
            f"For {crop_en} {emoji}: Soil needs watering today (~{mm} L/m²) before peak sun."
        )
    else:
        level = "ok"
        state_ar = "تمام"
        state_en = "All Good"
        action_ar = "مفيش حاجة مطلوبة، أرضك وزرعتك في أمان."
        action_en = "No action required — crop and root moisture are healthy."
        msg_ar = f"{voice} {emoji} كله تمام النهارده يا أخي المزارع، مفيش ري مطلوب، أرضك وزرعتك في أمان."
        msg_en = f"For {crop_en} {emoji}: All indicators are well balanced today. No extra irrigation needed."

    return {
        "level": level,
        "language": "en" if is_en else "ar",
        "state_ar": state_en if is_en else state_ar,
        "state_en": state_en,
        "action_ar": action_en if is_en else action_ar,
        "action_en": action_en,
        "message": msg_en if is_en else msg_ar,
        "message_en": msg_en,
        "water_mm": mm if level in ("urgent", "water") else 0.0,
        "soil_wetness": soil,
        "rain_7d_mm": round(rain7, 1),
        "rain_next_2d_mm": rain_next,
        "forecast_tmax": check_tmax,
        "forecast_tmin": check_tmin,
    }

