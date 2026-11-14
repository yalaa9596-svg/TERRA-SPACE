"""اختبار شامل لمنطق Terra Space (core.py, vision_engine.py, nasa_engine.py, matching_engine.py): python test_core.py"""
import core
import gemini_client
import matching_engine
import nasa_engine
import rag_engine
import vision_engine
import voice_assistant_engine


def fake_power(t=20.0, tmax=26.0, tmin=14.0, rh=60.0, soil=0.5, rain=0.0, n=30):
    days = [f"202610{d:02d}" if d <= 31 else f"202611{d-31:02d}" for d in range(1, n + 1)]
    mk = lambda v: {d: v for d in days}
    return {"T2M": mk(t), "T2M_MAX": mk(tmax), "T2M_MIN": mk(tmin),
            "PRECTOTCORR": mk(rain), "RH2M": mk(rh), "GWETROOT": mk(soil)}


apple, tomato = core.CROPS["apple"], core.CROPS["tomato"]

# 1) تفاح في جو معتدل -> مناسب للمزارع
clim = core.summarize(fake_power(t=18, tmax=26, tmin=9, rh=60))
r = core.suitability(apple, clim)
assert r["level"] == "yes", r
print("تفاح في جو معتدل:", r["verdict"], r["score"])

# 2) تفاح في جو حار جداً -> غير مناسب
clim = core.summarize(fake_power(t=33, tmax=42, tmin=26, rh=30))
r = core.suitability(apple, clim)
assert r["level"] == "no", r
story = core.story_check(apple, r, clim)
assert "المزارع" in story["text"]
print("تفاح في جو حار:", r["verdict"], r["score"])

# 3) اختبار محرك قواعد الري ذو الـ 5 حالات (5-State NASA Irrigation Engine)
dry_hot = core.summarize(fake_power(t=30, tmax=35, soil=0.15, rain=0), 7)
irr_urgent = core.irrigation(tomato, dry_hot, None)
assert irr_urgent["level"] == "urgent" and irr_urgent["state_ar"] == "ري عاجل"

irr_skip = core.irrigation(tomato, dry_hot, {"rain_next_2d": 10})
assert irr_skip["level"] == "skip" and irr_skip["state_ar"] == "لا تروي"

wet_wave = core.summarize(fake_power(t=25, tmax=30, soil=0.6, rain=2), 7)
irr_wave = core.irrigation(tomato, wet_wave, {"rain_next_2d": 0, "tmax_next_3d": 43.0})
assert irr_wave["level"] == "wave" and irr_wave["state_ar"] == "موجة حر أو برد"

wet_ok = core.summarize(fake_power(t=22, tmax=26, soil=0.7, rain=3), 7)
irr_ok = core.irrigation(tomato, wet_ok, {"rain_next_2d": 0})
assert irr_ok["level"] == "ok" and irr_ok["state_ar"] == "تمام"

dry_mild = core.summarize(fake_power(t=22, tmax=26, soil=0.15), 7)
irr_water = core.irrigation(tomato, dry_mild, None)
assert irr_water["level"] == "water" and irr_water["state_ar"] == "ري مطلوب"
print("محرك الري ذو الـ 5 حالات يعمل بنجاح ✅")

# 4) اختبار أقرب مهندس للمزارع (Haversine Matching Engine)
res = matching_engine.match_engineers(31.05, 31.38, core.ENGINEERS, k=3)
assert res[0]["governorate"] == "الدقهلية", res[0]
assert matching_engine.match_engineers(24.1, 32.9, core.ENGINEERS)[0]["governorate"] == "أسوان"
print("مطابقة المهندسين بـ Haversine تعمل بنجاح ✅")

# 5) اختبار محرك تشخيص الأمراض (PlantDoc Vision & Escalation Engine)
# أ) محصول مدعوم بثقة عالية (>= 75%) ومرض غير حرج -> لا يتطلب تصعيد إجباري
diag_early = vision_engine.diagnose_plant_image(
    crop_id="tomato",
    hint_class="Tomato Early Blight",
    simulated_confidence=0.88,
)
assert diag_early["supported_in_plantdoc"] is True
assert diag_early["escalate_to_engineer"] is False
assert "المزارع" in diag_early["voice_message_ar"]

