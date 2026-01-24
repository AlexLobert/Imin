from typing import Literal

from pydantic import BaseModel


class StatusRequest(BaseModel):
    status: Literal["In", "Out"]


class SetStatusResponse(BaseModel):
    status: Literal["In", "Out"]
    message: str
