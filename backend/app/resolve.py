import os
import re
import shutil
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
# where it resolves fine. No anonymous player-client fallback works around
# this; the fix is authenticating with real YouTube cookies (see
# _AUTH_YDL_OPTS below for what that actually takes as of 2026 — it's not
# just "add cookiefile", the auth-capable client also needs a JS challenge
# solver and settles for a lower-quality combined stream).
# Render's "Secret Files" feature mounts uploaded files under /etc/secrets/
# in the running container — add one there named `youtube_cookies.txt`
# (exported from a real, signed-in-to-YouTube browser session, Netscape
# cookies.txt format) and this picks it up automatically on next deploy.
# Until that file exists, resolution keeps working exactly as before for
# whatever isn't currently bot-walled.
_COOKIES_SECRET_PATH = os.environ.get("YTDLP_COOKIES_FILE", "/etc/secrets/youtube_cookies.txt")
# Railway has no equivalent of Render's mounted Secret Files, so it takes the
# cookie file as a plain environment variable's raw text content instead.
_COOKIES_CONTENT = os.environ.get("YTDLP_COOKIES_CONTENT")


def _writable_cookies_path() -> str | None:
    # yt-dlp opens the cookiefile as a MozillaCookieJar and saves it back
    # after use (Google rotates the session cookies during a request), so
    # it needs a writable path — Render mounts Secret Files read-only,
    # which made every resolve fail with "Read-only file system" as soon
    # as yt-dlp tried to persist the rotated cookies. Copy it into /tmp
    # (writable) once at import time and use that copy instead.
    writable_path = "/tmp/youtube_cookies.txt"
    if os.path.exists(_COOKIES_SECRET_PATH):
        shutil.copyfile(_COOKIES_SECRET_PATH, writable_path)
        return writable_path
    if _COOKIES_CONTENT:
        with open(writable_path, "w") as f:
            f.write(_COOKIES_CONTENT)
        return writable_path
    return None


_COOKIES_PATH = _writable_cookies_path()

_BASE_YDL_OPTS = {
    "noplaylist": True,
    "quiet": True,
    "no_warnings": True,
    "skip_download": True,
}

# Anonymous, mobile-app-flavored clients — no cookies attached. These use
# their own embedded API keys rather than a browser session, so yt-dlp
# refuses to even try them once a cookiefile is configured on the instance
# ("does not support cookies", silently skipped). Tried first because it's
# the cheaper, better-quality path: itag 140 is real AAC/m4a *audio-only*,
# vs. the fallback path's combined video+audio. Whether this succeeds
# depends entirely on whether YouTube bot-walls the requesting IP for this
# particular request — Render's datacenter IP frequently does.
_ANON_YDL_OPTS = {
    **_BASE_YDL_OPTS,
    # AVPlayer has no Opus/WebM support, so the default "bestaudio" pick
    # (usually itag 251, webm/opus) is silently unplayable on iOS. Force
    # AAC/m4a (itag 140) — the format Apple's stack actually decodes.
    "format": "bestaudio[ext=m4a]/bestaudio/best",
    "extractor_args": {
        "youtube": {"player_client": ["ios", "android_vr", "android", "android_music"]},
    },
}

# Cookie-authenticated fallback for when the anonymous path gets bot-walled.
# "web" is the only client that honors a browser cookie jar at all. As of
# 2026 it also needs a JS runtime (Deno, installed in the Dockerfile) to
# solve YouTube's signature/n-parameter challenge — without one, every
# non-storyboard format silently disappears. Even then, the pure-audio
# adaptive formats (itag 140 included) require a GVS PO Token we don't have
# a provider for, so this only ever gets the legacy progressive format
# (itag 18: 360p h264 + AAC, combined) — heavier than pure audio, but it's
# a real, playable stream, which is what actually matters here.
_AUTH_YDL_OPTS = {
    **_BASE_YDL_OPTS,
    "format": "bestaudio[ext=m4a]/bestaudio/best",
    "extractor_args": {"youtube": {"player_client": ["web"]}},
    "remote_components": ["ejs:github"],
    "cookiefile": _COOKIES_PATH,
}


class InvalidVideoId(ValueError):
    pass


class ResolveFailed(RuntimeError):
    pass


def _validate_video_id(video_id: str) -> None:
    if not _VIDEO_ID_RE.match(video_id):
        raise InvalidVideoId(video_id)


def _run_extract(opts: dict, url: str) -> dict:
    with YoutubeDL(opts) as ydl:
        return ydl.extract_info(url, download=False)


def _extract(video_id: str) -> dict:
    url = f"https://www.youtube.com/watch?v={video_id}"
    try:
        info = _run_extract(_ANON_YDL_OPTS, url)
    except Exception as anon_exc:  # yt-dlp raises its own DownloadError hierarchy
        if not _COOKIES_PATH:
            raise ResolveFailed(str(anon_exc)) from anon_exc
        try:
            info = _run_extract(_AUTH_YDL_OPTS, url)
        except Exception as auth_exc:
            raise ResolveFailed(f"{anon_exc} / auth fallback: {auth_exc}") from auth_exc

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
