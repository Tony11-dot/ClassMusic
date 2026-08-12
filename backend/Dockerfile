FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg curl unzip \
    && rm -rf /var/lib/apt/lists/*

# yt-dlp needs a JS runtime to solve YouTube's signature/n-parameter
# challenge for the cookie-authenticated ("web") client — the only client
# that honors youtube_cookies.txt at all. Without this, that fallback path
# silently returns storyboard-only results (see app/resolve.py). Deno was
# picked over Node for size — the slim base image doesn't ship a runtime
# and Deno's install is a single static binary.
ENV DENO_INSTALL=/usr/local
RUN curl -fsSL https://deno.land/install.sh | sh

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
