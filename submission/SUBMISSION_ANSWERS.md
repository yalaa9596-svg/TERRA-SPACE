# Terra Space — Team NOVERA Submission Copy-Paste Sheet
**Event:** NASA Space Apps Cairo 2026  
**Team Name:** NOVERA  
**Selected Challenge:** Field Shift: Adapting Farms with NASA  

> **BEFORE CLICKING SUBMIT — CHECK THESE 4 ITEMS:**
> 1. Replace `[INSERT TEAM MEMBERS' FULL NAMES HERE]` in `TerraSpace_NOVERA_Documentation.html` (and regenerate PDF) before uploading to Google Drive!
> 2. Upload your `<= 30s` demo video (with English subtitles if spoken in Arabic) OR `TerraSpace_NOVERA_Demo_7Slides.pdf` to Google Drive / YouTube Unlisted, set **"Anyone with the link can view"**, and verify it opens in an **Incognito browser window without login**.
> 3. For **Question 3 (Link to your final project)**, Cairo/NASA rules require a **working app judges can open directly** (source code alone is NOT sufficient). Upload `TerraSpace.apk` (Android release APK) AND host the live Web + FastAPI backend URLs (e.g., Netlify + Railway), plus include your source code repo/archive link as a supporting link.
> 4. Check below **Question 9** on the Google Form after scrolling down to ensure no extra team email / checkbox fields were left unanswered!

---

## Question 1 — Link Of Your Global Project Page *
1. Log in at `https://www.spaceappschallenge.org/` -> **Profile Icon -> My Team -> Project -> Edit**.
2. Paste the fields below into the Global Project Page fields.
3. Click **Save Progress** often, then review Terms & Conditions + Originality Confirmation boxes and click **Submit for Judging**.
4. Copy the final submitted Project page URL from `spaceappschallenge.org` and paste it into **Question 1** on the Cairo Google Form.

*(Global Page `Project Name`)*
```text
Terra Space
```

---

## Question 2 — Project Demo Link *
Paste the public Incognito-accessible URL to your **<= 30-second video** (YouTube Unlisted / Google Drive "Anyone with link") **OR** your **7-slide English PDF** (`submission/TerraSpace_NOVERA_Demo_7Slides.pdf`).
- Must stay strictly `<= 30 seconds` video OR `<= 7 slides` TOTAL (exceeding causes Global Judging disqualification).
- Must clearly include team name (`NOVERA`), team members' names, challenge (`Field Shift: Adapting Farms with NASA`), problem, how the solution works, NASA/space-agency data, benefit, and visuals of the working prototype.

---

## Question 3 — Link to your final project *
Replace `<LIVE_APP_URL>`, `<APK_DRIVE_LINK>`, and `<SOURCE_REPO_OR_ZIP_LINK>` below before pasting into Question 3:

```text
Live Working Web App: <LIVE_APP_URL>
Android Release APK (Direct Install, 52.2 MB): <APK_DRIVE_LINK>
Source Code & Setup Instructions (Supporting Link): <SOURCE_REPO_OR_ZIP_LINK>

How Judges Can Test Immediately (No Login Friction):
1. Open the Live Web App or install TerraSpace.apk on Android. Use the top bar toggle to switch between English (Global Mode, LTR) and Arabic (Local Mode, RTL).
2. Complete Quick Farmer Onboarding using any GPS coordinates, Egyptian governorate, or global agricultural hub (no SMS gateway needed; demo OTP is 1234 if using OTP sign-in).
3. Test the tabs:
   - Irrigation Advisor: Live NASA POWER 6-parameter climate & root-zone soil wetness + Open-Meteo 48h forecast producing 1 of 5 actionable states and L/m² guidance.
   - Crop Rotation: Enter any previous crop + target crop to test botanical-family conflict detection (e.g., Poaceae -> Poaceae) and climate-matched alternatives.
   - PlantDoc Vision Doctor: Upload any crop leaf photo for 27-class PlantDoc diagnosis and automatic Haversine engineer escalation if confidence < 75%, severe disease, or crop is outside PlantDoc's 11-crop leaf scope (e.g., Wheat, Cotton, Olive).
   - Voice Assistant & Engineers: Speak or type farming questions for grounded BM25 RAG + NASA telemetry advice, or switch to the Engineer Portal to register/inspect assigned farmer escalations and send prescriptions.

Verified Working Features vs. Limitations & Future Plans:
- Working & Verified Today: Live NASA POWER & Open-Meteo telemetry fusion; 5-state L/m² irrigation engine; 24-crop botanical-family rotation engine; 27-class PlantDoc Gemini Vision triage with offline deterministic fallback and <75% escalation; Haversine engineer matching across 5 specialties (15 pre-seeded agronomists); bilingual ar-EG / en-US voice & text companion with SQLite persistent memory; automated backend test suite (test_core.py) and Flutter analyzer + 8/8 widget/unit tests.
- Current Limitations: Local SQLite storage and demo OTP code (1234) streamline hackathon evaluation; web browsers require an initial click to unlock audio autoplay; offline vision fallback uses heuristic/hash matching across PlantDoc categories when cloud connectivity drops.
- Future Plans: Managed cloud PostgreSQL backend, live SMS OTP gateway, Sentinel-2 NDVI & SoilGrids spatial layers, and on-device TensorFlow Lite PlantDoc inference for zero-connectivity farms.
```

