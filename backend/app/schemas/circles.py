from pydantic import BaseModel


class CircleResponse(BaseModel):
    circle_id: int
    name: str
    is_system: bool


class CirclesListResponse(BaseModel):
    items: list[CircleResponse]
    next_cursor: str | None = None


class CircleCreate(BaseModel):
    name: str


class CirclePatch(BaseModel):
    name: str


class CircleMembersBatchAdd(BaseModel):
    member_ids: list[int]


class CircleMembersAddedResponse(BaseModel):
    added: int
