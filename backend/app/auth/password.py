import re

from passlib.context import CryptContext


_PWD_CONTEXT = CryptContext(schemes=["bcrypt"], deprecated="auto")
_PASSWORD_ERROR = (
    "password must be at least 10 characters and include 1 capital letter, 1 number, "
    "and 1 special character"
)


def hash_password(password: str) -> str:
    return _PWD_CONTEXT.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return _PWD_CONTEXT.verify(password, password_hash)


def validate_password(password: str) -> tuple[bool, str | None]:
    if len(password) < 10:
        return False, _PASSWORD_ERROR
    if re.search(r"[A-Z]", password) is None:
        return False, _PASSWORD_ERROR
    if re.search(r"[0-9]", password) is None:
        return False, _PASSWORD_ERROR
    if re.search(r"[^A-Za-z0-9]", password) is None:
        return False, _PASSWORD_ERROR
    return True, None
