import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.config import settings
from app.routers import (
    analytics,
    boards,
    ews_auth,
    ews_notifications,
    health,
    krr,
    notes,
    owa,
    spaces,
    task_analytics,
    task_types,
    tasks,
    users,
)
from app.services.ews_keepalive import ews_keepalive_service
from app.services.ews_notification_service import ews_notification_service
from app.services.ews_runtime import shutdown_ews_executor
from app.services.notification_hub import notification_hub
from app.services.session_service import session_service

logger = logging.getLogger(__name__)


def _runs_exchange_background() -> bool:
    return settings.app_role in {"all", "api"}


@asynccontextmanager
async def lifespan(_app: FastAPI):
    session_service.start()
    if _runs_exchange_background():
        notification_hub.set_loop(asyncio.get_running_loop())
        ews_keepalive_service.start()
    yield
    if _runs_exchange_background():
        ews_keepalive_service.stop()
        ews_notification_service.shutdown_all()
    if settings.app_role in {"all", "api", "mail"}:
        shutdown_ews_executor()


app = FastAPI(title="DDT API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def unhandled_exception_handler(_request: Request, exc: Exception):
    if isinstance(exc, StarletteHTTPException):
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail},
        )

    logger.exception("Unhandled server error")
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )


@app.get("/")
async def root():
    return {"message": "DDT API is running"}


_role = settings.app_role

app.include_router(health.router, prefix="/api/health", tags=["health"])

if _role in {"all", "api"}:
    app.include_router(users.router, prefix="/api/users", tags=["users"])
    app.include_router(tasks.router, prefix="/api/tasks", tags=["tasks"])
    app.include_router(spaces.router, prefix="/api/spaces", tags=["spaces"])
    app.include_router(task_types.router, prefix="/api/task-types", tags=["task-types"])
    app.include_router(ews_auth.router, prefix="/api/ews/auth", tags=["ews-auth"])
    app.include_router(
        ews_notifications.router,
        prefix="/api/ews/notifications",
        tags=["ews-notifications"],
    )
    app.include_router(boards.router, prefix="/api/boards", tags=["boards"])
    app.include_router(notes.router, prefix="/api/notes", tags=["notes"])

if _role in {"all", "mail"}:
    app.include_router(owa.router, prefix="/api/owa", tags=["owa"])

if _role in {"all", "analytics"}:
    app.include_router(analytics.router, prefix="/api/analytics", tags=["analytics"])
    app.include_router(
        task_analytics.router,
        prefix="/api/task-analytics",
        tags=["task-analytics"],
    )
    app.include_router(krr.router, prefix="/api/krr", tags=["krr"])
