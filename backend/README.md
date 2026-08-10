# ClassMusic resolve backend

Tiny FastAPI service that turns a YouTube video ID into a direct, iOS-playable
audio stream URL, using yt-dlp. This is the only piece of the pipeline that
talks to yt-dlp — search happens client-side against the YouTube Data API v3.

## Why this exists

`AVPlayer` can't play YouTube pages directly, and it can't decode the
Opus/WebM streams YouTube serves by default for "best audio" — it only
decodes AAC. So `/resolve` specifically forces itag 140 (`bestaudio[ext=m4a]`)
and hands back a googlevideo.com URL AVPlayer can stream straight from.

## Endpoints

- `GET /health` — unauthenticated. Used to wake a sleeping Render free
  instance and as an app-side cold-start probe.
- `GET /resolve?id=VIDEO_ID` — requires `X-API-Key` header if `BACKEND_API_KEY`
  is set. Returns `{ id, stream_url, title, artist, duration, thumbnail,
  resolved_at, expires_in }`. Results are cached in-memory for
  `RESOLVE_CACHE_TTL` seconds (default 4h) — googlevideo URLs are
  time-limited, so don't cache them longer than that on the client either.

## Local dev

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8123
curl "http://127.0.0.1:8123/resolve?id=dQw4w9WgXcQ"
```

## Deploying to Render (free tier)

1. Push this repo to GitHub.
2. Render dashboard → New → Blueprint → point at this repo (uses `render.yaml`).
3. Set the `BACKEND_API_KEY` env var to a random secret — put the same value
   in the iOS app's `Secrets.xcconfig` (see `ios/README.md`).
4. Free tier spins down after idle; first request after a cold start can take
   15-30s. The iOS app should hit `/health` first and show a loading state,
   not fire `/resolve` cold.

## Known constraint: YouTube vs. cloud IPs

yt-dlp vs. YouTube's bot detection is an ongoing arms race, worse from
datacenter IP ranges (Render/Fly) than from home IPs. If `/resolve` starts
returning 502s in production but works locally:

- `pip install -U yt-dlp` first — YouTube extractor fixes ship frequently and
  this is the most common fix.
- As a fallback, cookies from a real YouTube session can be supplied via
  `yt-dlp`'s `cookiefile` option — not wired up here since this is personal
  use, but worth knowing if datacenter IPs get consistently blocked.
