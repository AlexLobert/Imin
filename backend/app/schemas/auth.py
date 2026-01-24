from pydantic import BaseModel, EmailStr


class CreateAccountRequest(BaseModel):
    email: EmailStr
    password: str


class CreateAccountResponse(BaseModel):
    user_id: str
    email: EmailStr
    message: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str


class LogoutResponse(BaseModel):
    message: str
