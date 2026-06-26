import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.routers import (
    ews_auth,
    ews_calendar,
    ews_contacts,
    ews_mail,
    health,
    static_assets,
    task_types,
    tasks,
    users,
)

logger = logging.getLogger(__name__)

app = FastAPI(title="DDT API", version="1.0.0")

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


app.include_router(health.router, prefix="/api/health", tags=["health"])
app.include_router(static_assets.router, prefix="/api/static", tags=["static"])
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(tasks.router, prefix="/api/tasks", tags=["tasks"])
app.include_router(task_types.router, prefix="/api/task-types", tags=["task-types"])
app.include_router(ews_auth.router, prefix="/api/ews/auth", tags=["ews-auth"])
app.include_router(ews_mail.router, prefix="/api/ews/mail", tags=["ews-mail"])
app.include_router(
    ews_calendar.router, prefix="/api/ews/calendar", tags=["ews-calendar"]
)
app.include_router(
    ews_contacts.router, prefix="/api/ews/contacts", tags=["ews-contacts"]
)
