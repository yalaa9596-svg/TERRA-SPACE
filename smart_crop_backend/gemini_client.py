"""عميل Gemini REST API المباشر عبر httpx مع تحميل .env وطباعة حالة الاستجابة والأخطاء الكاملة في الـ Terminal."""
import os
import traceback
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import httpx
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env", override=True)

# الموديلات التي تم التحقق عملياً أنها ترجع HTTP 200 OK بأسرع وقت (0.6 ثانية) في الأعلى
GEMINI_MODELS: Tuple[str, ...] = (
    "gemini-flash-lite-latest",
    "gemini-3.1-flash-lite-preview",
    "gemini-3.1-flash-lite",
    "gemini-3.5-flash-lite",
    "gemini-3-flash-preview",
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-1.5-flash",
)

_UNAVAILABLE_404_MODELS: set[str] = set()


def get_api_key(override_key: Optional[str] = None) -> str:
    """إرجاع مفتاح GEMINI_API_KEY من الإدخال أو ملف .env."""
    if override_key and override_key.strip():
        return override_key.strip()
    load_dotenv(BASE_DIR / ".env", override=True)
    return (os.getenv("GEMINI_API_KEY") or "").strip()


def call_gemini_generate(
    contents: List[Dict[str, Any]],
    system_instruction: Optional[str] = None,
    temperature: float = 0.4,
    max_output_tokens: int = 768,
    response_mime_type: Optional[str] = None,
    api_key: Optional[str] = None,
    timeout: float = 16.0,
) -> Tuple[Optional[str], Optional[str]]:
    """استدعاء Gemini REST API مباشرة عبر httpx مع طباعة تفصيلية لحالة الطلب وعدم إخفاء أي خطأ."""
    key = get_api_key(api_key)
    if not key or not key.startswith("AIza"):
        print(
            f"[GEMINI API FATAL] Invalid or missing GEMINI_API_KEY in {BASE_DIR / '.env'} (starts_with_AIza={key.startswith('AIza') if key else False})",
            flush=True,
        )
        return None, None

    gen_cfg: Dict[str, Any] = {
        "temperature": temperature,
        "maxOutputTokens": max_output_tokens,
    }
    if response_mime_type:
        gen_cfg["responseMimeType"] = response_mime_type

    payload: Dict[str, Any] = {
        "contents": contents,
        "generationConfig": gen_cfg,
    }
    if system_instruction:
        payload["systemInstruction"] = {"parts": [{"text": system_instruction}]}

    env_model = (os.getenv("GEMINI_MODEL") or "").strip()
    candidates: List[str] = []
    if env_model:
        candidates.append(env_model)
    for m in GEMINI_MODELS:
        if m not in candidates:
            candidates.append(m)

    with httpx.Client(timeout=min(timeout, 9.0)) as client:
        for model in candidates:
            if model in _UNAVAILABLE_404_MODELS:
                continue
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"
            try:
                resp = client.post(url, json=payload)

                if resp.status_code == 404:
                    print(
                        f"[GEMINI API 404] model={model} HTTP 404 Not Found: {resp.text[:250]}",
                        flush=True,
                    )
                    _UNAVAILABLE_404_MODELS.add(model)
                    continue

                if resp.status_code != 200:
                    print(
                        f"[GEMINI API ERROR] model={model} HTTP {resp.status_code}: {resp.text[:400]}",
                        flush=True,
                    )
                    continue

                data = resp.json()
                cands = data.get("candidates") or []
                if not cands:
                    print(
                        f"[GEMINI API WARNING] model={model} HTTP 200 but empty candidates: {resp.text[:300]}",
                        flush=True,
                    )
                    continue

                parts = cands[0].get("content", {}).get("parts", [])
                answer_chunks = [
                    p.get("text", "")
                    for p in parts
                    if not p.get("thought") and p.get("text")
                ]
                if not answer_chunks:
                    answer_chunks = [p.get("text", "") for p in parts if p.get("text")]
                text = "".join(answer_chunks).strip()
                if text:
                    print(
                        f"[GEMINI API OK] model={model} HTTP 200 (turns={len(contents)}, reply_chars={len(text)})",
                        flush=True,
                    )
                    return text, model
            except Exception as exc:
                print(
                    f"[GEMINI API EXCEPTION] model={model} {type(exc).__name__}: {exc}\n{traceback.format_exc()}",
                    flush=True,
                )
                continue

    print("[GEMINI API FAILED] All candidate Gemini models failed to return a valid response.", flush=True)
    return None, None