# ب) محصول مدعوم بثقة أقل من 75% -> تصعيد تلقائي للمهندس
diag_low = vision_engine.diagnose_plant_image(
    crop_id="potato",
    hint_class="Potato Early Blight",
    simulated_confidence=0.68,
)
assert diag_low["escalate_to_engineer"] is True

# ج) محصول خارج نطاق PlantDoc (مثل القمح أو القطن) -> إحالة فورية لمهندس زراعي متخصص
diag_wheat = vision_engine.diagnose_plant_image(crop_id="wheat")
assert diag_wheat["supported_in_plantdoc"] is False
assert diag_wheat["escalate_to_engineer"] is True
assert "المزارع" in diag_wheat["voice_message_ar"]
print("محرك الرؤية PlantDoc والتصعيد للمهندس يعمل بنجاح ✅")

# 6) اختبار الدورة الزراعية
clim_winter = core.summarize(fake_power(t=19.0, tmax=23.0, tmin=14.0, rh=55.0, soil=0.28))
rot_good = core.evaluate_rotation("wheat", "clover", clim_winter)
assert rot_good["is_suitable"] is True
assert "المزارع" in rot_good["voice_dialogue"]
assert "الفلاح" not in rot_good["voice_dialogue"]

# 7) اختبار BM25 RAG واسترجاع أعلى 4 مقاطع
top_chunks = rag_engine.retrieve_top_k("القمح والنيتروجين والدورة الزراعية", k=4)
assert len(top_chunks) == 4, top_chunks
assert any("قمح" in c["text"] or "Wheat" in c["text"] for c in top_chunks)
assert gemini_client.get_api_key().startswith("AIza"), "GEMINI_API_KEY missing in .env"

# 8) اختبار المساعد الصوتي الحقيقي عبر Gemini + الذاكرة متعددة الأدوار + عدم إخفاء الأخطاء
voice_assistant_engine._SESSION_HISTORY.clear()
v_ar = voice_assistant_engine.generate_voice_reply(
    "أنا اسمي الحاج محمود، ينفع أزرع قمح بعد ذرة؟", "wheat", "clover", clim_winter, None,
    crops_map=core.CROPS, evaluate_rotation_fn=core.evaluate_rotation, irrigation_fn=core.irrigation,
    synthesize_audio=False, farmer_name="الحاج محمود", session_id="test_session_1",
)
assert v_ar["lang"] == "ar" and v_ar["crop_id"] == "wheat"
assert v_ar["ai_source"].startswith("gemini") and v_ar["ai_source"] != "gemini_connection_error"
assert v_ar["system_prompt_injected"] is True
assert v_ar["rotation"]["family_conflict"] is True
assert v_ar["turns_in_memory"] == 2

v_turn2 = voice_assistant_engine.generate_voice_reply(
    "أنا قولتلك اسمي إيه من شوية؟", "tomato", "clover", clim_winter, None,
    crops_map=core.CROPS, evaluate_rotation_fn=core.evaluate_rotation, irrigation_fn=core.irrigation,
    synthesize_audio=False, farmer_name="الحاج محمود", session_id="test_session_1",
)
assert v_turn2["ai_source"].startswith("gemini") and v_turn2["ai_source"] != "gemini_connection_error"
assert v_turn2["turns_in_memory"] == 4
assert "محمود" in v_turn2["reply"]

# اختبار رسالة الخطأ الصريحة عند فشل المفتاح (بدون أي ردود وهمية معلبة)
v_err = voice_assistant_engine.generate_voice_reply(
    "أروي إمتى؟", "wheat", "clover", clim_winter, None,
    crops_map=core.CROPS, evaluate_rotation_fn=core.evaluate_rotation, irrigation_fn=core.irrigation,
    gemini_api_key="AIza_INVALID_KEY_FOR_TEST", synthesize_audio=False, session_id="test_err_session",
)
assert v_err["ai_source"] == "gemini_connection_error"
assert v_err["reply"] == voice_assistant_engine.HONEST_CONNECTION_ERROR_AR

