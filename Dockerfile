FROM python:3.13-slim
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY server.py ./
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 CHATGPT_AUTH_FILE=/credentials/auth.json
ENTRYPOINT ["python", "/app/server.py"]
