FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY server.py ./
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 CHATGPT_AUTH_FILE=/credentials/auth.json
ENTRYPOINT ["python", "/app/server.py"]
