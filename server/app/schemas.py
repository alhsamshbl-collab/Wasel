import re
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field, field_validator
class RegisterIn(BaseModel):
    username: str = Field(min_length=3, max_length=32)
    display_name: str = Field(min_length=1, max_length=80)
    password: str = Field(min_length=8, max_length=128)
    @field_validator("username")
    @classmethod
    def username_format(cls, value: str) -> str:
        value = value.strip().lower()
        if not re.fullmatch(r"[a-z0-9_.-]+", value): raise ValueError("Username accepts English letters, digits, _, . and - only")
        return value
    @field_validator("display_name")
    @classmethod
    def trim_name(cls, value: str) -> str:
        value = value.strip()
        if not value: raise ValueError("Display name is required")
        return value
class LoginIn(BaseModel):
    username: str
    password: str
class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    username: str
    display_name: str
    avatar_url: str | None
    bio: str | None
    created_at: datetime
class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
class ProfilePatch(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=80)
    bio: str | None = Field(default=None, max_length=300)
    avatar_url: str | None = Field(default=None, max_length=500)
