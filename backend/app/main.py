from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.exceptions import RequestValidationError

from app.api.errors import (
    http_exception_handler,
    unhandled_exception_handler,
    validation_exception_handler,
)
from app.api.routes import auth as auth_routes
from app.api.routes import chat as chat_routes
from app.api.routes import circles as circles_routes
from app.api.routes import devices as devices_routes
from app.api.routes import discovery as discovery_routes
from app.api.routes import friends as friends_routes
from app.api.routes import profile as profile_routes
from app.api.routes import reports as reports_routes
from app.api.routes import status as status_routes
from app.db.init_db import init_db

TAGS_METADATA = [
    {"name": "Auth", "description": "Authentication and session management."},
    {"name": "Profile", "description": "Current user profile and handle checks."},
    {"name": "Status", "description": "Status updates and visibility settings."},
    {"name": "Friends", "description": "Friends, friend requests, and blocking."},
    {"name": "Circles", "description": "Organize friends into circles."},
    {"name": "Chat", "description": "1:1 messaging threads and messages."},
    {"name": "Discovery", "description": "Discover who is In now."},
    {"name": "Devices", "description": "Push device registrations."},
    {"name": "Safety", "description": "User reporting and safety tools."},
]


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="Imin Backend",
    version="0.1.0",
    lifespan=lifespan,
    openapi_tags=TAGS_METADATA,
)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(HTTPException, http_exception_handler)
app.add_exception_handler(Exception, unhandled_exception_handler)


app.include_router(auth_routes.router)
app.include_router(profile_routes.router)
app.include_router(status_routes.router)
app.include_router(friends_routes.router)
app.include_router(circles_routes.router)
app.include_router(chat_routes.router)
app.include_router(discovery_routes.router)
app.include_router(devices_routes.router)
app.include_router(reports_routes.router)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
