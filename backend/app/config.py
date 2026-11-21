"""Environment configuration.

All secrets live in the environment (or backend/.env, which is git-ignored).
Nothing here is ever sent to the client.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

BACKEND_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BACKEND_DIR / ".env")


def _bool(name: str, default: bool = False) -> bool:
    return os.getenv(name, "1" if default else "0").strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    gemini_api_key: str
    gemini_model: str
    host: str
    port: int
    trust_proxy: bool
    round_ttl_minutes: int
    cors_origins: tuple[str, ...]

    @property
    def ai_enabled(self) -> bool:
        return bool(self.gemini_api_key)


def load_settings() -> Settings:
    return Settings(
        gemini_api_key=os.getenv("GEMINI_API_KEY", "").strip(),
        gemini_model=os.getenv("GEMINI_MODEL", "gemini-2.5-flash").strip() or "gemini-2.5-flash",
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8080")),
        trust_proxy=_bool("TRUST_PROXY"),
        round_ttl_minutes=max(5, int(os.getenv("ROUND_TTL_MINUTES", "45"))),
        cors_origins=tuple(
            origin.strip()
            for origin in os.getenv("CORS_ORIGINS", "").split(",")
            if origin.strip()
        ),
    )


settings = load_settings()
