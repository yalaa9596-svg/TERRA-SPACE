"""خدمة توليد الملفات الصوتية باللهجة المصرية عبر edge-tts (ar-EG-ShakirNeural) باسم ملف فريد في كل رد لمنع الكاش."""
import asyncio
import re
import threading
import time
import uuid
from pathlib import Path
from typing import Optional

AUDIO_DIR = Path(__file__).resolve().parent / "generated_audio"
AUDIO_DIR.mkdir(parents=True, exist_ok=True)

DEFAULT_EGYPTIAN_VOICE = "ar-EG-ShakirNeural"
DEFAULT_ENGLISH_VOICE = "en-US-GuyNeural"
_EDGE_TTS_COOL_DOWN_UNTIL: float = 0.0


def _format_phone_for_speech(match: re.Match) -> str:
    digits = match.group(0)
    if len(digits) == 11 and digits.startswith("01"):
        return f"{digits[:3]} {digits[3:7]} {digits[7:]}"
    return " ".join(digits)


def clean_for_speech(text: str, lang: Optional[str] = None) -> str:
    """تنظيف النص وتبسيطه قبل التحويل إلى صوت عربي أو إنجليزي طبيعي بدون أخطاء نطق."""
    cleaned = re.sub(r"[\U0001F300-\U0001FAFF\u2600-\u27BF\uFE0F]", "", text or "")
    cleaned = re.sub(r"[*_`#]", " ", cleaned)

    ar_count = len(re.findall(r"[\u0600-\u06FF]", cleaned))
    en_count = len(re.findall(r"[A-Za-z]", cleaned))
    is_en = bool(lang and lang.lower().startswith("en")) or (en_count > ar_count)

    if is_en:
        # إزالة أي حروف عربية شاردة داخل الرد الإنجليزي حتى ينطق الصوت الإنجليزي كل الكلمات بوضوح تام
        cleaned = re.sub(r"[\u0600-\u06FF\u061F\u060C]+", " ", cleaned)
        cleaned = re.sub(r"(\d+(?:\.\d+)?)\s*%", r"\1 percent ", cleaned)
        cleaned = re.sub(r"°\s*[cC]\b", " degrees Celsius ", cleaned)
        cleaned = re.sub(r"°\s*[fF]\b", " degrees Fahrenheit ", cleaned)
        cleaned = re.sub(r"\bL/m[²2]\b", " liters per square meter ", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"(\d+(?:\.\d+)?)\s*mm\b", r"\1 millimeters ", cleaned)
        cleaned = re.sub(r"(\d+(?:\.\d+)?)\s*km\b", r"\1 kilometers ", cleaned)
        cleaned = re.sub(r"[()\[\]]", " ", cleaned)
    elif ar_count > 0:
        cleaned = re.sub(r"\([A-Za-z0-9\s.,_-]+\)", " ", cleaned)
        cleaned = re.sub(r"\bNASA\b", "ناسا", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bOpen[- ]Meteo\b", "أوبن ميتيو", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bPlantDoc\b", "بلانت دوك", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bTerra\s*Space\b", "تيرا سبيس", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\bGPS\b", "جي بي إس", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"(\d+(?:\.\d+)?)\s*%", r"\1 في المية ", cleaned)
        cleaned = re.sub(r"°\s*[مcC]", " درجة ", cleaned)
        cleaned = re.sub(r"\b01\d{9}\b", _format_phone_for_speech, cleaned)

    return re.sub(r"\s+", " ", cleaned).strip()


def resolve_voice(lang: str = "ar-EG", preferred_voice: Optional[str] = None) -> str:
    if preferred_voice:
        return preferred_voice
    return DEFAULT_EGYPTIAN_VOICE if (lang or "ar").lower().startswith("ar") else DEFAULT_ENGLISH_VOICE


def _prune_old_audio_files(max_files: int = 120) -> None:
    try:
        files = sorted(AUDIO_DIR.glob("*.mp3"), key=lambda p: p.stat().st_mtime, reverse=True)
        for old_file in files[max_files:]:
            old_file.unlink(missing_ok=True)
    except Exception:
        pass


