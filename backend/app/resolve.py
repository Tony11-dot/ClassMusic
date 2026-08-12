import os
import re
import time

from cachetools import TTLCache
from fastapi.concurrency import run_in_threadpool
from yt_dlp import YoutubeDL

from app.config import settings

_VIDEO_ID_RE = re.compile(r"^[a-zA-Z0-9_-]{11}$")

_cache: TTLCache = TTLCache(maxsize=settings.cache_max_size, ttl=settings.cache_ttl_seconds)

# Confirmed root cause of the standing 502s: YouTube serves Render's
# datacenter IP a bot-check wall ("Sign in to confirm you're not a bot") —
# reproduced with identical yt-dlp options/version from a residential IP,
# where it resolves fine. No player-client fallback works around this; the
# documented fix is authenticating requests with real YouTube cookies.
# Render's "Secret Files" feature mounts uploaded files under /etc/secrets/
# in the running container — add one there named `youtube_cookies.txt`
# (exported from a real, signed-in-to-YouTube browser session, Netscape
# cookies.txt format) and this picks it up automatically on next deploy.
# Until that file exists, resolution keeps working exactly as before for
# whatever isn't currently bot-walled.
_COOKIES_PATH = os.environ.get("YTDLP_COOKIES_FILE", "/etc/secrets/youtube_cookies.txt")

_YDL_OPTS = {
    # AVPlayer has no Opus/WebM support, so the default "bestaudio" pick
    # (usually itag 251, webm/opus) is silently unplayable on iOS. Force
    # AAC/m4a (itag 140) — the format Apple's stack actually decodes.
    "format": "bestaudio[ext=m4a]/bestaudio/best",
    "noplaylist": True,
    "quiet": True,
    "no_warnings": True,
    "skip_download": True,
    # Trying several player clients costs nothing and still helps for
    # anything that isn't the bot-check wall (format availability quirks,
    # a single client being independently rate-limited, etc).
    "extractor_args": {
        "youtube": {
            "player_client": ["ios", "android_vr", "android", "android_music"],
        }
    },
    **({"cookiefile": _COOKIES_PATH} if os.path.exists(_COOKIES_PATH) else {}),
}


class InvalidVideoId(ValueError):
    pass


class ResolveFailed(RuntimeError):
    pass


def _validate_video_id(video_id: str) -> None:
    if not _VIDEO_ID_RE.match(video_id):
        raise InvalidVideoId(video_id)


def _extract(video_id: str) -> dict:
    url = f"https://www.youtube.com/watch?v={video_id}"
    try:
        with YoutubeDL(_YDL_OPTS) as ydl:
            info = ydl.extract_info(url, download=False)
    except Exception as exc:  # yt-dlp raises its own DownloadError hierarchy
        raise ResolveFailed(str(exc)) from exc

    stream_url = info.get("url")
    if not stream_url:
        raise ResolveFailed("no stream url in extractor result")

    return {
        "id": video_id,
        "stream_url": stream_url,
        "title": info.get("title"),
        "artist": info.get("artist") or info.get("uploader"),
        "duration": info.get("duration"),
        "thumbnail": info.get("thumbnail"),
        "resolved_at": int(time.time()),
        "expires_in": settings.cache_ttl_seconds,
    }


async def resolve_video(video_id: str, *, force: bool = False) -> dict:
    _validate_video_id(video_id)

    if not force and video_id in _cache:
        return _cache[video_id]

    result = await run_in_threadpool(_extract, video_id)
    _cache[video_id] = result
    return result
