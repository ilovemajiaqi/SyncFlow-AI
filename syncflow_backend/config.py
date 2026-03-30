from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parent
ENV_FILE = BASE_DIR / ".env"

load_dotenv(ENV_FILE)


class Settings(BaseSettings):
    database_url: str = Field(default="sqlite:///./syncflow.db", alias="DATABASE_URL")
    default_user_id: str = Field(default="default_user", alias="DEFAULT_USER_ID")
    syncflow_mock_llm: bool = Field(default=False, alias="SYNCFLOW_MOCK_LLM")

    model_config = SettingsConfigDict(
        env_file=ENV_FILE,
        env_file_encoding="utf-8",
        populate_by_name=True,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
