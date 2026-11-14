# Terra Space — NASA Space Apps Cairo 2026

**Team:** NOVERA  
**Challenge:** Field Shift: Adapting Farms with NASA  
**Event:** NASA Space Apps Challenge — Cairo 2026  

---

## Overview

**Terra Space** is a bilingual (**Egyptian Arabic `ar-EG` RTL & Global English `en-US` LTR**) mobile and web precision-agriculture application built to help farmers adapt to extreme weather shifts, water scarcity, crop-rotation failures, and acute plant diseases.

It transforms live **NASA POWER** agroclimatology telemetry and **Open-Meteo** short-term forecasts into plain-language irrigation guidance (`L/m²`), botanical crop-rotation checks, **PlantDoc** visual leaf disease triage, voice-first AI guidance grounded via **BM25 RAG**, and **Haversine GPS escalation** to nearby agricultural engineers.

---

## Key Working Features

1. **NASA 5-State Irrigation Advisor (`smart_crop_backend/nasa_engine.py`)**
   - Pulls 6 NASA POWER (`AG` community) daily parameters (`T2M`, `T2M_MAX`, `T2M_MIN`, `RH2M`, `GWETROOT`, `PRECTOTCORR`) with sentinel `-999` filtering and monthly climatology fallback, fused with Open-Meteo 48–72h rainfall and temperature forecasts.
   - Issues five clear irrigation decisions: **Urgent Irrigation**, **Irrigation Needed**, **Do Not Irrigate** (`>= 5 mm` forecasted rainfall within 48h), **Heat / Cold Wave**, or **All Good**, plus recommended daily watering depth (`L/m²`).
2. **Smart Crop Rotation Engine (`smart_crop_backend/core.py` & `smart_crop_app/lib/services/rotation_engine.dart`)**
   - Evaluates climatic fit across **24 crops**, flags same botanical-family conflicts (e.g., *Poaceae -> Poaceae* or *Solanaceae -> Solanaceae*), and recommends compatible alternatives using Egyptian governorate presets, global agricultural hubs, or live GPS coordinates.
3. **PlantDoc AI Vision Doctor & Safety Escalation (`smart_crop_backend/vision_engine.py`)**
   - Analyzes leaf images across **27 PlantDoc disease/healthy classes** using multimodal **Google Gemini Vision** with deterministic offline PlantDoc fallback.
   - Automatically escalates cases to the nearest matched agronomist when confidence `< 75%`, disease severity is high, or the crop sits outside PlantDoc's 11-crop leaf scope (e.g., Wheat, Cotton, Olive).
4. **Geo-Matched Agronomist Portal (`smart_crop_backend/matching_engine.py`)**
   - Ranks engineers across **5 agricultural specialties** using great-circle **Haversine distance (km)** and comes pre-seeded with 15 default engineers plus live registration, telemetry inspection, and prescription replies.
5. **Local / Global Bilingual Voice Companion (`smart_crop_backend/voice_assistant_engine.py` & `tts_service.py`)**
   - One-tap switch between **Local Mode (`ar-EG` / `ar-EG-ShakirNeural`)** and **Global Mode (`en-US` / `en-US-GuyNeural`)**, backed by `BM25Okapi` agronomic RAG (`rag_engine.py`) and persistent SQLite farmer chat history.

---

## Project Structure

- `smart_crop_backend/` — Python 3 + FastAPI backend (`main.py`, `nasa_engine.py`, `core.py`, `vision_engine.py`, `matching_engine.py`, `rag_engine.py`, `voice_assistant_engine.py`, `tts_service.py`, `test_core.py`, `Dockerfile`, `Procfile`, `.env.example`)
- `smart_crop_app/` — Flutter cross-platform Android & Web frontend (`lib/`, `assets/terra_logo.png`, `test/widget_test.dart`)
- `submission/` — NASA Space Apps deliverables (Documentation PDF, 7-Slide Backup Deck PDF, submission answer sheet, compiled `TerraSpace.apk`)

---

## Setup & Running Locally

### 1. Backend (FastAPI + Python 3)

```bash
cd smart_crop_backend
pip install -r requirements.txt
cp .env.example .env
# Edit .env and set GEMINI_API_KEY=<your_google_gemini_api_key>
uvicorn main:app --host 0.0.0.0 --port 8000
```

Health check endpoint: `http://localhost:8000/health`

#### Docker / Cloud Deployment (Railway, Render, Fly.io)
A ready-to-deploy `smart_crop_backend/Dockerfile`, `smart_crop_backend/.dockerignore`, and `smart_crop_backend/Procfile` are included. Set `GEMINI_API_KEY` in the cloud environment variables.

### 2. Frontend (Flutter Web & Android APK)

```bash
cd smart_crop_app
flutter pub get

# Run on Chrome against local backend:
flutter run -d chrome --dart-define=API_URL=http://localhost:8000

# Build production Web bundle pointing to your deployed backend:
flutter build web --no-pub --dart-define=API_URL=https://<your-backend-url>

# Build Android Release APK:
flutter build apk --release --no-pub --dart-define=API_URL=https://<your-backend-url>
```

> Note: Users and judges can also override the Backend URL directly from the Server URL dialog inside the app UI (`AuthScreen` / `HomeScreen`).

---

## Verification & Tests

Run backend core integration checks:
```bash
cd smart_crop_backend
python -X utf8 test_core.py
```

Run Flutter static analysis and widget tests:
```bash
cd smart_crop_app
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
```

---

## Current Limitations & Future Plans

### Limitations
- **Demo Authentication & Local Storage:** Uses SQLite (`smartcrop.db`) and a demo OTP flow (`1234`) for fast hackathon judging rather than a paid SMS OTP gateway.
- **Browser Autoplay Policy:** Web browsers require a user click before unlocking spoken TTS playback.
- **Offline Vision Fallback:** When cloud Vision API connectivity is unavailable, local fallback relies on deterministic keyword/hash matching over the supported PlantDoc classes.

### Future Plans
- Production cloud deployment with managed PostgreSQL & live SMS OTP authentication.
- High-resolution **Sentinel-2 NDVI** vegetation vigor layers and **SoilGrids** root-depth soil taxonomy fusion.
- Quantized on-device **TensorFlow Lite** PlantDoc weights for zero-connectivity rural inference.

---

## NASA Data, Partner Data & AI/SI Disclosure

- **NASA Data:** NASA Langley Research Center (LaRC) **POWER API** Agroclimatology (`AG`) Daily & Climatology point services (`https://power.larc.nasa.gov/api/temporal/daily/point`, `https://power.larc.nasa.gov/api/temporal/climatology/point`).
- **Partner & Open Data:** **Open-Meteo Forecast API** (`https://api.open-meteo.com/v1/forecast`, CC BY 4.0) and **PlantDoc Classification Dataset** (`https://www.kaggle.com/datasets/nirmalsankalana/plantdoc-dataset`).
- **AI / Super Intelligence (SI):** Google Gemini Vision & Chat REST APIs (leaf disease classification and grounded voice responses), `rank-bm25` sparse retrieval, `edge-tts` neural voices (with text displayed alongside spoken audio), and AI-assisted code/test refactoring validated by automated backend & Flutter tests. No NASA logos, flags, insignias, or mission identifiers were generated or modified by AI; Terra Space uses an original custom sprout-and-orbit logo.