async def synthesize_mp3_bytes_async(
    text: str,
    lang: str = "ar-EG",
    voice: Optional[str] = None,
    rate: str = "-10%",
) -> bytes:
    """توليد بايتات MP3 عبر edge-tts مباشرة (ar-EG-ShakirNeural للعربية)."""
    import edge_tts

    cleaned = clean_for_speech(text, lang=lang)
    if not cleaned:
        return b""

    global _EDGE_TTS_COOL_DOWN_UNTIL
    chosen_voice = resolve_voice(lang, voice)
    fallback_voice = "ar-EG-SalmaNeural" if (lang or "ar").lower().startswith("ar") else "en-US-AriaNeural"
    candidates = [chosen_voice] if chosen_voice == fallback_voice else [chosen_voice, fallback_voice]

    if time.time() >= _EDGE_TTS_COOL_DOWN_UNTIL:
        for candidate in candidates:
            try:
                communicate = edge_tts.Communicate(cleaned, candidate, rate=rate)
                chunks = []

                async def _collect():
                    async for chunk in communicate.stream():
                        if chunk.get("type") == "audio":
                            chunks.append(chunk["data"])

                await asyncio.wait_for(_collect(), timeout=2.8)
                data = b"".join(chunks)
                if data:
                    return data
            except Exception as exc:
                print(f"[EDGE-TTS WARNING] voice={candidate} error={type(exc).__name__}: {exc}", flush=True)
                _EDGE_TTS_COOL_DOWN_UNTIL = time.time() + 180.0
                break

    # فولباك آمن عبر Google Translate TTS باللهجة العربية عند بطء أو حظر شبكة Microsoft Edge TTS
    # يقسم النص الطويل إلى مقاطع (<= 175 حرفاً عند حدود الجمل/الكلمات) ويدمج كل مقاطع MP3 حتى يُقرأ الرد كاملاً لآخر كلمة
    try:
        import urllib.parse
        import urllib.request

        lang_code = "ar" if (lang or "ar").lower().startswith("ar") else "en"
        words = cleaned.split()
        segments: list[str] = []
        current_seg = ""
        for w in words:
            candidate_seg = f"{current_seg} {w}".strip() if current_seg else w
            if len(candidate_seg) <= 175:
                current_seg = candidate_seg
            else:
                if current_seg:
                    segments.append(current_seg)
                current_seg = w[:175]
        if current_seg:
            segments.append(current_seg)

        combined_mp3 = bytearray()
        for seg in segments[:12]:
            q = urllib.parse.quote(seg)
            g_url = f"https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl={lang_code}&q={q}"
            req = urllib.request.Request(g_url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=4.0) as resp:
                part_bytes = resp.read()
                if part_bytes and len(part_bytes) > 128:
                    combined_mp3.extend(part_bytes)

        if len(combined_mp3) > 256:
            return bytes(combined_mp3)
    except Exception as exc:
        print(f"[FALLBACK-TTS WARNING] error={type(exc).__name__}: {exc}", flush=True)

    return b""


def split_text_into_tts_segments(text: str, max_chars: int = 180, lang: Optional[str] = None) -> list[str]:
    """تقسيم النص إلى جمل طبيعية (<= max_chars حرفاً) لقراءة الصوت العربي والإنجليزي بانسيابية."""
    cleaned = clean_for_speech(text, lang=lang)
    if not cleaned:
        return []
    sentences = [s.strip() for s in re.split(r"(?<=[.!؟?])\s+", cleaned) if s.strip()]
    segments: list[str] = []
    current_seg = ""

    def _flush_word_split(long_text: str) -> None:
        nonlocal current_seg
        for w in long_text.split():
            candidate = f"{current_seg} {w}".strip() if current_seg else w
            if len(candidate) <= max_chars:
                current_seg = candidate
            else:
                if current_seg:
                    segments.append(current_seg)
                current_seg = w[:max_chars]

    for sent in sentences:
        candidate_sent = f"{current_seg} {sent}".strip() if current_seg else sent
        if len(candidate_sent) <= max_chars:
            current_seg = candidate_sent
        else:
            if current_seg:
                segments.append(current_seg)
                current_seg = ""
            if len(sent) <= max_chars:
                current_seg = sent
            else:
                _flush_word_split(sent)
    if current_seg:
        segments.append(current_seg)
    return segments[:16]


