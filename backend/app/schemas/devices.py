from pydantic import BaseModel


class DeviceCreate(BaseModel):
    platform: str
    token: str
    device_id: str | None = None


class DeviceResponse(BaseModel):
    device_id: int
    platform: str
    token: str
    device_identifier: str | None = None
