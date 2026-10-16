from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    database_url: str = "postgresql+asyncpg://wasel:wasel@localhost:5432/wasel"
    jwt_secret: str = "development-only-change-this-secret-before-deploying"
    jwt_access_minutes: int = 20
    cors_origins: str = "http://localhost:3000"
    max_upload_bytes: int = 20 * 1024 * 1024
    upload_dir: str = "./uploads"
    registration_code: str = "change-this-invite-code"
    max_users: int = 6

    @property
    def cors_origin_list(self) -> list[str]:
        return [x.strip() for x in self.cors_origins.split(",") if x.strip()]

settings = Settings()
