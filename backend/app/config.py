import os


class Settings:
    api_key: str | None = os.environ.get("BACKEND_API_KEY")
    cache_ttl_seconds: int = int(os.environ.get("RESOLVE_CACHE_TTL", "14400"))  # 4h
    cache_max_size: int = int(os.environ.get("RESOLVE_CACHE_MAX", "512"))


settings = Settings()
