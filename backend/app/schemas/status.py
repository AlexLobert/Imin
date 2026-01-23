from pydantic import BaseModel


class StatusRequest(BaseModel):
    status: str
