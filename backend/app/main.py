import logging

from fastapi import Depends, FastAPI, Header, HTTPException, Query

from app.config import settings
from app.resolve import InvalidVideoId, ResolveFailed, resolve_video

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("classmusic")

app = FastAPI(title="ClassMusic Resolve Backend", version="1.0.0")


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
    return {"status": "ok"}


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
