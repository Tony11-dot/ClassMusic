import re
import time

from cachetools import TTLCache
from fastapi.concurrency import run_in_threadpool
from yt_dlp import YoutubeDL

from app.config import settings

_VIDEO_ID_RE = re.compile(r"^[a-zA-Z0-9_-]{11}$")

_cache: TTLCache = TTLCache(maxsize=settings.cache_max_size, ttl=settings.cache_ttl_seconds)

_YDL_OPTS = {
    # AVPlayer has no Opus/WebM support, so the default "bestaudio" pick
    # (usually itag 251, webm/opus) is silently unplayable on iOS. Force
    # AAC/m4a (itag 140) — the format Apple's stack actually decodes.
    "format": "bestaudio[ext=m4a]/bestaudio/best",
    "noplaylist": True,
    "quiet": True,
    "no_warnings": True,
    "skip_download": True,
    # A single player client (previously just the default/android_vr) is a
    # single point of failure: YouTube blocks individual client+IP
    # combinations independently, and Render's datacenter IP gets flagged
    # far more readily than a residential one. Listing several clients lets
    # yt-dlp fall back automatically if one is currently blocked for this
    # IP. All of these avoid the JS-runtime signature path (the container
    # has no deno/node installed), unlike "web".
    "extractor_args": {
        "youtube": {
            "player_client": ["ios", "android_vr", "android", "android_music"],
        }
    },
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