---

## Question 4 — High-Level Project Summary *
*(Use identical text on both Global Project Page `High-Level Project Summary` and Cairo Google Form Question 4)*

```text
Terra Space is a bilingual (Arabic & English) mobile and web precision-agriculture platform built by Team NOVERA for the "Field Shift: Adapting Farms with NASA" challenge. Smallholder farmers frequently lose crops and scarce water due to weather volatility, ill-timed irrigation, conflicting crop-family rotations, and slow diagnosis of sudden leaf diseases. Terra Space integrates live NASA POWER agroclimatology telemetry (air temperature, relative humidity, root-zone soil wetness, and precipitation) with Open-Meteo 48-72h forecasts, a botanical crop-rotation checker, PlantDoc visual disease triage, GPS Haversine matching to nearby agricultural engineers, and a voice-first AI companion—giving farmers simple, actionable daily guidance in Egyptian Arabic or Global English while escalating uncertain or severe cases to local human specialists.
```

---

## Question 5 — Project Details *
*(Use consistent text on both Global Project Page `Detailed Project Description`, Cairo Google Form Question 5, and Sections 2 & 3 of the PDF)*

```text
WHAT IT DOES & HOW IT WORKS
Terra Space translates complex Earth-observation data into immediate daily field actions across five integrated modules:
1. NASA 5-State Irrigation Advisor: Queries NASA POWER point telemetry (30-day & 7-day daily series with monthly climatology fallback) and Open-Meteo 3-day forecasts for the farmer's exact latitude/longitude. It evaluates crop-specific thresholds to issue one of five clear decisions—Urgent Irrigation, Irrigation Needed, Do Not Irrigate (when >=5 mm of rain is forecasted within 48 hours), Heat / Cold Wave, or All Good—along with recommended daily irrigation volume in L/m².
2. Smart Crop Rotation Engine: Covers 24 field and horticultural crops. It prevents planting the same botanical family back-to-back (e.g., Poaceae -> Poaceae such as Maize after Wheat, or Solanaceae -> Solanaceae) while recommending climatically compatible alternative crops using NASA temperature and humidity tolerances across Egyptian governorates, global agricultural hubs, and live GPS coordinates.
3. PlantDoc AI Vision Doctor & Safety Escalation: Classifies uploaded leaf images against 27 disease and healthy classes from the PlantDoc benchmark using multimodal Google Gemini Vision (plus deterministic local fallback). Any diagnosis with <75% confidence, high severity, or crops outside PlantDoc's 11-crop leaf scope (such as Wheat, Cotton, or Olive) automatically escalates to the nearest matched agricultural engineer.
4. Geo-Matched Engineer Portal (Haversine): Ranks agronomists across 5 specialties (Plant Pathology, Field Crops, Vegetables, Fruits & Orchards, Irrigation & Soil) using exact great-circle Haversine distance from the farm. Engineers can register, inspect live NASA telemetry for their assigned farmers, and reply with direct prescriptions.
5. Bilingual Local & Global Voice Companion: Supports one-tap switching between Local Mode (Egyptian Arabic RTL, ar-EG speech recognition, ar-EG-ShakirNeural TTS) and Global Mode (English LTR, en-US speech recognition, en-US-GuyNeural TTS), backed by BM25 sparse retrieval (rank-bm25) over agronomic documents and persistent SQLite per-farmer conversation memory.

TOOLS, LANGUAGES, HARDWARE & SOFTWARE USED
- Frontend: Flutter / Dart (Material UI, Provider, speech_to_text, flutter_tts, image_picker, geolocator, shared_preferences, url_launcher) compiled into a release Android APK (52.2 MB) and responsive Web bundle.
- Backend: Python 3, FastAPI, Uvicorn, HTTPX, Requests, SQLite (smartcrop.db), rank-bm25 (BM25Okapi), and edge-tts. Docker/Procfile configs are included for cloud deployment.
- Hardware: Standard Android smartphone or web browser (camera, microphone, and GPS optional) communicating with a Python 3 backend server connected to NASA POWER, Open-Meteo, and Gemini APIs.

WORKING FEATURES & EVIDENCE vs. LIMITATIONS & FUTURE PLANS
- Verified Working Evidence: Automated backend integration tests (smart_crop_backend/test_core.py) verify live bilingual 5-state NASA irrigation, Haversine engineer matching, PlantDoc low-confidence and out-of-scope escalation, BM25 RAG + Gemini multi-turn memory, and Arabic/English neural speech output. Flutter static analysis passed with 0 errors/warnings and 8/8 unit/widget tests in test/widget_test.dart passed (covering rotation conflict detection, PlantDoc escalation alerts, honest offline error handling, single language toggle, and live English UI switching).
- Limitations: Uses local SQLite storage and demo OTP code (1234) for hackathon testing; web audio requires an initial user click due to browser autoplay policies; deterministic offline disease fallback uses filename/hash heuristics when disconnected from cloud Vision APIs.
- Future Plans: Production PostgreSQL cloud hosting, verified SMS OTP authentication, Sentinel-2 NDVI and SoilGrids spatial layers, and quantized on-device TensorFlow Lite PlantDoc inference for zero-connectivity rural regions.
```

