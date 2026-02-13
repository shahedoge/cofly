import asyncio
import logging
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone

from fastapi import FastAPI

from database import engine, Base, SessionLocal
from models import Message
from routers import auth_router, message_router, contact_router, chat_router, ws_router, media_router, reaction_router

logger = logging.getLogger("cofly.gc")

GC_INTERVAL_HOURS = 1
GC_MAX_AGE_DAYS = 2


async def _message_gc_loop():
    """Periodically delete messages older than GC_MAX_AGE_DAYS."""
    while True:
        await asyncio.sleep(GC_INTERVAL_HOURS * 3600)
        try:
            db = SessionLocal()
            cutoff = datetime.now(timezone.utc) - timedelta(days=GC_MAX_AGE_DAYS)
            count = db.query(Message).filter(Message.created_at < cutoff).delete()
            db.commit()
            db.close()
            if count:
                logger.info("GC: deleted %d messages older than %s", count, cutoff.isoformat())
        except Exception as e:
            logger.error("GC: error: %s", e)


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    gc_task = asyncio.create_task(_message_gc_loop())
    yield
    gc_task.cancel()


app = FastAPI(title="Cofly", lifespan=lifespan)

app.include_router(auth_router.router)
app.include_router(message_router.router)
app.include_router(contact_router.router)
app.include_router(chat_router.router)
app.include_router(ws_router.router)
app.include_router(media_router.router)
app.include_router(reaction_router.router)


@app.get("/")
def root():
    return {"code": 0, "msg": "cofly is running"}
