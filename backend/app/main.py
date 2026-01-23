from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes import auth as auth_routes
from app.api.routes import status as status_routes
from app.db.init_db import init_db

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(title="Imin Backend", version="0.1.0", lifespan=lifespan)


app.include_router(auth_routes.router)
app.include_router(status_routes.router)