# 9) اختبار التكامل الحي مع Gemini RAG + edge-tts (ar-EG-ShakirNeural)
v_live = core.voice_assistant_reply("الجو حر أوي النهارده وأنا زارع طماطم، أروي ولا لأ؟", "tomato", "clover", clim_winter)
assert v_live["ai_source"].startswith("gemini") and v_live["ai_source"] != "gemini_connection_error"
assert len(v_live["rag_chunks"]) == 4
assert v_live["audio_url"] and v_live["audio_url"].startswith("/audio/tts_") and v_live["audio_url"].endswith(".mp3")
print("المساعد الصوتي بـ BM25 RAG + Gemini + ذاكرة المحادثة + edge-tts يعمل بنجاح ✅ | ai_source:", v_live["ai_source"], "| audio:", v_live["audio_url"])

# 10) اختبار اللغة الإنجليزية الصريحة + التبديل بين العربي والإنجليزي في نفس الجلسة (منع التهويس والخلط)
import re as _re
voice_assistant_engine._SESSION_HISTORY.pop("test_session_bilingual", None)
voice_assistant_engine._FARMER_LONG_TERM_MEMORY.pop("test_session_bilingual", None)
# 10) اختبار اللغة الإنجليزية الصريحة + التبديل بين العربي والإنجليزي في نفس الجلسة (منع التهويس والخلط)
import re as _re
voice_assistant_engine._SESSION_HISTORY.pop("test_session_bilingual", None)
voice_assistant_engine._FARMER_LONG_TERM_MEMORY.pop("test_session_bilingual", None)

v_bi_1 = voice_assistant_engine.generate_voice_reply(
    "أنا اسمي أمير وزراع بطاطس في الدقهلية",
    "potato", "clover", dry_hot, None,
    crops_map=core.CROPS, evaluate_rotation_fn=core.evaluate_rotation, irrigation_fn=core.irrigation,
    synthesize_audio=False, farmer_name="أمير", session_id="test_session_bilingual",
)
assert v_bi_1["lang"] == "ar" and v_bi_1["crop_id"] == "potato"

v_bi_2 = voice_assistant_engine.generate_voice_reply(
    "My name is Amir and I want to plant wheat after maize, should I irrigate today?",
    "wheat", "clover", dry_hot, None,
    crops_map=core.CROPS, evaluate_rotation_fn=core.evaluate_rotation, irrigation_fn=core.irrigation,
    synthesize_audio=True, farmer_name="Amir", session_id="test_session_bilingual",
)
assert v_bi_2["lang"] == "en"
assert v_bi_2["ai_source"].startswith("gemini") and v_bi_2["ai_source"] != "gemini_connection_error"
assert "conflict" in v_bi_2["reply"].lower(), v_bi_2["reply"]
assert not _re.search(r"[\u0600-\u06FF]", v_bi_2["reply"]), f"Arabic leaked into English reply: {v_bi_2['reply']}"
assert v_bi_2["audio_url"] and v_bi_2["audio_url"].endswith(".mp3")

v_bi_1 = voice_assistant_engine.generate_voice_reply(
    "أنا اسمي أمير وزراع بطاطس في الدقهلية",
    "potato", "clover", dry_hot, None,
    crops_map=core.CROPS, evaluate_rotation_fn=core.evaluate_rotation, irrigation_fn=core.irrigation,
    synthesize_audio=False, farmer_name="أمير", session_id="test_session_bilingual",
)
assert v_bi_1["lang"] == "ar" and v_bi_1["crop_id"] == "potato"

