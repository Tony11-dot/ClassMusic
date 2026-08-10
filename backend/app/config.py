import os


class Settings:
    # .strip(): dashboard env-var text areas are an easy way to paste in a
    # trailing newline/space without noticing, which a plain == comparison
    # would then silently always reject.
    api_key: str | None = (os.environ.get("BACKEND_API_KEY") or "").strip() or None
    cache_ttl_seconds: int = int(os.environ.get("RESOLVE_CACHE_TTL", "14400"))  # 4h
    cache_max_size: int = int(os.environ.get("RESOLVE_CACHE_MAX", "512"))


settings = Settings()
