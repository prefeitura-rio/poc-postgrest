"""Application settings loaded from environment variables."""

from typing import ClassVar

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration for the PoC API."""

    model_config: ClassVar[SettingsConfigDict] = {
        "env_prefix": "POC_",
        "env_file": ".env",
    }

    postgrest_url: str = "http://postgrest:3000"
    postgrest_timeout: float = 10.0


settings = Settings()
