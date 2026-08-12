import logging

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import StreamingResponse

from app.config import settings
from app.resolve import InvalidVideoId, ResolveFailed, resolve_video

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("classmusic")

app = FastAPI(title="ClassMusic Resolve Backend", version="1.0.0")

# Reused across requests: googlevideo URLs are cryptographically bound (via
# the `ip` param baked into `sparams`) to whichever IP fetched them, so a
# client fetching the raw URL directly gets rejected — the audio has to be
# proxied through this same process/IP that resolved it.
_stream_client = httpx.AsyncClient(follow_redirects=True, timeout=httpx.Timeout(30.0, read=60.0))


@app.on_event("shutdown")
async def _close_stream_client() -> None:
    await _stream_client.aclose()


async def require_api_key(x_api_key: str | None = Header(default=None)) -> None:
    if settings.api_key is None:
        # No key configured (e.g. local dev) — leave the endpoint open.
        return
    if x_api_key != settings.api_key:
        raise HTTPException(status_code=401, detail="invalid or missing X-API-Key")


@app.get("/health")
async def health() -> dict:
    # Unauthenticated on purpose: this is what wakes a sleeping free-tier
    # instance (Render) via an uptime ping / the app's cold-start probe.
    # "build" is a bump-by-hand marker (not real versioning) purely so a
    # deploy can be confirmed live from the outside without dashboard/log
    # access — compare it before/after a push instead of guessing from
    # elapsed time whether the new image actually rolled out.
    return {"status": "ok", "build": "resolve-cookies-3"}


@app.get("/resolve")
async def resolve(
    id: str = Query(..., min_length=11, max_length=11, description="YouTube video ID"),
    _: None = Depends(require_api_key),
) -> dict:
    try:
        return await resolve_video(id)
    except InvalidVideoId:
        raise HTTPException(status_code=400, detail="malformed video id")
    except ResolveFailed as exc:
        logger.warning("resolve failed for %s: %s", id, exc)
        raise HTTPException(status_code=502, detail="could not resolve stream for this video")


_PASSTHROUGH_HEADERS = ("content-type", "content-length", "content-range", "accept-ranges")


@app.get("/stream")
async def stream(
    request: Request,
    id: str = Query(..., min_length=11, max_length=11, description="YouTube video ID"),
    _: None = Depends(require_api_key),
) -> StreamingResponse:
    try:
        resolved = await resolve_video(id)
    except InvalidVideoId:
        raise HTTPException(status_code=400, detail="malformed video id")
    except ResolveFailed as exc:
        logger.warning("resolve failed for %s: %s", id, exc)
        raise HTTPException(status_code=502, detail="could not resolve stream for this video")

    range_header = request.headers.get("range")
    upstream_headers = {"range": range_header} if range_header else {}

    async def open_upstream(stream_url: str) -> httpx.Response:
        req = _stream_client.build_request("GET", stream_url, headers=upstream_headers)
        return await _stream_client.send(req, stream=True)

    upstream = await open_upstream(resolved["stream_url"])
    if upstream.status_code in (403, 404):
        # A stale cached URL (or one issued to a since-recycled egress IP)
        # reads as a rejection here — force a fresh resolve and retry once.
        await upstream.aclose()
        resolved = await resolve_video(id, force=True)
        upstream = await open_upstream(resolved["stream_url"])

    if upstream.status_code >= 400:
        await upstream.aclose()
        logger.warning("upstream stream fetch failed for %s: %s", id, upstream.status_code)
        raise HTTPException(status_code=502, detail=f"upstream returned {upstream.status_code}")

    headers = {key: upstream.headers[key] for key in _PASSTHROUGH_HEADERS if key in upstream.headers}
    headers.setdefault("accept-ranges", "bytes")

    async def body():
        try:
            async for chunk in upstream.aiter_bytes():
                yield chunk
        finally:
            await upstream.aclose()

    return StreamingResponse(
        body(),
        status_code=upstream.status_code,
        media_type=headers.get("content-type", "audio/mp4"),
        headers=headers,
    )