---

## Question 6 — NASA Data *
*(Consistent across Global Page `NASA Data` & Cairo Form Question 6)*

```text
NASA POWER API (Prediction Of Worldwide Energy Resources) — NASA Langley Research Center (LaRC) Agroclimatology (AG) Community
- Daily Point Endpoint: https://power.larc.nasa.gov/api/temporal/daily/point
- Climatology Point Endpoint (fallback): https://power.larc.nasa.gov/api/temporal/climatology/point

Area & Time Period: Exact farmer latitude/longitude point queries across Egypt governorates, global agricultural hubs, or device GPS coordinates over trailing 30-day and 7-day daily series (plus long-term monthly climatology fallback when recent daily series are delayed).

Parameters Used:
1. T2M (2m Mean Air Temperature, °C)
2. T2M_MAX (2m Maximum Air Temperature, °C)
3. T2M_MIN (2m Minimum Air Temperature, °C)
4. RH2M (2m Relative Humidity, %)
5. GWETROOT (Root-Zone Soil Wetness, 0-1 index)
6. PRECTOTCORR (Bias-Corrected Precipitation, mm/day)

Processing & Role: Our NASA data module (nasa_engine.py) filters NASA POWER sentinel -999 missing flags, computes 30-day and 7-day averages/extremes/totals, fuses GWETROOT and temperature telemetry with short-term precipitation forecasts to compute daily L/m² irrigation states, scores crop-rotation climatic suitability across 24 crops, and surfaces raw satellite metrics inside the Agronomist Portal.
```

---

## Question 7 — Space Agency Partner & Other Data *
*(Consistent across Global Page `Space Agency Partner Data and Other References` & Cairo Form Question 7)*

