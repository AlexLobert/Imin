from pydantic import BaseModel, EmailStr


class CreateAccountRequest(BaseModel):
    email: EmailStr
    password: str
    first_name: str | None = None
    last_name: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