v_bi_2 = voice_assistant_engine.generate_voice_reply(
    "My name is Amir and I want to plant wheat after maize, should I irrigate today?",
    "wheat", "clover", dry_hot, None,
    crops_map=core.CROPS, evaluate_rotation_fn=core.evaluate_rotation, irrigation_fn=core.irrigation,
    synthesize_audio=True, farmer_name="Amir", session_id="test_session_bilingual",
)
assert v_bi_2["lang"] == "en"
assert v_bi_2["ai_source"].startswith("gemini") and v_bi_2["ai_source"] != "gemini_connection_error"
assert "conflict" in v_bi_2["reply"].lower(), v_bi_2["reply"]
assert not _re.search(r"[\u0600-\u06FF]", v_bi_2["reply"]), f"Arabic leaked into English reply: {v_bi_2['reply']}"
assert v_bi_2["audio_url"] and v_bi_2["audio_url"].endswith(".mp3")

v_bi_3 = voice_assistant_engine.generate_voice_reply(
    "I planted broccoli yesterday, what was the first crop I mentioned earlier?",
    "potato", "clover", dry_hot, None,
    crops_map=core.CROPS, evaluate_rotation_fn=core.evaluate_rotation, irrigation_fn=core.irrigation,
    synthesize_audio=False, farmer_name="Amir", session_id="test_session_bilingual",
)
assert v_bi_3["lang"] == "en" and v_bi_3["detected_crop_id"] == "custom_broccoli", v_bi_3["detected_crop_id"]
assert "potato" in v_bi_3["reply"].lower(), v_bi_3["reply"]

v_bi_4 = voice_assistant_engine.generate_voice_reply(
    "تمام، قولي تاني بالمصري أنا كنت زارع إيه الأول وأعمل إيه النهارده؟",
    "potato", "clover", dry_hot, None,
    crops_map=core.CROPS, evaluate_rotation_fn=core.evaluate_rotation, irrigation_fn=core.irrigation,
    synthesize_audio=False, farmer_name="أمير", session_id="test_session_bilingual",
)
assert v_bi_4["lang"] == "ar" and "البطاطس" in v_bi_4["reply"], v_bi_4["reply"]
print("Bilingual Arabic+English Voice Agent test passed ✅ | ai_source:", v_bi_2["ai_source"])

v_bi_3 = voice_assistant_engine.generate_voice_reply(
    "I planted broccoli yesterday, what was the first crop I mentioned earlier?",
    "potato", "clover", dry_hot, None,
    crops_map=core.CROPS, evaluate_rotation_fn=core.evaluate_rotation, irrigation_fn=core.irrigation,
    synthesize_audio=False, farmer_name="Amir", session_id="test_session_bilingual",
)
assert v_bi_3["lang"] == "en" and v_bi_3["detected_crop_id"] == "custom_broccoli", v_bi_3["detected_crop_id"]
assert "potato" in v_bi_3["reply"].lower(), v_bi_3["reply"]

v_bi_4 = voice_assistant_engine.generate_voice_reply(
    "تمام، قولي تاني بالمصري أنا كنت زارع إيه الأول وأعمل إيه النهارده؟",
    "potato", "clover", dry_hot, None,
    crops_map=core.CROPS, evaluate_rotation_fn=core.evaluate_rotation, irrigation_fn=core.irrigation,
    synthesize_audio=False, farmer_name="أمير", session_id="test_session_bilingual",
)
assert v_bi_4["lang"] == "ar" and "البطاطس" in v_bi_4["reply"], v_bi_4["reply"]
print("Bilingual Arabic+English Voice Agent test passed ✅ | ai_source:", v_bi_2["ai_source"])

# 11) اختبار وضع اللغة الإنجليزية (Global EN mode) للري والرؤية
irr_en = core.irrigation(tomato, dry_hot, None, language="en")
assert irr_en["level"] == "urgent" and irr_en["state_en"] == "Urgent Irrigation", irr_en
diag_en = vision_engine.diagnose_plant_image(
    crop_id="tomato",
    hint_class="Tomato Early Blight",
    simulated_confidence=0.88,
    language="en",
)
assert diag_en["language"] == "en" and "Tomato" in diag_en["crop_name"]
assert not _re.search(r"[\u0600-\u06FF]", diag_en["voice_message_ar"]), diag_en["voice_message_ar"]
print("Global English NASA Irrigation & PlantDoc Vision test passed ✅")

print("\nكل اختبارات Terra Space نجحت 100% ✅")