```text
1. Open-Meteo Forecast API (https://api.open-meteo.com/v1/forecast)
   - Usage: Supplies current temperature, humidity, wind, field elevation, and 3-day daily precipitation & temperature forecasts to halt irrigation when >=5 mm rain is expected within 48 hours and warn of impending heat/cold waves.
   - Attribution/License: Weather data by Open-Meteo.com (CC BY 4.0).

2. PlantDoc Classification Dataset (https://www.kaggle.com/datasets/nirmalsankalana/plantdoc-dataset)
   - Usage: Defines the 27 leaf disease and healthy classification taxonomy (across crops such as Tomato, Potato, Maize/Corn, Apple, Grape, Bell Pepper, Strawberry, Peach, and Soybean) powering visual triage, symptom descriptions, and treatment baselines.
   - Attribution: Public PlantDoc research benchmark hosted on Kaggle (CC0: Public Domain dataset listing / original PlantDoc research attribution).

3. Open-Source Libraries & Software Stack:
   - Flutter & Dart SDK packages (BSD-3-Clause): provider, http, geolocator, image_picker, speech_to_text, flutter_tts, shared_preferences, url_launcher
   - Python Backend Libraries: FastAPI & Uvicorn (open-source ASGI framework/server), httpx & python-dotenv (BSD-3-Clause), requests & rank-bm25 (Apache-2.0), edge-tts (LGPLv3 interface to Microsoft Neural Voices ar-EG-ShakirNeural and en-US-GuyNeural)
```

---

## Question 8 — Use of Artificial Intelligence / Super Intelligence (AI/SI) *
*(Consistent across Global Page `Use of Super Intelligence (SI)` & Cairo Form Question 8)*

```text
Team NOVERA used the following AI / Super Intelligence (SI) tools and transparently identifies every affected component:

1. Google Gemini REST API (Gemini Flash-Lite / Multimodal Vision & Text Chat Models)
   - Vision Triage (smart_crop_backend/vision_engine.py): Classifies farmer-uploaded leaf photos across the 27 PlantDoc categories, describes observed symptoms, and outputs structured confidence and severity scores. When confidence < 75%, infection is severe, or the crop falls outside PlantDoc's scope, Terra Space escalates to a human agronomist.
   - Conversational Advisor (smart_crop_backend/voice_assistant_engine.py): Generates concise, bilingual farmer replies grounded strictly in retrieved NASA POWER telemetry, Open-Meteo forecasts, BM25 RAG passages, and persistent SQLite conversation memory. System prompts forbid fabricating telemetry values.

2. BM25 Sparse Information Retrieval (rank-bm25 / BM25Okapi)
   - Grounding Engine (smart_crop_backend/rag_engine.py): Indexes curated agronomic knowledge files with Egyptian colloquial-to-scientific synonym expansion before prompt construction.

3. Neural Speech Synthesis (edge-tts) & Speech-to-Text (speech_to_text)
   - Audio & Voice Interface (smart_crop_backend/tts_service.py, smart_crop_app/lib/services/voice_service.dart): Synthesizes verified backend advice into spoken audio in Egyptian Arabic (ar-EG-ShakirNeural) and Global English (en-US-GuyNeural) and transcribes spoken farmer queries.
   - Audio Acknowledgement: All generated speech output strictly reads verified response text derived from NASA POWER / PlantDoc calculations and is always displayed as readable on-screen text alongside audio metadata.

4. AI-Assisted Software Engineering Disclosure (Code & Documentation)
   - Code/Data Acknowledgement: AI coding assistants helped accelerate UI localization scaffolding, refactoring, test automation, and submission documentation formatting. Every module and response was verified locally through backend integration tests (test_core.py) and Flutter static analysis + widget tests (flutter analyze / flutter test).

5. NASA Branding & Visual Integrity Compliance
   - No NASA logos, flags, insignias, or mission identifiers were generated or modified by AI. Terra Space uses an independently created sprout-and-orbit application icon.
```

---

## Question 9 — Link of Project Documentation File (PDF) *
1. Provide **Team NOVERA members' full English names** so `[INSERT TEAM MEMBERS' FULL NAMES HERE]` in `submission/TerraSpace_NOVERA_Documentation.html` is replaced and `submission/TerraSpace_NOVERA_Documentation.pdf` is re-generated cleanly.
2. Upload `TerraSpace_NOVERA_Documentation.pdf` to Google Drive -> Share -> **"Anyone with the link" (Viewer)** -> verify opening in an **Incognito browser window** -> paste the public VIEW link into Question 9.