def generate_audio_urls_list_sync(
    text: str,
    lang: str = "ar-EG",
    voice: Optional[str] = None,
) -> list[str]:
    """توليد قائمة روابط MP3 بالتوازي (Parallel) لكل مقطع من الرد الطويل حتى يبدأ النطق في أقل من ثانية ويكمل للنهاية."""
    import urllib.parse
    import urllib.request
    from concurrent.futures import ThreadPoolExecutor

    segments = split_text_into_tts_segments(text, max_chars=190, lang=lang)
    if not segments:
        return []

    lang_code = "ar" if (lang or "ar").lower().startswith("ar") else "en"
    ts_ms = int(time.time() * 1000)
    batch_id = uuid.uuid4().hex[:6]

    def _fetch_one(args: tuple[int, str]) -> tuple[int, Optional[str]]:
        idx, seg = args
        q = urllib.parse.quote(seg)
        g_url = f"https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl={lang_code}&q={q}"
        for attempt in range(2):
            try:
                req = urllib.request.Request(g_url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=5.0) as resp:
                    part_bytes = resp.read()
                    if part_bytes and len(part_bytes) > 128:
                        out_file = AUDIO_DIR / f"tts_{ts_ms}_{batch_id}_{idx}.mp3"
                        out_file.write_bytes(part_bytes)
                        return idx, f"/audio/{out_file.name}"
            except Exception as exc:
                if attempt == 1:
                    print(f"[SEGMENT-TTS WARNING] seg={idx} error={exc}", flush=True)
        return idx, None

    with ThreadPoolExecutor(max_workers=min(8, len(segments))) as pool:
        results = list(pool.map(_fetch_one, enumerate(segments)))

    results.sort(key=lambda x: x[0])
    urls = [u for _, u in results if u]
    if not urls:
        single = generate_audio_url_sync(text, lang=lang, voice=voice)
        if single:
            urls = [single]

    _prune_old_audio_files()
    return urls


async def generate_audio_url_async(
    text: str,
    lang: str = "ar-EG",
    voice: Optional[str] = None,
    rate: str = "-10%",
) -> Optional[str]:
    """حفظ ملف MP3 باسم فريد (timestamp + UUID) وإرجاع مساره /audio/tts_<ts>_<uuid>.mp3 لمنع كاش المتصفح."""
    cleaned = clean_for_speech(text, lang=lang)
    if not cleaned:
        return None

    chosen_voice = resolve_voice(lang, voice)
    ts_ms = int(time.time() * 1000)
    unique_id = uuid.uuid4().hex[:8]
    out_file = AUDIO_DIR / f"tts_{ts_ms}_{unique_id}.mp3"

    try:
        audio_bytes = await synthesize_mp3_bytes_async(cleaned, lang=lang, voice=chosen_voice, rate=rate)
        if audio_bytes:
            out_file.write_bytes(audio_bytes)
            _prune_old_audio_files()
            return f"/audio/{out_file.name}"
    except Exception as exc:
        print(f"[EDGE-TTS ERROR] Failed to write audio file: {exc}", flush=True)
    return None


def generate_audio_url_sync(
    text: str,
    lang: str = "ar-EG",
    voice: Optional[str] = None,
    rate: str = "-10%",
) -> Optional[str]:
    """تشغيل آمن لتوليد رابط MP3 فريد سواء داخل سياق متزامن أو داخل FastAPI event loop."""
    cleaned = clean_for_speech(text, lang=lang)
    if not cleaned:
        return None

    chosen_voice = resolve_voice(lang, voice)
    result_box: list[Optional[str]] = [None]

    def _worker() -> None:
        try:
            result_box[0] = asyncio.run(
                generate_audio_url_async(cleaned, lang=lang, voice=chosen_voice, rate=rate)
            )
        except Exception as exc:
            print(f"[EDGE-TTS THREAD ERROR] {exc}", flush=True)
            result_box[0] = None

    t = threading.Thread(target=_worker, daemon=True)
    t.start()
    t.join(timeout=18.0)
    return result_box[0]
