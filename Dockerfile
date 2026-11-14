FROM python:3.11-slim

WORKDIR /app

COPY smart_crop_backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY smart_crop_backend/ .
RUN rm -f .env *.env smartcrop.db && mkdir -p generated_audio

EXPOSE 8000

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]

