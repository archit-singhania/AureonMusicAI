"""Durable project documents, authenticated sessions, and replayable event outbox.

SQLite is the self-contained local profile; DATABASE_URL selects PostgreSQL in Compose.
Revision compare-and-swap prevents silently losing simultaneous edits.
"""

import hashlib
import secrets
import time
import uuid
from contextlib import contextmanager
from sqlalchemy import JSON, Float, Integer, String, create_engine, update
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column
from settings import DATABASE_URL, REDIS_URL


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    email: Mapped[str] = mapped_column(String(254), unique=True)
    name: Mapped[str] = mapped_column(String(80))
    password: Mapped[str] = mapped_column(String(300))


class AuthSession(Base):
    __tablename__ = "sessions"
    token_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(36), index=True)
    expires: Mapped[float] = mapped_column(Float)


class Document(Base):
    __tablename__ = "documents"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    kind: Mapped[str] = mapped_column(String(30), index=True)
    owner: Mapped[str] = mapped_column(String(36), index=True)
    parent: Mapped[str] = mapped_column(String(36), default="", index=True)
    data: Mapped[dict] = mapped_column(JSON)
    revision: Mapped[int] = mapped_column(Integer, default=1)
    created: Mapped[float] = mapped_column(Float, default=time.time)
    updated: Mapped[float] = mapped_column(Float, default=time.time)


class Event(Base):
    __tablename__ = "events"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    owner: Mapped[str] = mapped_column(String(36), index=True)
    project_id: Mapped[str] = mapped_column(String(36), index=True)
    payload: Mapped[dict] = mapped_column(JSON)
    created: Mapped[float] = mapped_column(Float, default=time.time)


engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}
    if DATABASE_URL.startswith("sqlite")
    else {},
    pool_pre_ping=True,
)
Base.metadata.create_all(engine)


@contextmanager
def session():
    with Session(engine, expire_on_commit=False) as db:
        yield db
        db.commit()


def identifier():
    return str(uuid.uuid4())


def password_hash(password, salt=None):
    salt = salt or secrets.token_hex(16)
    return (
        salt
        + ":"
        + hashlib.scrypt(
            password.encode(), salt=bytes.fromhex(salt), n=16384, r=8, p=1
        ).hex()
    )


def password_matches(password, encoded):
    return secrets.compare_digest(
        password_hash(password, encoded.split(":")[0]), encoded
    )


def issue_token(db, user_id):
    token = secrets.token_urlsafe(36)
    db.add(
        AuthSession(
            token_hash=hashlib.sha256(token.encode()).hexdigest(),
            user_id=user_id,
            expires=time.time() + 60 * 60 * 24 * 7,
        )
    )
    return token


def lookup_token(token):
    with session() as db:
        auth = db.get(AuthSession, hashlib.sha256(token.encode()).hexdigest())
        return (
            db.get(User, auth.user_id) if auth and auth.expires > time.time() else None
        )


def public(doc):
    return {
        "id": doc.id,
        "owner_id": doc.owner,
        "revision": doc.revision,
        "created_at": doc.created,
        "updated_at": doc.updated,
        **doc.data,
    }


def create(db, kind, owner, data, parent=""):
    doc = Document(id=identifier(), kind=kind, owner=owner, parent=parent, data=data)
    db.add(doc)
    db.flush()
    return doc


def emit(db, doc, event_type="updated"):
    db.add(
        Event(
            owner=doc.owner,
            project_id=doc.parent if doc.kind == "job" else doc.id,
            payload={"type": event_type, "kind": doc.kind, **public(doc)},
        )
    )
    if REDIS_URL and doc.kind == "job" and event_type == "job.queued":
        try:
            import redis

            redis.Redis.from_url(
                REDIS_URL, socket_timeout=0.5, socket_connect_timeout=0.5
            ).rpush("aureon:work", doc.id)
        except Exception:
            pass  # The committed database is authoritative; scanning recovers missed wakeups.


def replace(db, doc, data, revision=None):
    expected = revision if revision is not None else doc.revision
    result = db.execute(
        update(Document)
        .where(Document.id == doc.id, Document.revision == expected)
        .values(data=data, revision=expected + 1, updated=time.time())
    )
    if result.rowcount != 1:
        raise ValueError(
            "This project changed on another device. Reload before saving."
        )
    db.refresh(doc)
    return doc
