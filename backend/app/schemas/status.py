from typing import Literal

from pydantic import BaseModel


class StatusRequest(BaseModel):
    status: Literal["In", "Out"]
    visible_circle_ids: list[int]


class SetStatusResponse(BaseModel):
    status: Literal["In", "Out"]
    visible_circle_ids: list[int]
    message: str
